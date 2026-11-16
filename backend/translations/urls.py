from django.urls import path

from users.permissions import (
    CanAnalyzeVideo,
    CanSpeechTranslate,
    CanTranslateText,
    CanViewHealthStatus,
    require_permission,
)

from . import views

urlpatterns = [
    path(
        'api/health',
        require_permission(CanViewHealthStatus)(views.HealthView.as_view()),
        name='health',
    ),
    path(
        'api/translate_text',
        require_permission(CanTranslateText)(views.TranslateTextView.as_view()),
        name='translate_text',
    ),
    path(
        'api/speech_translate',
        require_permission(CanSpeechTranslate)(views.SpeechTranslateView.as_view()),
        name='speech_translate',
    ),
    path(
        'api/analyze_video',
        require_permission(CanAnalyzeVideo)(views.AnalyzeVideoView.as_view()),
        name='analyze_video',
    ),
]
