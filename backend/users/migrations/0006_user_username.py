import re
from typing import ClassVar

from django.contrib.auth.validators import UnicodeUsernameValidator
from django.db import migrations, models


def populate_usernames(apps, schema_editor):
    User = apps.get_model('users', 'User')
    database = schema_editor.connection.alias
    for user in User.objects.using(database).order_by('pk').iterator():
        base = re.sub(
            r'[^\w.@+-]',
            '_',
            user.email.partition('@')[0],
            flags=re.UNICODE,
        )[:150].strip('_') or f'user_{user.pk}'
        candidate = base
        suffix = 2
        while (
            User.objects.using(database)
            .filter(username__iexact=candidate)
            .exclude(pk=user.pk)
            .exists()
        ):
            suffix_text = f'_{suffix}'
            candidate = f'{base[:150 - len(suffix_text)]}{suffix_text}'
            suffix += 1
        user.username = candidate
        user.save(using=database, update_fields=['username'])


def clear_usernames(apps, schema_editor):
    User = apps.get_model('users', 'User')
    User.objects.using(schema_editor.connection.alias).update(username=None)


class Migration(migrations.Migration):
    dependencies: ClassVar[list[tuple[str, str]]] = [
        ('users', '0005_user_country'),
    ]

    operations: ClassVar[list] = [
        migrations.AddField(
            model_name='user',
            name='username',
            field=models.CharField(
                blank=True,
                max_length=150,
                null=True,
                validators=[UnicodeUsernameValidator()],
            ),
        ),
        migrations.RunPython(populate_usernames, clear_usernames),
        migrations.AlterField(
            model_name='user',
            name='username',
            field=models.CharField(
                max_length=150,
                unique=True,
                validators=[UnicodeUsernameValidator()],
            ),
        ),
    ]
