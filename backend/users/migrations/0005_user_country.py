from typing import ClassVar

from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies: ClassVar[list[tuple[str, str]]] = [
        ('users', '0004_named_capability_permissions'),
    ]

    operations: ClassVar[list] = [
        migrations.AddField(
            model_name='user',
            name='country',
            field=models.CharField(default='', max_length=100),
            preserve_default=False,
        ),
    ]
