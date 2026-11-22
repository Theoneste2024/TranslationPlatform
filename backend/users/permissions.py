from collections.abc import Callable
from functools import wraps
from typing import ClassVar

from django.conf import settings
from django.core import signing
from django.http import HttpRequest, HttpResponse, JsonResponse
from rest_framework.authentication import BaseAuthentication
from rest_framework.exceptions import AuthenticationFailed
from rest_framework.permissions import BasePermission
from rest_framework.request import Request

from .models import Permission, User

TOKEN_SALT = 'users.api-token'


def issue_access_token(user: User) -> str:
    return signing.dumps(
        {'user_id': user.pk, 'token_version': user.token_version},
        salt=TOKEN_SALT,
    )


def _get_bearer_user(request: HttpRequest) -> User | None:
    authorization = request.headers.get('Authorization', '')
    scheme, separator, token = authorization.partition(' ')
    if not separator or scheme.lower() != 'bearer' or not token.strip():
        return None

    try:
        payload = signing.loads(
            token.strip(),
            salt=TOKEN_SALT,
            max_age=settings.API_TOKEN_TTL_SECONDS,
        )
    except signing.BadSignature:
        return None

    if not isinstance(payload, dict) or 'user_id' not in payload:
        return None

    try:
        user = User.objects.get(pk=payload['user_id'], is_active=True)
    except (User.DoesNotExist, TypeError, ValueError):
        return None
    if payload.get('token_version') != user.token_version:
        return None
    return user


class BearerTokenAuthentication(BaseAuthentication):
    def authenticate(self, request: Request) -> tuple[User, None] | None:
        authorization = request.headers.get('Authorization', '')
        if not authorization:
            return None

        scheme, separator, token = authorization.partition(' ')
        if not separator or scheme.lower() != 'bearer' or not token.strip():
            return None

        user = _get_bearer_user(request._request)
        if user is None:
            raise AuthenticationFailed('Invalid or expired bearer token.')
        return user, None

    def authenticate_header(self, request: Request) -> str:
        return 'Bearer'


class CapabilityPermission(BasePermission):
    name: ClassVar[str]
    allow_anonymous: ClassVar[bool] = False

    def has_user_permission(self, user: User) -> bool:
        permission, _ = Permission.objects.get_or_create(
            codename=self.name,
            defaults={'name': self.name},
        )
        permission.grant_to_superusers()

        if user.is_superuser:
            return True
        return permission.users.filter(pk=user.pk).exists() or (
            user.role_id is not None
            and permission.roles.filter(pk=user.role_id).exists()
        )

    def has_permission(self, request: Request, view) -> bool:
        user = request.user
        if not user.is_authenticated:
            return self.allow_anonymous
        return self.has_user_permission(user)


class CanAddUser(CapabilityPermission):
    name = 'CanAddUser'
    allow_anonymous = True


class CanVerifyEmail(CapabilityPermission):
    name = 'CanVerifyEmail'
    allow_anonymous = True


class CanResendVerification(CapabilityPermission):
    name = 'CanResendVerification'
    allow_anonymous = True


class CanLogin(CapabilityPermission):
    name = 'CanLogin'
    allow_anonymous = True


class CanRequestPasswordReset(CapabilityPermission):
    name = 'CanRequestPasswordReset'
    allow_anonymous = True


class CanResetPassword(CapabilityPermission):
    name = 'CanResetPassword'
    allow_anonymous = True


class CanViewUserProfile(CapabilityPermission):
    name = 'CanViewUserProfile'


class CanChangeSystemLanguage(CapabilityPermission):
    name = 'CanChangeSystemLanguage'


class CanViewHealthStatus(CapabilityPermission):
    name = 'CanViewHealthStatus'
    allow_anonymous = True


class CanTranslateText(CapabilityPermission):
    name = 'CanTranslateText'


class CanSpeechTranslate(CapabilityPermission):
    name = 'CanSpeechTranslate'




def _with_cors(response: HttpResponse) -> HttpResponse:
    response['Access-Control-Allow-Origin'] = '*'
    response['Access-Control-Allow-Methods'] = 'GET, POST, OPTIONS'
    response['Access-Control-Allow-Headers'] = 'Content-Type, Authorization'
    return response


def require_permission(permission_class: type[CapabilityPermission]) -> Callable:
    def decorate(view: Callable) -> Callable:
        @wraps(view)
        def check_permission(request: HttpRequest, *args, **kwargs):
            if request.method == 'OPTIONS':
                return _with_cors(HttpResponse(status=204))

            permission = permission_class()
            user = _get_bearer_user(request)
            if user is None and not permission.allow_anonymous:
                return _with_cors(
                    JsonResponse({'error': 'Authentication required.'}, status=401)
                )
            if user is not None:
                request.api_user = user

            if user is not None and not permission.has_user_permission(user):
                return _with_cors(
                    JsonResponse({'error': 'Permission denied.'}, status=403)
                )
            return _with_cors(view(request, *args, **kwargs))

        return check_permission

    return decorate
