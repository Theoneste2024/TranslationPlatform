from django.conf import settings
from django.db import migrations, models
import django.db.models.deletion


def remove_video_permission(apps, schema_editor):
    Permission = apps.get_model('users', 'Permission')
    Permission.objects.filter(codename='CanAnalyzeVideo').delete()


class Migration(migrations.Migration):
    dependencies = [
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
        ('translations', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(remove_video_permission, migrations.RunPython.noop),
        migrations.CreateModel(
            name='Advert',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('title', models.CharField(max_length=200)),
                ('description', models.TextField(blank=True)),
                ('image', models.FileField(upload_to='adverts/')),
                ('link_url', models.URLField(blank=True)),
                ('is_active', models.BooleanField(db_index=True, default=True)),
                ('created_at', models.DateTimeField(auto_now_add=True)),
                ('updated_at', models.DateTimeField(auto_now=True)),
                ('created_by', models.ForeignKey(null=True, on_delete=django.db.models.deletion.SET_NULL, related_name='adverts', to=settings.AUTH_USER_MODEL)),
            ],
            options={'ordering': ['-created_at']},
        ),
    ]
