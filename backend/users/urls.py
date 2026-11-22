from django.urls import path

from . import views

urlpatterns = [
    path(
        'api/users/signup',
        views.SignupView.as_view(),
        name='users-signup',
    ),
    path(
        'api/users/verify-email',
        views.VerifyEmailView.as_view(),
        name='users-verify-email',
    ),
    path(
        'api/users/resend-verification',
        views.ResendVerificationView.as_view(),
        name='users-resend-verification',
    ),
    path(
        'api/users/login',
        views.LoginView.as_view(),
        name='users-login',
    ),
    path(
        'api/users/forgot-password',
        views.ForgotPasswordView.as_view(),
        name='users-forgot-password',
    ),
    path(
        'api/users/reset-password',
        views.ResetPasswordView.as_view(),
        name='users-reset-password',
    ),
    path(
        'api/users/me',
        views.ProfileView.as_view(),
        name='users-profile',
    ),
    path(
        'api/users/me/system-language',
        views.SystemLanguageView.as_view(),
        name='users-system-language',
    ),
]
