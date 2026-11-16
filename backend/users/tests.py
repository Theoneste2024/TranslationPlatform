import os
from unittest.mock import patch
from urllib.parse import urlsplit

from django.contrib.auth import get_user_model
from django.test import TestCase
from rest_framework.test import APIClient

from .notifications import send_auth_email
from .views import _issue_tokens


User = get_user_model()


class UserAuthenticationApiTests(TestCase):
    def setUp(self):
        self.client = APIClient()

    def create_user(self, **overrides):
        values = {
            "email": "person@example.com",
            "username": "person",
            "phone_number": "+12025550143",
            "gender": User.Gender.OTHER,
            "password": "Long-Unique-Passphrase-2030!",
            "email_verified": True,
            "is_active": True,
        }
        values.update(overrides)
        password = values.pop("password")
        return User.objects.create_user(password=password, **values)

    @patch("users.views.send_auth_email")
    def test_registration_requires_email_verification(self, send_email):
        response = self.client.post(
            "/api/v1/auth/register/",
            {
                "email": "new.user@example.com",
                "username": "newuser",
                "phone_number": "+12025550144",
                "gender": "prefer_not_to_say",
                "password": "Long-Unique-Passphrase-2030!",
                "confirm_password": "Long-Unique-Passphrase-2030!",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 201)
        self.assertNotIn("access", response.data)
        self.assertEqual(response.data["user"]["username"], "newuser")
        user = User.objects.get(email="new.user@example.com")
        self.assertFalse(user.is_active)
        self.assertFalse(user.email_verified)
        self.assertTrue(user.check_password("Long-Unique-Passphrase-2030!"))
        send_email.assert_called_once()

        verification_path = urlsplit(send_email.call_args.args[2].split("\n\n")[-1]).path
        verification_response = self.client.get(verification_path)
        user.refresh_from_db()
        self.assertEqual(verification_response.status_code, 200)
        self.assertTrue(user.is_active)
        self.assertTrue(user.email_verified)

        login_response = self.client.post(
            "/api/v1/auth/token/",
            {
                "identifier": user.email,
                "password": "Long-Unique-Passphrase-2030!",
            },
            format="json",
        )
        self.assertEqual(login_response.status_code, 200)
        self.assertIn("access", login_response.data)

    def test_email_and_phone_login_issue_tokens_immediately(self):
        user = self.create_user()

        for identifier in (user.email, user.phone_number):
            with self.subTest(identifier=identifier):
                response = self.client.post(
                    "/api/v1/auth/token/",
                    {
                        "identifier": identifier,
                        "password": "Long-Unique-Passphrase-2030!",
                    },
                    format="json",
                )

                self.assertEqual(response.status_code, 200)
                self.assertIn("access", response.data)
                self.assertIn("refresh", response.data)
                self.assertNotIn("challenge_id", response.data)
                refresh_response = self.client.post(
                    "/api/v1/auth/token/refresh/",
                    {"refresh": response.data["refresh"]},
                    format="json",
                )
                self.assertEqual(refresh_response.status_code, 200)

    def test_unverified_user_cannot_login(self):
        user = self.create_user(is_active=False, email_verified=False)
        response = self.client.post(
            "/api/v1/auth/token/",
            {
                "identifier": user.email,
                "password": "Long-Unique-Passphrase-2030!",
            },
            format="json",
        )

        self.assertEqual(response.status_code, 401)

    @patch("users.views.send_auth_email")
    def test_password_reset_changes_password_and_revokes_old_tokens(self, send_email):
        user = self.create_user()
        old_tokens = _issue_tokens(user)
        response = self.client.post(
            "/api/v1/auth/password-reset/",
            {"email": user.email},
            format="json",
        )

        self.assertEqual(response.status_code, 200)
        send_email.assert_called_once()
        reset_path = urlsplit(send_email.call_args.args[2].split("\n\n")[-1]).path
        reset_page = self.client.get(reset_path)
        self.assertEqual(reset_page.status_code, 200)
        self.assertContains(reset_page, "Choose a new password")
        reset_response = self.client.post(
            reset_path,
            {
                "password": "Another-Unique-Passphrase-2031!",
                "confirm_password": "Another-Unique-Passphrase-2031!",
            },
            format="json",
        )

        self.assertEqual(reset_response.status_code, 200)
        user.refresh_from_db()
        self.assertTrue(user.check_password("Another-Unique-Passphrase-2031!"))
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {old_tokens['access']}")
        self.assertEqual(self.client.get("/api/v1/auth/me/").status_code, 401)
        refresh_response = self.client.post(
            "/api/v1/auth/token/refresh/",
            {"refresh": old_tokens["refresh"]},
            format="json",
        )
        self.assertEqual(refresh_response.status_code, 401)

    def test_smtp_delivery_uses_environment_configuration(self):
        smtp_settings = {
            "EMAIL_HOST": "smtp.example.com",
            "EMAIL_PORT": "587",
            "EMAIL_HOST_USER": "mailer",
            "EMAIL_HOST_PASSWORD": "test-password",
            "EMAIL_USE_TLS": "True",
            "EMAIL_USE_SSL": "False",
            "DEFAULT_FROM_EMAIL": "noreply@example.com",
        }
        with (
            patch.dict(os.environ, smtp_settings),
            patch("users.notifications.get_connection") as get_connection,
            patch("users.notifications.EmailMultiAlternatives") as email_class,
        ):
            email_class.return_value.send.return_value = 1
            send_auth_email("person@example.com", "Subject", "Body")

        self.assertEqual(get_connection.call_args.kwargs["host"], "smtp.example.com")
        self.assertEqual(get_connection.call_args.kwargs["port"], 587)
        self.assertEqual(
            email_class.call_args.kwargs["from_email"],
            "noreply@example.com",
        )
