from django.db import models


class Translation(models.Model):
    class Kind(models.TextChoices):
        TEXT = 'text', 'Text'
        SPEECH = 'speech', 'Speech'
        VIDEO = 'video', 'Video'

    class Status(models.TextChoices):
        PROCESSING = 'processing', 'Processing'
        COMPLETED = 'completed', 'Completed'
        FAILED = 'failed', 'Failed'

    kind = models.CharField(max_length=16, choices=Kind.choices, db_index=True)
    status = models.CharField(
        max_length=16,
        choices=Status.choices,
        default=Status.PROCESSING,
        db_index=True,
    )
    source_language = models.CharField(max_length=100, blank=True)
    target_language = models.CharField(max_length=100, blank=True)
    source_text = models.TextField(blank=True)
    translated_text = models.TextField(blank=True)
    summary_text = models.TextField(blank=True)
    source_url = models.TextField(blank=True)
    source_file_name = models.CharField(max_length=255, blank=True)
    source_file_content_type = models.CharField(max_length=150, blank=True)
    source_file_size = models.PositiveBigIntegerField(null=True, blank=True)
    segments = models.JSONField(default=list, blank=True)
    audio_base64 = models.TextField(blank=True)
    request_metadata = models.JSONField(default=dict, blank=True)
    error_message = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True, db_index=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        ordering = ['-created_at']

    def __str__(self) -> str:
        return f'{self.get_kind_display()} translation #{self.pk} ({self.status})'