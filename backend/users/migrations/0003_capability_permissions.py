from typing import ClassVar

from django.db import migrations

ENDPOINT_PERMISSIONS = [
    ('users.signup', 'cancreateuser', 'Create user', True),
    ('users.verify_email', 'canverifyemail', 'Verify email address', True),
    (
        'users.resend_verification',
        'canresendverification',
        'Resend email verification code',
        True,
    ),
    ('users.login', 'canlogin', 'Log in', True),
    ('users.forgot_password', 'canrequestpasswordreset', 'Request password reset', True),
    ('users.reset_password', 'canresetpassword', 'Reset password', True),
    ('users.view_profile', 'canviewuserprofile', 'View user profile', False),
    ('translations.health', 'canviewhealthstatus', 'View health status', True),
    ('translations.translate_text', 'cantranslatetext', 'Translate text', False),
    ('translations.speech_translate', 'canspeechtranslate', 'Translate speech', False),
    ('translations.analyze_video', 'cananalyzevideo', 'Analyze video', False),
]


def migrate_endpoint_permissions(apps, schema_editor):
    EndpointPermission = apps.get_model('users', 'EndpointPermission')
    User = apps.get_model('users', 'User')
    database = schema_editor.connection.alias

    superuser_ids = list(
        User.objects.using(database)
        .filter(is_superuser=True)
        .values_list('pk', flat=True)
    )
    for old_codename, capability, name, is_public in ENDPOINT_PERMISSIONS:
        old_permission = (
            EndpointPermission.objects.using(database)
            .filter(codename=old_codename)
            .first()
        )
        permission = (
            EndpointPermission.objects.using(database)
            .filter(codename=capability)
            .first()
        )

        if permission is None and old_permission is not None:
            permission = old_permission
            permission.codename = capability

        if permission is None:
            permission = EndpointPermission.objects.using(database).create(
                codename=capability,
                name=name,
                is_public=is_public,
            )
        else:
            permission.name = name
            permission.is_public = is_public
            permission.save(update_fields=['codename', 'name', 'is_public'])
            if old_permission is not None and old_permission.pk != permission.pk:
                permission.users.add(*old_permission.users.all())
                permission.roles.add(*old_permission.roles.all())
                old_permission.delete()

        permission.users.add(*superuser_ids)


class Migration(migrations.Migration):
    dependencies: ClassVar[list[tuple[str, str]]] = [
        ('users', '0002_user_token_version'),
    ]

    operations: ClassVar[list[migrations.RunPython]] = [
        migrations.RunPython(
            migrate_endpoint_permissions,
            migrations.RunPython.noop,
        ),
    ]
