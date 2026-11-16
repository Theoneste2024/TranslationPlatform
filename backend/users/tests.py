import json
import re

from django.core import mail
from django.http import JsonResponse
from django.test import RequestFactory, TestCase, override_settings

from .models import EmailOTP, Permission, Role, User
from .permissions import (
    CapabilityPermission,
    issue_access_token,
    require_permission,
)


@override_settings(
    EMAIL_BACKEND='django.core.mail.backends.locmem.EmailBackend',
    OTP_EXPIRY_SECONDS=600,
)
class UserAuthenticationTests(TestCase):
    def post_json(self, path, body):
        return self.client.post(
            path,
            data=json.dumps(body),
            content_type='application/json',
        )

    def verification_code(self):
        match = re.search(r'\b\d{6}\b', mail.outbox[-1].body)
        self.assertIsNotNone(match)
        return match.group()

    def test_signup_requires_email_verification_before_login(self):
        weak_password = self.post_json(
            '/api/users/signup',
            {
                'username': 'weak_password_user',
                'email': 'weak-password@example.com',
                'phone_number': '+15551234565',
                'country': 'United States',
                'gender': 'prefer_not_to_say',
                'password': 'password1',
                'confirm_password': 'password1',
            },
        )
        self.assertEqual(weak_password.status_code, 400)

        mismatched_password = self.post_json(
            '/api/users/signup',
            {
                'username': 'mismatch_user',
                'email': 'mismatch@example.com',
                'phone_number': '+15551234564',
                'country': 'United States',
                'gender': 'prefer_not_to_say',
                'password': 'Strong-Passphrase-90',
                'confirm_password': 'Different-Passphrase-90',
            },
        )
        self.assertEqual(mismatched_password.status_code, 400)

        missing_confirmation = self.post_json(
            '/api/users/signup',
            {
                'username': 'missing_confirmation_user',
                'email': 'missing-confirmation@example.com',
                'phone_number': '+15551234563',
                'country': 'United States',
                'gender': 'prefer_not_to_say',
                'password': 'Strong-Passphrase-90',
            },
        )
        self.assertEqual(missing_confirmation.status_code, 400)

        missing_country = self.post_json(
            '/api/users/signup',
            {
                'username': 'missing_country_user',
                'email': 'missing-country@example.com',
                'phone_number': '+15551234566',
                'gender': 'prefer_not_to_say',
                'password': 'Strong-Passphrase-90',
            },
        )
        self.assertEqual(missing_country.status_code, 400)

        signup = self.post_json(
            '/api/users/signup',
            {
                'username': 'new_user',
                'email': 'new@example.com',
                'phone_number': '+15551234567',
                'country': 'United States',
                'gender': 'prefer_not_to_say',
                'password': 'Strong-Passphrase-90',
                'confirm_password': 'Strong-Passphrase-90',
                'role': 'admin',
            },
        )
        self.assertEqual(signup.status_code, 400)

        signup = self.post_json(
            '/api/users/signup',
            {
                'username': 'new_user',
                'email': 'new@example.com',
                'phone_number': '+15551234567',
                'country': 'United States',
                'gender': 'prefer_not_to_say',
                'password': 'Strong-Passphrase-90',
                'confirm_password': 'Strong-Passphrase-90',
            },
        )
        self.assertEqual(signup.status_code, 201)
        user = User.objects.get(email='new@example.com')
        self.assertFalse(user.is_active)
        self.assertEqual(user.role.name, 'user')
        self.assertEqual(user.country, 'United States')
        self.assertEqual(user.username, 'new_user')

        resend = self.post_json(
            '/api/users/resend-verification',
            {'email': user.email},
        )
        self.assertEqual(resend.status_code, 202)
        self.assertEqual(len(mail.outbox), 1)

        login = self.post_json(
            '/api/users/login',
            {'identifier': user.username, 'password': 'Strong-Passphrase-90'},
        )
        self.assertEqual(login.status_code, 403)

        verification = self.post_json(
            '/api/users/verify-email',
            {'email': user.email, 'otp': self.verification_code()},
        )
        self.assertEqual(verification.status_code, 200)

        login = self.post_json(
            '/api/users/login',
            {'email': user.email, 'password': 'Strong-Passphrase-90'},
        )
        self.assertEqual(login.status_code, 200)
        token = login.json()['access_token']
        self.assertEqual(login.json()['user']['country'], 'United States')
        self.assertEqual(login.json()['user']['username'], user.username)

        denied = self.client.get(
            '/api/users/me',
            HTTP_AUTHORIZATION=f'Bearer {token}',
        )
        self.assertEqual(denied.status_code, 403)

        permission = Permission.objects.get(codename='CanViewUserProfile')
        permission.users.add(user)
        allowed = self.client.get(
            '/api/users/me',
            HTTP_AUTHORIZATION=f'Bearer {token}',
        )
        self.assertEqual(allowed.status_code, 200)
        self.assertEqual(allowed.json()['email'], user.email)
        self.assertEqual(allowed.json()['country'], 'United States')

    @override_settings(OTP_EXPIRY_SECONDS=937, OTP_RESEND_COOLDOWN_SECONDS=83)
    def test_otp_endpoints_return_configured_expiry_and_resend_values(self):
        signup = self.post_json(
            '/api/users/signup',
            {
                'username': 'timed_user',
                'email': 'timed@example.com',
                'phone_number': '+15551234571',
                'country': 'United States',
                'gender': 'other',
                'password': 'Strong-Passphrase-90',
                'confirm_password': 'Strong-Passphrase-90',
            },
        )
        self.assertEqual(signup.status_code, 201)
        self.assertEqual(signup.json()['expires_in'], 937)
        self.assertEqual(signup.json()['resend_in'], 83)

        resend = self.post_json(
            '/api/users/resend-verification',
            {'email': 'timed@example.com'},
        )
        self.assertEqual(resend.status_code, 202)
        self.assertEqual(resend.json()['expires_in'], 937)
        self.assertEqual(resend.json()['resend_in'], 83)

        user = User.objects.get(email='timed@example.com')
        user.is_active = True
        user.save(update_fields=['is_active'])
        reset = self.post_json(
            '/api/users/forgot-password',
            {'email': user.email},
        )
        self.assertEqual(reset.status_code, 202)
        self.assertEqual(reset.json()['expires_in'], 937)
        self.assertEqual(reset.json()['resend_in'], 83)

    def test_superusers_receive_existing_and_future_capabilities(self):
        superuser = User.objects.create_superuser(
            email='root@example.com',
            phone_number='+15551234570',
            country='United States',
            gender='other',
            password='Root-Strong-Passphrase-90',
        )
        self.assertTrue(
            all(
                permission.users.filter(pk=superuser.pk).exists()
                for permission in Permission.objects.all()
            )
        )

        class CanViewFutureEndpoint(CapabilityPermission):
            name = 'CanViewFutureEndpoint'

        @require_permission(CanViewFutureEndpoint)
        def future_endpoint(request):
            return JsonResponse({'ok': True})

        request = RequestFactory().get('/future-endpoint')
        request.META['HTTP_AUTHORIZATION'] = f'Bearer {issue_access_token(superuser)}'
        response = future_endpoint(request)

        self.assertEqual(response.status_code, 200)
        future_permission = Permission.objects.get(codename='CanViewFutureEndpoint')
        self.assertTrue(future_permission.users.filter(pk=superuser.pk).exists())

    def test_user_role_can_reach_all_translation_endpoints_by_default(self):
        user = User.objects.create_user(
            email='translator@example.com',
            username='translator',
            phone_number='+15551234573',
            country='United States',
            gender='other',
            password='Translator-Strong-Passphrase-90',
            role=Role.objects.get(name='user'),
        )
        token = issue_access_token(user)
        endpoints = (
            '/api/v1/translate_text/',
            '/api/v1/speech_translate/',
            '/api/v1/analyze_video/',
        )

        for endpoint in endpoints:
            with self.subTest(endpoint=endpoint):
                response = self.client.post(
                    endpoint,
                    data='{}',
                    content_type='application/json',
                    HTTP_AUTHORIZATION=f'Bearer {token}',
                )
                self.assertEqual(response.status_code, 400, response.content)

    def test_email_otp_is_single_use_and_limited_to_five_attempts(self):
        self.post_json(
            '/api/users/signup',
            {
                'username': 'otp_user',
                'email': 'otp@example.com',
                'phone_number': '+15551234568',
                'country': 'United States',
                'gender': 'other',
                'password': 'Strong-Passphrase-90',
                'confirm_password': 'Strong-Passphrase-90',
            },
        )
        user = User.objects.get(email='otp@example.com')
        wrong_code = '000000'
        actual_code = self.verification_code()
        if actual_code == wrong_code:
            wrong_code = '000001'

        for _ in range(5):
            response = self.post_json(
                '/api/users/verify-email',
                {'email': user.email, 'otp': wrong_code},
            )
        self.assertEqual(response.status_code, 400)
        self.assertIsNotNone(EmailOTP.objects.get(user=user).consumed_at)
        self.assertFalse(user.is_active)

    def test_forgot_password_code_resets_password(self):
        user_role = Role.objects.get(name='user')
        user = User.objects.create_user(
            email='reset@example.com',
            phone_number='+15551234569',
            country='United States',
            gender='female',
            password='Old-Strong-Passphrase-90',
            role=user_role,
        )
        login = self.post_json(
            '/api/users/login',
            {'email': user.email, 'password': 'Old-Strong-Passphrase-90'},
        )
        token = login.json()['access_token']
        profile_permission = Permission.objects.get_or_create(
            codename='CanViewUserProfile',
            defaults={'name': 'CanViewUserProfile'},
        )[0]
        profile_permission.users.add(user)

        response = self.post_json(
            '/api/users/forgot-password',
            {'email': user.email},
        )
        self.assertEqual(response.status_code, 202)

        mismatch = self.post_json(
            '/api/users/reset-password',
            {
                'email': user.email,
                'otp': self.verification_code(),
                'new_password': 'New-Strong-Passphrase-90',
                'confirm_password': 'Different-Strong-Passphrase-90',
            },
        )
        self.assertEqual(mismatch.status_code, 400)

        response = self.post_json(
            '/api/users/reset-password',
            {
                'email': user.email,
                'otp': self.verification_code(),
                'new_password': 'New-Strong-Passphrase-90',
                'confirm_password': 'New-Strong-Passphrase-90',
            },
        )
        self.assertEqual(response.status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.check_password('New-Strong-Passphrase-90'))
        self.assertFalse(user.check_password('Old-Strong-Passphrase-90'))
        revoked = self.client.get(
            '/api/users/me',
            HTTP_AUTHORIZATION=f'Bearer {token}',
        )
        self.assertEqual(revoked.status_code, 401)

    def test_translation_routes_are_permission_protected_and_health_is_public(self):
        health = self.client.get('/api/health')
        self.assertEqual(health.status_code, 200)

        versioned_health = self.client.get('/api/v1/health/')
        self.assertEqual(versioned_health.status_code, 200)

        response = self.client.post(
            '/api/translate_text',
            data='{}',
            content_type='application/json',
        )
        self.assertEqual(response.status_code, 401)
        self.assertIn('Authorization', response['Access-Control-Allow-Headers'])

        preflight = self.client.options('/api/translate_text')
        self.assertEqual(preflight.status_code, 204)

        versioned_preflight = self.client.options('/api/v1/translate_text/')
        self.assertEqual(versioned_preflight.status_code, 204)

    def test_user_api_view_rejects_unsupported_methods_with_json(self):
        response = self.client.get('/api/users/signup')
        self.assertEqual(response.status_code, 405)
