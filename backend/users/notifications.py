import smtplib

from decouple import UndefinedValueError, config
from django.core.mail import EmailMultiAlternatives, get_connection


class DeliveryError(Exception):
    pass


class DeliveryConfigurationError(DeliveryError):
    pass


def _required_setting(name, cast=None):
    try:
        if cast is None:
            return config(name)
        return config(name, cast=cast)
    except UndefinedValueError as exc:
        raise DeliveryConfigurationError(
            f"Missing required environment variable: {name}."
        ) from exc
    except ValueError as exc:
        raise DeliveryConfigurationError(
            f"Invalid value for environment variable: {name}."
        ) from exc


def send_auth_email(recipient, subject, body):
    use_tls = _required_setting("EMAIL_USE_TLS", cast=bool)
    use_ssl = _required_setting("EMAIL_USE_SSL", cast=bool)
    if use_tls and use_ssl:
        raise DeliveryConfigurationError(
            "EMAIL_USE_TLS and EMAIL_USE_SSL cannot both be enabled."
        )

    connection = get_connection(
        backend="django.core.mail.backends.smtp.EmailBackend",
        host=_required_setting("EMAIL_HOST"),
        port=_required_setting("EMAIL_PORT", cast=int),
        username=_required_setting("EMAIL_HOST_USER"),
        password=_required_setting("EMAIL_HOST_PASSWORD"),
        use_tls=use_tls,
        use_ssl=use_ssl,
        timeout=10,
    )
    message = EmailMultiAlternatives(
        subject=subject,
        body=body,
        from_email=_required_setting("DEFAULT_FROM_EMAIL"),
        to=[recipient],
        connection=connection,
    )
    try:
        if message.send(fail_silently=False) != 1:
            raise DeliveryError("SMTP did not accept the authentication email.")
    except (OSError, smtplib.SMTPException) as exc:
        raise DeliveryError("SMTP could not send the authentication email.") from exc


