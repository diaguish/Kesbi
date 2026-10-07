from django.urls import path

from boutiques.views import BoutiqueCouranteView, BoutiqueCreateView, MeView
from core.views import HealthView

urlpatterns = [
    path("api/health/", HealthView.as_view(), name="health"),
    path("api/me/", MeView.as_view(), name="me"),
    path("api/boutiques/", BoutiqueCreateView.as_view(), name="boutique-create"),
    path("api/boutique/", BoutiqueCouranteView.as_view(), name="boutique-courante"),
]
