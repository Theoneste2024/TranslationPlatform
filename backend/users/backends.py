from django.contrib.auth import get_user_model
from django.contrib.auth.backends import ModelBackend


class EmailOrPhoneBackend(ModelBackend):
    def authenticate(self, request, username=None, password=None, **kwargs):
        identifier = (username or kwargs.get("identifier") or "").strip()
        if not identifier or password is None:
            return None

        User = get_user_model()
        try:
            user = User.objects.get(email__iexact=identifier)
        except User.DoesNotExist:
            try:
                user = User.objects.get(phone_number=identifier)
            except User.DoesNotExist:
                User().set_password(password)
                return None
            except User.MultipleObjectsReturned:
                User().set_password(password)
                return None
        except User.MultipleObjectsReturned:
            User().set_password(password)
            return None

        if (
            user.check_password(password)
            and user.email_verified
            and self.user_can_authenticate(user)
        ):
            return user
        return None
