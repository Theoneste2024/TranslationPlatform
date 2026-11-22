from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import User


class UserSerializer(serializers.ModelSerializer):
    name = serializers.CharField(read_only=True)

    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "username",
            "name",
            "phone_number",
            "gender",
            "system_language",
            "email_verified",
            "first_name",
            "last_name",
        )
        read_only_fields = ("id", "email_verified", "first_name", "last_name")


class RegistrationSerializer(serializers.ModelSerializer):
    phone_number = serializers.RegexField(
        r"^\+[1-9]\d{7,14}$",
        max_length=16,
    )
    gender = serializers.ChoiceField(choices=User.Gender.choices)
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = (
            "email",
            "username",
            "phone_number",
            "gender",
            "password",
            "confirm_password",
        )

    def validate_email(self, value):
        if User.objects.filter(email__iexact=value).exists():
            raise serializers.ValidationError(
                "A user with this email address already exists."
            )
        return value.lower()

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {"confirm_password": "The passwords do not match."}
            )
        validate_password(
            attrs["password"],
            user=User(
                email=attrs["email"],
                username=attrs["username"],
                phone_number=attrs["phone_number"],
            ),
        )
        return attrs

    def create(self, validated_data):
        validated_data.pop("confirm_password")
        password = validated_data.pop("password")
        return User.objects.create_user(
            password=password,
            is_active=False,
            email_verified=False,
            **validated_data,
        )


class LoginSerializer(serializers.Serializer):
    identifier = serializers.CharField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)


class SystemLanguagePreferenceSerializer(serializers.Serializer):
    system_language = serializers.ChoiceField(choices=User.SystemLanguage.choices)


class ResendVerificationSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetRequestSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetConfirmSerializer(serializers.Serializer):
    password = serializers.CharField(write_only=True)
    confirm_password = serializers.CharField(write_only=True)

    def validate(self, attrs):
        if attrs["password"] != attrs["confirm_password"]:
            raise serializers.ValidationError(
                {"confirm_password": "The passwords do not match."}
            )
        validate_password(attrs["password"], user=self.context["user"])
        return attrs
