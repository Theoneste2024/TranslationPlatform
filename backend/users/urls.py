from django.urls import path

from .views import (
    CurrentUserView,
    LoginView,
    PasswordResetConfirmView,
    PasswordResetRequestView,
    RegisterView,
    ResendVerificationView,
    VerifyEmailView,
    VersionedTokenRefreshView,
)


urlpatterns = [
    path("register/", RegisterView.as_view(), name="register"),
    path("verify-email/resend/", ResendVerificationView.as_view(), name="email_verify_resend"),
    path("verify-email/<str:token>/", VerifyEmailView.as_view(), name="email_verify"),
    path("token/", LoginView.as_view(), name="token_obtain_pair"),
    path("token/refresh/", VersionedTokenRefreshView.as_view(), name="token_refresh"),
    path("password-reset/", PasswordResetRequestView.as_view(), name="password_reset"),
    path(
        "password-reset/confirm/<uidb64>/<token>/",
        PasswordResetConfirmView.as_view(),
        name="password_reset_confirm",
    ),
    path("me/", CurrentUserView.as_view(), name="current_user"),
]
