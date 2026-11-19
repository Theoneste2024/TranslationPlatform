from rest_framework import serializers
from .models import Advert


class TextTranslationSerializer(serializers.Serializer):
    text = serializers.CharField(allow_blank=False)
    source_language = serializers.CharField()
    target_language = serializers.CharField()


class TranslationSpeechSerializer(serializers.Serializer):
    text = serializers.CharField(allow_blank=False, max_length=4096)
    target_language = serializers.CharField()


class SpeechTranslationSerializer(serializers.Serializer):
    source_language = serializers.CharField()
    target_language = serializers.CharField()


class VideoAnalysisSerializer(serializers.Serializer):
    mode = serializers.ChoiceField(
        choices=("translate", "summarize"),
        required=False,
        default="translate",
    )
    source_language = serializers.CharField(required=False, default="auto")
    target_language = serializers.CharField(required=False, default="en")
    youtube_url = serializers.CharField(required=False, allow_blank=True)
    audio = serializers.BooleanField(required=False, default=False)
    video = serializers.FileField(required=False)


class Base64AudioSerializer(serializers.Serializer):
    audio = serializers.CharField(allow_blank=False)
    source_language = serializers.CharField()
    target_language = serializers.CharField()


class AdvertSerializer(serializers.ModelSerializer):
    image_url = serializers.SerializerMethodField()
    created_by_name = serializers.CharField(
        source='created_by.username',
        read_only=True,
        default='',
    )

    class Meta:
        model = Advert
        fields = [
            'id',
            'title',
            'description',
            'image',
            'image_url',
            'link_url',
            'is_active',
            'created_by_name',
            'created_at',
            'updated_at',
        ]
        read_only_fields = [
            'id',
            'image_url',
            'created_by_name',
            'created_at',
            'updated_at',
        ]

    def get_image_url(self, obj):
        request = self.context.get('request')
        if not obj.image:
            return ''
        return request.build_absolute_uri(obj.image.url) if request else obj.image.url
