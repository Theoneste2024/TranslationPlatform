import re
from typing import ClassVar

from django.conf import settings
from django.contrib.auth.base_user import AbstractBaseUser, BaseUserManager
from django.contrib.auth.models import PermissionsMixin
from django.contrib.auth.validators import UnicodeUsernameValidator
from django.db import models


class Role(models.Model):
    name = models.CharField(max_length=64, unique=True)

    def __str__(self) -> str:
        return self.name


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _available_username(self, username: str | None, email: str) -> str:
        source = username or re.sub(
            r'[^\w.@+-]',
            '_',
            email.partition('@')[0],
        )
        base = source.strip().lower()[:150] or 'user'
        candidate = base
        suffix = 2
        while (
            self.get_queryset()
            .using(self._db)
            .filter(username__iexact=candidate)
            .exists()
        ):
            suffix_text = f'_{suffix}'
            candidate = f'{base[:150 - len(suffix_text)]}{suffix_text}'
            suffix += 1
        return candidate

    def create_user(
        self,
        email: str,
        phone_number: str,
        country: str,
        gender: str,
        password: str | None = None,
        **extra_fields,
    ):
        if not email:
            raise ValueError('An email address is required.')
        if not phone_number:
            raise ValueError('A phone number is required.')
        if not country:
            raise ValueError('A country is required.')
        if not gender:
            raise ValueError('A gender is required.')
        if not password:
            raise ValueError('A password is required.')

        email = email.strip().lower()
        username = extra_fields.pop('username', None)
        username = (
            self._available_username(None, email)
            if username is None
            else username.strip().lower()
        )
        role = extra_fields.pop('role', None)
        if role is None:
            role, _ = Role.objects.get_or_create(name='user')

        user = self.model(
            username=username,
            email=email,
            phone_number=phone_number.strip(),
            country=country.strip(),
            gender=gender,
            role=role,
            **extra_fields,
        )
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_superuser(
        self,
        email: str,
        phone_number: str,
        country: str,
        gender: str,
        password: str | None = None,
        **extra_fields,
    ):
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        extra_fields.setdefault('is_active', True)
        if not extra_fields['is_staff']:
            raise ValueError('A superuser must have is_staff=True.')
        if not extra_fields['is_superuser']:
            raise ValueError('A superuser must have is_superuser=True.')

        admin_role, _ = Role.objects.get_or_create(name='admin')
        extra_fields['role'] = admin_role
        user = self.create_user(
            email,
            phone_number,
            country,
            gender,
            password,
            **extra_fields,
        )
        for permission in Permission.objects.all():
            permission.users.add(user)
        return user


class User(AbstractBaseUser, PermissionsMixin):
    class Gender(models.TextChoices):
        FEMALE = 'female', 'Female'
        MALE = 'male', 'Male'
        OTHER = 'other', 'Other'
        PREFER_NOT_TO_SAY = 'prefer_not_to_say', 'Prefer not to say'

    username = models.CharField(
        max_length=150,
        unique=True,
        validators=[UnicodeUsernameValidator()],
    )
    email = models.EmailField(unique=True)
    phone_number = models.CharField(max_length=32, unique=True)
    country = models.CharField(max_length=100)
    gender = models.CharField(max_length=32, choices=Gender.choices)
    role = models.ForeignKey(Role, on_delete=models.PROTECT, related_name='users')
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    token_version = models.PositiveIntegerField(default=0, editable=False)
    date_joined = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = 'email'
    REQUIRED_FIELDS: ClassVar[list[str]] = [
        'username',
        'phone_number',
        'country',
        'gender',
    ]

    def __str__(self) -> str:
        return self.username


class Permission(models.Model):
    codename = models.CharField(max_length=150, unique=True)
    name = models.CharField(max_length=255)
    roles = models.ManyToManyField(Role, blank=True, related_name='permissions')
    users = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        blank=True,
        related_name='permissions',
    )

    class Meta:
        ordering: ClassVar[list[str]] = ['codename']

    def __str__(self) -> str:
        return self.name

    def grant_to_superusers(self) -> None:
        superusers = User.objects.filter(is_superuser=True)
        self.users.add(*superusers)


class EmailOTP(models.Model):
    class Purpose(models.TextChoices):
        EMAIL_VERIFICATION = 'email_verification', 'Email verification'
        PASSWORD_RESET = 'password_reset', 'Password reset'

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='email_otps')
    purpose = models.CharField(max_length=32, choices=Purpose.choices)
    code_hash = models.CharField(max_length=128)
    created_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    attempts = models.PositiveSmallIntegerField(default=0)
    consumed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        indexes: ClassVar[list[models.Index]] = [
            models.Index(fields=['user', 'purpose', 'consumed_at']),
        ]
        ordering: ClassVar[list[str]] = ['-created_at']

    def __str__(self) -> str:
        return f'{self.get_purpose_display()} OTP for {self.user_id}'
