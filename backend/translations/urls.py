from django.urls import path

from .views import AnalyzeVideoView, SpeechTranslateView, TranslateTextView


urlpatterns = [
    path("translate_text/", TranslateTextView.as_view(), name="translate_text"),
    path("speech_translate/", SpeechTranslateView.as_view(), name="speech_translate"),
    path("analyze_video/", AnalyzeVideoView.as_view(), name="analyze_video"),
]
