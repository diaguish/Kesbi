from django.urls import path

from boutiques.views import BoutiqueCouranteView, BoutiqueCreateView, MeView, SuppressionCompteView
from core.views import HealthView
from tresorerie.views import (
    AnnulerTransactionView,
    SoldesView,
    TransactionDetailView,
    TransactionListCreateView,
)

urlpatterns = [
    path("api/health/", HealthView.as_view(), name="health"),
    path("api/me/", MeView.as_view(), name="me"),
    path("api/compte/", SuppressionCompteView.as_view(), name="compte"),
    path("api/boutiques/", BoutiqueCreateView.as_view(), name="boutique-create"),
    path("api/boutique/", BoutiqueCouranteView.as_view(), name="boutique-courante"),
    path("api/comptes/", SoldesView.as_view(), name="soldes"),
    path("api/transactions/", TransactionListCreateView.as_view(), name="transactions"),
    path("api/transactions/<uuid:pk>/", TransactionDetailView.as_view(), name="transaction"),
    path(
        "api/transactions/<uuid:pk>/annuler/",
        AnnulerTransactionView.as_view(),
        name="transaction-annuler",
    ),
]
