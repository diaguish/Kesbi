import uuid

from django.db import models
from django.utils import timezone

from core.models import SyncedModel


class Boutique(SyncedModel):
    """Racine de toutes les données métier. Les autres tables portent `boutique_id`."""

    nom = models.CharField(max_length=120)
    activite = models.CharField(max_length=80, blank=True)

    class Meta:
        db_table = "boutique"

    def __str__(self):
        return self.nom


class Membre(models.Model):
    """Lien utilisateur Supabase ↔ boutique.

    MVP : un seul membre (le propriétaire) par boutique. La table est déjà prête
    pour le multi-utilisateur (P2) : il suffira d'ajouter des rôles.
    """

    class Role(models.TextChoices):
        PROPRIETAIRE = "proprietaire", "Propriétaire"

    # Créé côté serveur avec la boutique : UUID serveur, pas d'auto-incrément.
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    boutique = models.ForeignKey(Boutique, on_delete=models.CASCADE, related_name="membres")
    # `auth.users.id` côté Supabase (claim `sub` du JWT). Pas de FK : autre schéma.
    user_id = models.UUIDField(db_index=True)
    role = models.CharField(max_length=20, choices=Role.choices, default=Role.PROPRIETAIRE)
    created_at = models.DateTimeField(default=timezone.now)

    class Meta:
        db_table = "boutique_membre"
        constraints = [
            models.UniqueConstraint(fields=["boutique", "user_id"], name="membre_unique_par_boutique"),
        ]

    def __str__(self):
        return f"{self.user_id} → {self.boutique_id} ({self.role})"
