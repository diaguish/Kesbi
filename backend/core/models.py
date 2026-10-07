"""Modèles de base communs à toutes les tables métier (ADR 0002)."""

from django.db import models
from django.utils import timezone


class SyncedModel(models.Model):
    """Entité synchronisable : UUID fourni par le client, suppression logique."""

    # Pas de valeur par défaut : l'UUID est généré par l'app (clé d'idempotence).
    id = models.UUIDField(primary_key=True, editable=True)
    # Heure de création côté appareil (UTC), envoyée par l'app.
    created_at = models.DateTimeField(default=timezone.now)
    updated_at = models.DateTimeField(auto_now=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True


class BoutiqueScopedModel(SyncedModel):
    """Table métier rattachée à une boutique. Toujours lue via `BoutiqueScopedMixin`."""

    boutique = models.ForeignKey(
        "boutiques.Boutique",
        on_delete=models.CASCADE,  # supprimée uniquement par la suppression de compte
        related_name="+",
    )

    class Meta:
        abstract = True
