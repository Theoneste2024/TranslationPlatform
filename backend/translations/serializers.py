from rest_framework import serializers


class TextTranslationSerializer(serializers.Serializer):
    text = serializers.CharField(allow_blank=False)
    source_language = serializers.CharField()
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
