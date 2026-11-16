import logging
import secrets
import smtplib
from datetime import timedelta
from typing import Any, ClassVar

from django.conf import settings
from django.contrib.auth.hashers import check_password, make_password
from django.contrib.auth.password_validation import validate_password
from django.core.exceptions import ValidationError
from django.core.mail import send_mail
from django.core.validators import validate_email
from django.db import IntegrityError, transaction
from django.db.models import Q
from django.utils import timezone
from rest_framework import generics, status
from rest_framework.authentication import BaseAuthentication
from rest_framework.permissions import BasePermission
from rest_framework.request import Request
from rest_framework.response import Response

from .models import EmailOTP, Role, User
from .permissions import (
    BearerTokenAuthentication,
    CanAddUser,
    CanLogin,
    CanRequestPasswordReset,
    CanResendVerification,
    CanResetPassword,
    CanVerifyEmail,
    CanViewUserProfile,
    issue_access_token,
)

logger = logging.getLogger(__name__)


class EmailDeliveryError(Exception):
    pass


class OTPRateLimited(Exception):
    pass


def _otp_timing_payload(message: str) -> dict[str, int | str]:
    return {
        'message': message,
        'expires_in': settings.OTP_EXPIRY_SECONDS,
        'resend_in': settings.OTP_RESEND_COOLDOWN_SECONDS,
    }


def _send_otp(user: User, purpose: str) -> None:
    now = timezone.now()
    most_recent = (
        EmailOTP.objects.filter(user=user, purpose=purpose)
        .order_by('-created_at')
        .first()
    )
    if (
        most_recent is not None
        and now - most_recent.created_at
        < timedelta(seconds=settings.OTP_RESEND_COOLDOWN_SECONDS)
    ):
        raise OTPRateLimited

    EmailOTP.objects.filter(
        user=user,
        purpose=purpose,
        consumed_at__isnull=True,
    ).update(consumed_at=now)

    code = f'{secrets.randbelow(1_000_000):06d}'
    EmailOTP.objects.create(
        user=user,
        purpose=purpose,
        code_hash=make_password(code),
        expires_at=now + timedelta(seconds=settings.OTP_EXPIRY_SECONDS),
    )
    subject = (
        'Verify your email address'
        if purpose == EmailOTP.Purpose.EMAIL_VERIFICATION
        else 'Reset your password'
    )
    message = (
        f'Your verification code is {code}. '
        f'It expires in {settings.OTP_EXPIRY_SECONDS // 60} minutes.'
    )
    try:
        sent = send_mail(
            subject,
            message,
            settings.DEFAULT_FROM_EMAIL,
            [user.email],
            fail_silently=False,
        )
    except (OSError, smtplib.SMTPException) as error:
        logger.exception('Could not send an OTP email.')
        raise EmailDeliveryError from error
    if sent != 1:
        logger.error('The configured email backend did not send an OTP email.')
        raise EmailDeliveryError


def _consume_otp(user: User, purpose: str, code: str) -> bool:
    otp = (
        EmailOTP.objects.select_for_update()
        .filter(
            user=user,
            purpose=purpose,
            consumed_at__isnull=True,
        )
        .order_by('-created_at')
        .first()
    )
    if otp is None:
        return False

    now = timezone.now()
    if otp.expires_at <= now or otp.attempts >= settings.OTP_MAX_ATTEMPTS:
        otp.consumed_at = now
        otp.save(update_fields=['consumed_at'])
        return False

    otp.attempts += 1
    if not check_password(code, otp.code_hash):
        if otp.attempts >= settings.OTP_MAX_ATTEMPTS:
            otp.consumed_at = now
        otp.save(update_fields=['attempts', 'consumed_at'])
        return False

    otp.consumed_at = now
    otp.save(update_fields=['attempts', 'consumed_at'])
    return True


def _password_errors(password: str, user: User | None = None) -> list[str]:
    errors = []
    if len(password) < 8:
        errors.append('Password must be at least 8 characters long.')
    if not any(character.isupper() for character in password):
        errors.append('Password must include an uppercase letter.')
    if not any(character.islower() for character in password):
        errors.append('Password must include a lowercase letter.')
    if not any(character.isdigit() for character in password):
        errors.append('Password must include a number.')
    if not any(not character.isalnum() for character in password):
        errors.append('Password must include a symbol.')
    if errors:
        return errors

    try:
        validate_password(password, user)
    except ValidationError as error:
        return list(error.messages)
    return []


class UsersAPIView(generics.GenericAPIView):
    authentication_classes: ClassVar[list[type[BaseAuthentication]]] = [
        BearerTokenAuthentication
    ]
    permission_classes: ClassVar[list[type[BasePermission]]] = []

    def get_payload(self, request: Request) -> dict[str, Any] | Response:
        payload = request.data
        if not isinstance(payload, dict):
            return Response(
                {'error': 'Request body must be a JSON object.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        return payload

    def check_permissions(self, request: Request) -> None:
        if request.method == 'OPTIONS':
            return
        super().check_permissions(request)

    def options(self, request: Request, *args, **kwargs) -> Response:
        return Response(status=status.HTTP_204_NO_CONTENT)

    def finalize_response(self, request, response, *args, **kwargs):
        response = super().finalize_response(request, response, *args, **kwargs)
        response['Access-Control-Allow-Origin'] = '*'
        response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
        response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
        return response


class SignupView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanAddUser]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        if 'role' in data:
            return Response(
                {'error': 'Role cannot be selected during signup.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        email = str(data.get('email', '')).strip().lower()
        username = str(data.get('username', '')).strip().lower()
        phone_number = str(data.get('phone_number', '')).strip()
        country = str(data.get('country', '')).strip()
        gender = data.get('gender')
        password = data.get('password')
        confirm_password = data.get('confirm_password')

        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {'error': 'A valid email address is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not username or len(username) > 150:
            return Response(
                {'error': 'A username is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        try:
            User._meta.get_field('username').run_validators(username)
        except ValidationError:
            return Response(
                {'error': 'A valid username is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not phone_number or len(phone_number) > 32:
            return Response(
                {'error': 'A valid phone number is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not country or len(country) > 100:
            return Response(
                {'error': 'A valid country is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if gender not in User.Gender.values:
            return Response(
                {'error': 'A valid gender is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(password, str):
            return Response(
                {'error': 'A password is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(confirm_password, str):
            return Response(
                {'error': 'Password confirmation is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if password != confirm_password:
            return Response(
                {'error': 'Password and confirmation do not match.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        password_errors = _password_errors(password)
        if password_errors:
            return Response(
                {'errors': password_errors},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if User.objects.filter(email=email).exists():
            return Response(
                {'error': 'An account with this email already exists.'},
                status=status.HTTP_409_CONFLICT,
            )
        if User.objects.filter(username__iexact=username).exists():
            return Response(
                {'error': 'An account with this username already exists.'},
                status=status.HTTP_409_CONFLICT,
            )
        if User.objects.filter(phone_number=phone_number).exists():
            return Response(
                {'error': 'An account with this phone number already exists.'},
                status=status.HTTP_409_CONFLICT,
            )

        try:
            with transaction.atomic():
                user_role = Role.objects.get(name='user')
                user = User.objects.create_user(
                    username=username,
                    email=email,
                    phone_number=phone_number,
                    country=country,
                    gender=gender,
                    password=password,
                    role=user_role,
                    is_active=False,
                )
                _send_otp(user, EmailOTP.Purpose.EMAIL_VERIFICATION)
        except IntegrityError:
            return Response(
                {'error': 'An account with these details already exists.'},
                status=status.HTTP_409_CONFLICT,
            )
        except EmailDeliveryError:
            return Response(
                {'error': 'Verification email could not be sent. Please try again later.'},
                status=status.HTTP_503_SERVICE_UNAVAILABLE,
            )

        return Response(
            _otp_timing_payload('Verification code sent to your email address.'),
            status=status.HTTP_201_CREATED,
        )


class VerifyEmailView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanVerifyEmail]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        email = str(data.get('email', '')).strip().lower()
        code = data.get('otp')
        if not email or not isinstance(code, str) or not code.isdigit() or len(code) != 6:
            return Response(
                {'error': 'Email and a six-digit OTP are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email).first()
        if user is None:
            return Response(
                {'error': 'Invalid email or OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if user.is_active:
            return Response({'message': 'Email address is already verified.'})

        with transaction.atomic():
            if not _consume_otp(user, EmailOTP.Purpose.EMAIL_VERIFICATION, code):
                return Response(
                    {'error': 'Invalid or expired OTP.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.is_active = True
            user.save(update_fields=['is_active'])
        return Response({'message': 'Email address verified.'})


class ResendVerificationView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanResendVerification]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        email = str(data.get('email', '')).strip().lower()
        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {'error': 'A valid email address is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email, is_active=False).first()
        if user is not None:
            try:
                with transaction.atomic():
                    _send_otp(user, EmailOTP.Purpose.EMAIL_VERIFICATION)
            except OTPRateLimited:
                pass
            except EmailDeliveryError:
                return Response(
                    {'error': 'Verification email could not be sent. Please try again later.'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
        return Response(
            _otp_timing_payload(
                'If the account needs verification, a code has been sent.'
            ),
            status=status.HTTP_202_ACCEPTED,
        )


class LoginView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanLogin]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        identifier = str(
            data.get('identifier', data.get('email', ''))
        ).strip().lower()
        password = data.get('password')
        if not identifier or not isinstance(password, str):
            return Response(
                {'error': 'Email or username and password are required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(
            Q(email__iexact=identifier) | Q(username__iexact=identifier)
        ).first()
        if user is None or not user.check_password(password):
            return Response(
                {'error': 'Invalid email or password.'},
                status=status.HTTP_401_UNAUTHORIZED,
            )
        if not user.is_active:
            return Response(
                {'error': 'Verify your email before logging in.'},
                status=status.HTTP_403_FORBIDDEN,
            )

        return Response(
            {
                'access_token': issue_access_token(user),
                'token_type': 'Bearer',
                'expires_in': settings.API_TOKEN_TTL_SECONDS,
                'user': {
                    'username': user.username,
                    'email': user.email,
                    'phone_number': user.phone_number,
                    'country': user.country,
                    'gender': user.gender,
                    'role': user.role.name,
                },
            }
        )


class ForgotPasswordView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanRequestPasswordReset]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        email = str(data.get('email', '')).strip().lower()
        try:
            validate_email(email)
        except ValidationError:
            return Response(
                {'error': 'A valid email address is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email, is_active=True).first()
        if user is not None:
            try:
                with transaction.atomic():
                    _send_otp(user, EmailOTP.Purpose.PASSWORD_RESET)
            except OTPRateLimited:
                pass
            except EmailDeliveryError:
                return Response(
                    {'error': 'Password reset email could not be sent. Please try again later.'},
                    status=status.HTTP_503_SERVICE_UNAVAILABLE,
                )
        return Response(
            _otp_timing_payload(
                'If the account exists, a password reset code has been sent.'
            ),
            status=status.HTTP_202_ACCEPTED,
        )


class ResetPasswordView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanResetPassword]

    def post(self, request: Request) -> Response:
        data = self.get_payload(request)
        if isinstance(data, Response):
            return data
        email = str(data.get('email', '')).strip().lower()
        code = data.get('otp')
        password = data.get('new_password')
        confirm_password = data.get('confirm_password')
        if not isinstance(code, str) or not code.isdigit() or len(code) != 6:
            return Response(
                {'error': 'A six-digit OTP is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(password, str):
            return Response(
                {'error': 'A new password is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if not isinstance(confirm_password, str):
            return Response(
                {'error': 'Password confirmation is required.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        if password != confirm_password:
            return Response(
                {'error': 'Password and confirmation do not match.'},
                status=status.HTTP_400_BAD_REQUEST,
            )

        user = User.objects.filter(email=email, is_active=True).first()
        if user is None:
            return Response(
                {'error': 'Invalid email or OTP.'},
                status=status.HTTP_400_BAD_REQUEST,
            )
        password_errors = _password_errors(password, user)
        if password_errors:
            return Response(
                {'errors': password_errors},
                status=status.HTTP_400_BAD_REQUEST,
            )

        with transaction.atomic():
            if not _consume_otp(user, EmailOTP.Purpose.PASSWORD_RESET, code):
                return Response(
                    {'error': 'Invalid or expired OTP.'},
                    status=status.HTTP_400_BAD_REQUEST,
                )
            user.set_password(password)
            user.token_version += 1
            user.save(update_fields=['password', 'token_version'])
        return Response({'message': 'Password has been reset.'})


class ProfileView(UsersAPIView):
    permission_classes: ClassVar[list[type[BasePermission]]] = [CanViewUserProfile]

    def get(self, request: Request) -> Response:
        user = request.user
        return Response(
            {
                'username': user.username,
                'email': user.email,
                'phone_number': user.phone_number,
                'country': user.country,
                'gender': user.gender,
                'role': user.role.name,
            }
        )
