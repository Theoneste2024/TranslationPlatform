from django.contrib import admin
from django.http import JsonResponse
from django.urls import include, path


def health_check(_request):
    return JsonResponse({"status": "ok"})


urlpatterns = [
    path("admin/", admin.site.urls),
    path("api/v1/health/", health_check, name="health"),
    path("api/v1/auth/", include("users.urls")),
    path("api/v1/", include("translations.urls")),
]
