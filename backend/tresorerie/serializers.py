from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from .models import MONTANT_MAX, SIGNE_NEGATIF, SIGNE_POSITIF, Compte, Transaction, TypeTransaction

# Types que l'app peut créer directement. Les transferts passeront par un endpoint
# dédié (S6) qui crée les deux écritures liées de façon atomique.
TYPES_CREABLES = (
    TypeTransaction.ENCAISSEMENT,
    TypeTransaction.DEPENSE,
    TypeTransaction.OUVERTURE,
    TypeTransaction.AJUSTEMENT,
)

# Tolérance sur l'horloge du téléphone.
AVANCE_MAX = timedelta(days=1)


class TransactionSerializer(serializers.ModelSerializer):
    # UUID généré par l'app (ADR 0002) : sert de clé d'idempotence.
    id = serializers.UUIDField()
    type = serializers.ChoiceField(choices=[(t.value, t.label) for t in TYPES_CREABLES])
    compte = serializers.ChoiceField(choices=Compte.choices)
    montant = serializers.IntegerField(min_value=-MONTANT_MAX + 1, max_value=MONTANT_MAX - 1)
    annulation_de = serializers.UUIDField(source="annulation_de_id", read_only=True)
    annulee_par = serializers.SerializerMethodField()

    class Meta:
        model = Transaction
        fields = [
            "id",
            "type",
            "compte",
            "montant",
            "date_operation",
            "categorie",
            "note",
            "annulation_de",
            "annulee_par",
            "transfert_id",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["annulation_de", "transfert_id", "updated_at"]
        extra_kwargs = {
            "created_at": {"required": False},
            "date_operation": {"required": False},
        }

    def get_annulee_par(self, obj):
        annulation = getattr(obj, "annulee_par", None)
        return str(annulation.id) if annulation else None

    def validate_date_operation(self, value):
        if value > timezone.now() + AVANCE_MAX:
            raise serializers.ValidationError("La date ne peut pas être dans le futur.")
        return value

    def validate(self, attrs):
        type_, montant = attrs["type"], attrs["montant"]
        if type_ in SIGNE_POSITIF and type_ != TypeTransaction.OUVERTURE and montant <= 0:
            raise serializers.ValidationError({"montant": "Le montant doit être positif."})
        if type_ == TypeTransaction.OUVERTURE and montant < 0:
            raise serializers.ValidationError({"montant": "Le solde d'ouverture ne peut pas être négatif."})
        if type_ in SIGNE_NEGATIF and montant >= 0:
            raise serializers.ValidationError(
                {"montant": "Une dépense s'enregistre avec un montant négatif (effet sur le solde)."}
            )
        if type_ == TypeTransaction.AJUSTEMENT and montant == 0:
            raise serializers.ValidationError({"montant": "Une correction de 0 FCFA est inutile."})
        if type_ in (TypeTransaction.ENCAISSEMENT, TypeTransaction.DEPENSE) and not attrs.get(
            "categorie", ""
        ).strip():
            raise serializers.ValidationError({"categorie": "La catégorie est obligatoire."})
        return attrs


class AnnulationSerializer(serializers.Serializer):
    """Corps de `POST /api/transactions/<id>/annuler/`."""

    # UUID de l'écriture d'annulation, généré par l'app (idempotence).
    id = serializers.UUIDField()
    note = serializers.CharField(max_length=500, required=False, allow_blank=True)
    created_at = serializers.DateTimeField(required=False)


class SoldeSerializer(serializers.Serializer):
    compte = serializers.ChoiceField(choices=Compte.choices)
    solde = serializers.IntegerField()
