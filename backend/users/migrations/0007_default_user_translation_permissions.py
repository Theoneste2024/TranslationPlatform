from django.db import migrations


TRANSLATION_PERMISSIONS = (
    'CanTranslateText',
    'CanSpeechTranslate',
    'CanAnalyzeVideo',
)


def grant_default_user_translation_permissions(apps, schema_editor):
    database = schema_editor.connection.alias
    Role = apps.get_model('users', 'Role')
    Permission = apps.get_model('users', 'Permission')
    user_role = Role.objects.using(database).get(name='user')

    for codename in TRANSLATION_PERMISSIONS:
        permission = Permission.objects.using(database).get(codename=codename)
        permission.roles.db_manager(database).add(user_role)


class Migration(migrations.Migration):
    dependencies = [
        ('users', '0006_user_username'),
    ]

    operations = [
        migrations.RunPython(
            grant_default_user_translation_permissions,
            migrations.RunPython.noop,
        ),
    ]
