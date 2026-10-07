"""Comptes et transactions (ADR 0004, 0009).

Règles :
- `montant` en FCFA entiers, **signé** : effet sur le solde du compte (+ entrée, − sortie).
- Le solde d'un compte = somme de ses transactions. Jamais stocké.
- Une transaction n'est jamais modifiée : on l'annule par une transaction opposée.
"""

from django.db import models
from django.db.models import Q
from django.utils import timezone

from core.models import BoutiqueScopedModel


class Compte(models.TextChoices):
    """Comptes du MVP. Pas de table : ajouter « Banque » = ajouter une valeur."""

    CAISSE = "caisse", "Caisse"
    WAVE = "wave", "Wave"
    ORANGE_MONEY = "orange_money", "Orange Money"


class TypeTransaction(models.TextChoices):
    ENCAISSEMENT = "encaissement", "Encaissement"
    DEPENSE = "depense", "Dépense"
    OUVERTURE = "ouverture", "Solde d'ouverture"
    AJUSTEMENT = "ajustement", "Correction de solde"
    TRANSFERT_SORTIE = "transfert_sortie", "Transfert (sortie)"
    TRANSFERT_ENTREE = "transfert_entree", "Transfert (entrée)"


# Seuls ces types entrent dans le chiffre d'affaires et les dépenses (ADR 0004).
TYPES_ACTIVITE = (TypeTransaction.ENCAISSEMENT, TypeTransaction.DEPENSE)

# Signe attendu du montant d'une écriture normale (une annulation a le signe inverse).
SIGNE_POSITIF = (
    TypeTransaction.ENCAISSEMENT,
    TypeTransaction.OUVERTURE,
    TypeTransaction.TRANSFERT_ENTREE,
)
SIGNE_NEGATIF = (TypeTransaction.DEPENSE, TypeTransaction.TRANSFERT_SORTIE)

MONTANT_MAX = 10**12  # 1 000 milliards FCFA : garde-fou contre les erreurs de saisie


class Transaction(BoutiqueScopedModel):
    type = models.CharField(max_length=20, choices=TypeTransaction.choices)
    compte = models.CharField(max_length=20, choices=Compte.choices)
    montant = models.BigIntegerField(help_text="FCFA, signé : effet sur le solde.")
    # Date de l'opération réelle (peut être antérieure à la saisie). UTC.
    date_operation = models.DateTimeField(default=timezone.now)
    categorie = models.CharField(max_length=60, blank=True)
    note = models.CharField(max_length=500, blank=True)
    # Annulation : écriture de montant opposé qui neutralise `annulation_de`.
    annulation_de = models.OneToOneField(
        "self",
        # RESTRICT : impossible de supprimer une écriture annulée seule, mais la
        # suppression de toute la boutique (suppression de compte) reste possible.
        on_delete=models.RESTRICT,
        null=True,
        blank=True,
        related_name="annulee_par",
    )
    # Transferts (S6) : les deux écritures partagent le même identifiant.
    transfert_id = models.UUIDField(null=True, blank=True, db_index=True)

    class Meta:
        db_table = "transaction_financiere"
        ordering = ["-date_operation", "-created_at"]
        indexes = [
            models.Index(fields=["boutique", "-date_operation"], name="tx_boutique_date"),
            models.Index(fields=["boutique", "compte"], name="tx_boutique_compte"),
        ]
        constraints = [
            # Signe cohérent avec le type ; une annulation porte le signe inverse.
            models.CheckConstraint(
                name="tx_signe_selon_type",
                condition=(
                    Q(type__in=SIGNE_POSITIF, annulation_de__isnull=True, montant__gte=0)
                    | Q(type__in=SIGNE_POSITIF, annulation_de__isnull=False, montant__lte=0)
                    | Q(type__in=SIGNE_NEGATIF, annulation_de__isnull=True, montant__lt=0)
                    | Q(type__in=SIGNE_NEGATIF, annulation_de__isnull=False, montant__gt=0)
                    | Q(type=TypeTransaction.AJUSTEMENT) & ~Q(montant=0)
                ),
            ),
            models.CheckConstraint(
                name="tx_montant_borne",
                condition=Q(montant__gt=-MONTANT_MAX, montant__lt=MONTANT_MAX),
            ),
            # Un seul solde d'ouverture par compte et par boutique.
            models.UniqueConstraint(
                fields=["boutique", "compte"],
                condition=Q(type=TypeTransaction.OUVERTURE, annulation_de__isnull=True),
                name="tx_une_ouverture_par_compte",
            ),
        ]

    def __str__(self):
        return f"{self.type} {self.montant} FCFA ({self.compte})"

    @property
    def est_annulation(self) -> bool:
        return self.annulation_de_id is not None
