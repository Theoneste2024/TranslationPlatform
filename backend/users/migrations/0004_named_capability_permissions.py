from typing import ClassVar

from django.db import migrations, models

PERMISSION_NAMES = {
    'cancreateuser': 'CanAddUser',
    'canverifyemail': 'CanVerifyEmail',
    'canresendverification': 'CanResendVerification',
    'canlogin': 'CanLogin',
    'canrequestpasswordreset': 'CanRequestPasswordReset',
    'canresetpassword': 'CanResetPassword',
    'canviewuserprofile': 'CanViewUserProfile',
    'canviewhealthstatus': 'CanViewHealthStatus',
    'cantranslatetext': 'CanTranslateText',
    'canspeechtranslate': 'CanSpeechTranslate',
    'cananalyzevideo': 'CanAnalyzeVideo',
}


def rename_capability_permissions(apps, schema_editor):
    Permission = apps.get_model('users', 'Permission')
    database = schema_editor.connection.alias
    for old_name, permission_name in PERMISSION_NAMES.items():
        Permission.objects.using(database).filter(codename=old_name).update(
            codename=permission_name,
            name=permission_name,
        )


class Migration(migrations.Migration):
    dependencies: ClassVar[list[tuple[str, str]]] = [
        ('users', '0003_capability_permissions'),
    ]

    operations: ClassVar[list] = [
        migrations.RenameModel(
            old_name='EndpointPermission',
            new_name='Permission',
        ),
        migrations.AlterField(
            model_name='permission',
            name='roles',
            field=models.ManyToManyField(
                blank=True,
                related_name='permissions',
                to='users.role',
            ),
        ),
        migrations.AlterField(
            model_name='permission',
            name='users',
            field=models.ManyToManyField(
                blank=True,
                related_name='permissions',
                to='users.user',
            ),
        ),
        migrations.RemoveField(
            model_name='permission',
            name='is_public',
        ),
        migrations.RunPython(
            rename_capability_permissions,
            migrations.RunPython.noop,
        ),
    ]
