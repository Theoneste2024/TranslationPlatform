from django.urls import path

from users.permissions import (
    CanAnalyzeVideo,
    CanSpeechTranslate,
    CanTranslateText,
    CanViewHealthStatus,
    require_permission,
)

from . import views

health_view = require_permission(CanViewHealthStatus)(views.HealthView.as_view())
text_translation_view = require_permission(CanTranslateText)(
    views.TranslateTextView.as_view()
)
speech_translation_view = require_permission(CanSpeechTranslate)(
    views.SpeechTranslateView.as_view()
)
video_analysis_view = require_permission(CanAnalyzeVideo)(
    views.AnalyzeVideoView.as_view()
)

urlpatterns = [
    path(
        'api/v1/health/',
        health_view,
        name='v1-health',
    ),
    path(
        'api/v1/translate_text/',
        text_translation_view,
        name='v1-translate_text',
    ),
    path(
        'api/v1/speech_translate/',
        speech_translation_view,
        name='v1-speech_translate',
    ),
    path(
        'api/v1/analyze_video/',
        video_analysis_view,
        name='v1-analyze_video',
    ),
    path('api/health', health_view, name='health'),
    path(
        'api/translate_text',
        text_translation_view,
        name='translate_text',
    ),
    path(
        'api/speech_translate',
        speech_translation_view,
        name='speech_translate',
    ),
    path(
        'api/analyze_video',
        video_analysis_view,
        name='analyze_video',
    ),
]
