"""Route the deployment homepage to the polls application."""

from django.urls import path
from django.views.generic import RedirectView

from .urls import urlpatterns as application_urls

urlpatterns = [
    path("", RedirectView.as_view(url="/polls/", permanent=False)),
    *application_urls,
]
