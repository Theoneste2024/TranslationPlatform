import binascii
import logging

from django.contrib.auth import authenticate
from django.contrib.auth.tokens import default_token_generator
from django.core import signing
from django.shortcuts import render
from django.urls import reverse
from django.utils.encoding import force_bytes, force_str
from django.utils.http import urlsafe_base64_decode, urlsafe_base64_encode
from rest_framework import status
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from rest_framework_simplejwt.serializers import TokenRefreshSerializer
from rest_framework_simplejwt.settings import api_settings
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.views import TokenRefreshView

from .models import User
from .notifications import DeliveryError, send_auth_email
from .serializers import (
    LoginSerializer,
    PasswordResetConfirmSerializer,
    PasswordResetRequestSerializer,
    RegistrationSerializer,
    ResendVerificationSerializer,
    UserSerializer,
)


logger = logging.getLogger(__name__)
EMAIL_VERIFICATION_SALT = "users.email-verification"
EMAIL_VERIFICATION_MAX_AGE = 24 * 60 * 60


def _send_verification_email(request, user):
    token = signing.dumps(
        {"user_id": user.pk, "email": user.email},
        salt=EMAIL_VERIFICATION_SALT,
        compress=True,
    )
    link = request.build_absolute_uri(
        reverse("email_verify", kwargs={"token": token})
    )
    send_auth_email(
        user.email,
        "Verify your email address",
        f"Verify your email address using this link:\n\n{link}",
    )


def _issue_tokens(user):
    refresh = RefreshToken.for_user(user)
    refresh["auth_version"] = user.auth_version
    return {
        "refresh": str(refresh),
        "access": str(refresh.access_token),
    }


def _password_reset_user(uidb64, token):
    try:
        user_id = force_str(urlsafe_base64_decode(uidb64))
        user = User.objects.get(pk=user_id)
    except (
        User.DoesNotExist,
        binascii.Error,
        OverflowError,
        TypeError,
        ValueError,
        UnicodeDecodeError,
    ):
        return None

    if (
        not user.is_active
        or not user.email_verified
        or not default_token_generator.check_token(user, token)
    ):
        return None
    return user


class RegisterView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "registration"

    def post(self, request):
        serializer = RegistrationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save()
        try:
            _send_verification_email(request, user)
        except DeliveryError:
            logger.exception("Could not send verification email for user_id=%s", user.pk)
            return Response(
                {"detail": "The verification email could not be sent. Please retry."},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(
            {
                "detail": "Registration successful. Verify your email before signing in.",
                "user": UserSerializer(user).data,
            },
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "email_verification"

    def get(self, request, token):
        try:
            payload = signing.loads(
                token,
                salt=EMAIL_VERIFICATION_SALT,
                max_age=EMAIL_VERIFICATION_MAX_AGE,
            )
            user = User.objects.get(
                pk=payload["user_id"],
                email=payload["email"],
            )
        except (
            signing.BadSignature,
            KeyError,
            TypeError,
            ValueError,
            User.DoesNotExist,
        ):
            return Response(
                {"detail": "The verification link is invalid or expired."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        if not user.email_verified:
            user.email_verified = True
            user.is_active = True
            user.save(update_fields=("email_verified", "is_active"))
        return Response({"detail": "Email verified. You can now sign in."})


class ResendVerificationView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "email_verification"

    def post(self, request):
        serializer = ResendVerificationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(
            email__iexact=serializer.validated_data["email"],
            email_verified=False,
            is_active=False,
        ).first()
        if user:
            try:
                _send_verification_email(request, user)
            except DeliveryError:
                logger.exception(
                    "Could not resend verification email for user_id=%s",
                    user.pk,
                )
                return Response(
                    {"detail": "The verification email could not be sent. Please retry."},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

        return Response(
            {"detail": "If the account needs verification, an email has been sent."}
        )


class LoginView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "login"

    def post(self, request):
        serializer = LoginSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = authenticate(
            request=request,
            username=serializer.validated_data["identifier"],
            password=serializer.validated_data["password"],
        )
        if user is None:
            raise AuthenticationFailed("Invalid email or phone number, or password.")

        return Response({"user": UserSerializer(user).data, **_issue_tokens(user)})


class VersionedTokenRefreshSerializer(TokenRefreshSerializer):
    def validate(self, attrs):
        try:
            refresh = RefreshToken(attrs["refresh"])
        except TokenError as exc:
            raise InvalidToken("Token is invalid.") from exc

        user_id = refresh.get(api_settings.USER_ID_CLAIM)
        user = User.objects.filter(
            pk=user_id,
            is_active=True,
            email_verified=True,
        ).first()
        if user is None or refresh.get("auth_version") != user.auth_version:
            raise InvalidToken("A current login token is required.")
        return super().validate(attrs)


class VersionedTokenRefreshView(TokenRefreshView):
    serializer_class = VersionedTokenRefreshSerializer
    permission_classes = [AllowAny]


class PasswordResetRequestView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def post(self, request):
        serializer = PasswordResetRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = User.objects.filter(
            email__iexact=serializer.validated_data["email"],
            is_active=True,
            email_verified=True,
        ).first()
        if user:
            uidb64 = urlsafe_base64_encode(force_bytes(user.pk))
            token = default_token_generator.make_token(user)
            link = request.build_absolute_uri(
                reverse(
                    "password_reset_confirm",
                    kwargs={"uidb64": uidb64, "token": token},
                )
            )
            try:
                send_auth_email(
                    user.email,
                    "Reset your password",
                    f"Reset your password using this link:\n\n{link}",
                )
            except DeliveryError:
                logger.exception("Could not send password reset email for user_id=%s", user.pk)
                return Response(
                    {"detail": "The password reset email could not be sent. Please retry."},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )

        return Response(
            {"detail": "If the account exists, a password reset email has been sent."}
        )


class PasswordResetConfirmView(APIView):
    permission_classes = [AllowAny]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "password_reset"

    def get(self, request, uidb64, token):
        is_valid = _password_reset_user(uidb64, token) is not None
        return render(
            request,
            "users/password_reset_confirm.html",
            {"is_valid": is_valid},
            status=status.HTTP_200_OK if is_valid else status.HTTP_400_BAD_REQUEST,
        )

    def post(self, request, uidb64, token):
        user = _password_reset_user(uidb64, token)
        if user is None:
            return Response(
                {"detail": "The password reset link is invalid or expired."},
                status=status.HTTP_400_BAD_REQUEST,
            )

        serializer = PasswordResetConfirmSerializer(
            data=request.data,
            context={"user": user},
        )
        serializer.is_valid(raise_exception=True)
        user.set_password(serializer.validated_data["password"])
        user.auth_version += 1
        user.save(update_fields=("password", "auth_version"))
        return Response({"detail": "Password reset successful. You can now sign in."})


class CurrentUserView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        return Response(UserSerializer(request.user).data)
