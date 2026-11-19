from django.urls import path

from users.permissions import (
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
text_translation_speech_view = require_permission(CanTranslateText)(
    views.TranslateTextSpeechView.as_view()
)
speech_translation_view = require_permission(CanSpeechTranslate)(
    views.SpeechTranslateView.as_view()
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
        'api/v1/translate_text/speech/',
        text_translation_speech_view,
        name='v1-translate_text-speech',
    ),
    path(
        'api/v1/speech_translate/',
        speech_translation_view,
        name='v1-speech_translate',
    ),
    path('api/v1/adverts/', views.AdvertListView.as_view(), name='v1-adverts'),
    path(
        'api/v1/adverts/<int:advert_id>/',
        views.AdvertDetailView.as_view(),
        name='v1-advert-detail',
    ),
    path('api/health', health_view, name='health'),
    path(
        'api/translate_text',
        text_translation_view,
        name='translate_text',
    ),
    path(
        'api/translate_text/speech',
        text_translation_speech_view,
        name='translate_text_speech',
    ),
    path(
        'api/speech_translate',
        speech_translation_view,
        name='speech_translate',
    ),
]
