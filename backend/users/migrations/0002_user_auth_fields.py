import uuid

from django.conf import settings
from django.contrib.auth.validators import UnicodeUsernameValidator
from django.db import migrations, models
from django.utils.text import slugify


def backfill_usernames_and_phone_numbers(apps, schema_editor):
    User = apps.get_model("users", "User")
    database = schema_editor.connection.alias
    queryset = User.objects.using(database).order_by("pk")
    phone_owners = {}

    for user in queryset.iterator():
        if not user.username:
            base = slugify(user.email.split("@", 1)[0])[:140] or "user"
            candidate = base
            suffix = 1
            while User.objects.using(database).filter(
                username__iexact=candidate
            ).exclude(pk=user.pk).exists():
                candidate = f"{base[:140]}-{suffix}"
                suffix += 1
            user.username = candidate

        phone_number = (user.legacy_telephone or "").strip()
        if phone_number:
            previous_owner = phone_owners.get(phone_number)
            if previous_owner is None:
                phone_owners[phone_number] = user.pk
                user.phone_number = phone_number
            else:
                User.objects.using(database).filter(pk=previous_owner).update(
                    phone_number=None
                )
                user.phone_number = None

        user.save(
            update_fields=("username", "phone_number"),
            using=database,
        )


def rename_user_content_type(apps, schema_editor):
    ContentType = apps.get_model("contenttypes", "ContentType")
    database = schema_editor.connection.alias
    legacy = ContentType.objects.using(database).filter(
        app_label="accounts",
        model="user",
    ).first()
    current_exists = ContentType.objects.using(database).filter(
        app_label="users",
        model="user",
    ).exists()
    if legacy and not current_exists:
        legacy.app_label = "users"
        legacy.save(update_fields=("app_label",), using=database)


def restore_user_content_type(apps, schema_editor):
    ContentType = apps.get_model("contenttypes", "ContentType")
    database = schema_editor.connection.alias
    current = ContentType.objects.using(database).filter(
        app_label="users",
        model="user",
    ).first()
    legacy_exists = ContentType.objects.using(database).filter(
        app_label="accounts",
        model="user",
    ).exists()
    if current and not legacy_exists:
        current.app_label = "accounts"
        current.save(update_fields=("app_label",), using=database)


class Migration(migrations.Migration):
    dependencies = [
        ("users", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="username",
            field=models.CharField(blank=True, max_length=150, null=True),
        ),
        migrations.SeparateDatabaseAndState(
            state_operations=[
                migrations.RenameField(
                    model_name="user",
                    old_name="telephone",
                    new_name="legacy_telephone",
                ),
                migrations.AlterField(
                    model_name="user",
                    name="legacy_telephone",
                    field=models.CharField(
                        blank=True,
                        db_column="telephone",
                        editable=False,
                        max_length=32,
                    ),
                ),
            ],
        ),
        migrations.AddField(
            model_name="user",
            name="phone_number",
            field=models.CharField(blank=True, max_length=32, null=True, unique=True),
        ),
        migrations.RunPython(backfill_usernames_and_phone_numbers, migrations.RunPython.noop),
        migrations.RunPython(rename_user_content_type, restore_user_content_type),
        migrations.AlterField(
            model_name="user",
            name="username",
            field=models.CharField(
                max_length=150,
                unique=True,
                validators=[UnicodeUsernameValidator()],
            ),
        ),
        migrations.AddField(
            model_name="user",
            name="gender",
            field=models.CharField(
                blank=True,
                choices=[
                    ("male", "Male"),
                    ("female", "Female"),
                    ("other", "Other"),
                    ("prefer_not_to_say", "Prefer not to say"),
                ],
                default="",
                max_length=32,
            ),
            preserve_default=False,
        ),
        migrations.AddField(
            model_name="user",
            name="email_verified",
            field=models.BooleanField(default=True),
        ),
        migrations.AddField(
            model_name="user",
            name="auth_version",
            field=models.PositiveIntegerField(default=1),
        ),
        migrations.CreateModel(
            name="LoginChallenge",
            fields=[
                (
                    "id",
                    models.UUIDField(
                        default=uuid.uuid4,
                        editable=False,
                        primary_key=True,
                        serialize=False,
                    ),
                ),
                ("email_code_hash", models.CharField(max_length=128)),
                ("phone_code_hash", models.CharField(max_length=128)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("expires_at", models.DateTimeField()),
                ("last_sent_at", models.DateTimeField()),
                ("attempts", models.PositiveSmallIntegerField(default=0)),
                ("used_at", models.DateTimeField(blank=True, null=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=models.deletion.CASCADE,
                        related_name="login_challenges",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "indexes": [
                    models.Index(
                        fields=["user", "expires_at"],
                        name="users_lc_user_exp_idx",
                    )
                ],
            },
        ),
    ]
