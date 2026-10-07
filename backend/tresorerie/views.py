from django.db import IntegrityError
from django.db import transaction as db_transaction
from django.db.models import Sum
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from rest_framework import exceptions, generics, status
from rest_framework.pagination import CursorPagination
from rest_framework.response import Response

from core.scoping import BoutiqueScopedMixin
from core.views import Conflict

from .models import Compte, Transaction, TypeTransaction
from .serializers import AnnulationSerializer, SoldeSerializer, TransactionSerializer


class TransactionPagination(CursorPagination):
    page_size = 50
    max_page_size = 200
    page_size_query_param = "taille"
    ordering = ("-date_operation", "-id")


def _rejeu(existante: Transaction, boutique, verifier=lambda tx: True) -> Response:
    """Même UUID renvoyé (file de sync rejouée) : on renvoie l'existante, sans rien modifier."""
    if existante.boutique_id != boutique.id or not verifier(existante):
        raise Conflict("Cet identifiant est déjà utilisé.")
    return Response(TransactionSerializer(existante).data, status=status.HTTP_200_OK)


class TransactionListCreateView(BoutiqueScopedMixin, generics.ListAPIView):
    """`GET` historique filtrable, `POST` nouvelle écriture (idempotent sur l'UUID)."""

    queryset = Transaction.objects.select_related("annulee_par")
    serializer_class = TransactionSerializer
    pagination_class = TransactionPagination

    def get_queryset(self):
        queryset = super().get_queryset()
        params = self.request.query_params
        if compte := params.get("compte"):
            queryset = queryset.filter(compte=compte)
        if types := params.get("type"):
            queryset = queryset.filter(type__in=types.split(","))
        for param, lookup in (("depuis", "date_operation__gte"), ("jusqu_a", "date_operation__lt")):
            if valeur := params.get(param):
                date = parse_datetime(valeur)
                if date is None:
                    raise exceptions.ValidationError({param: "Date ISO 8601 attendue."})
                queryset = queryset.filter(**{lookup: date})
        return queryset

    def post(self, request):
        boutique = self.get_boutique()
        serializer = TransactionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        tx_id = serializer.validated_data["id"]

        if existante := Transaction.objects.filter(id=tx_id).first():
            return _rejeu(existante, boutique)
        try:
            with db_transaction.atomic():
                tx = serializer.save(boutique=boutique)
        except IntegrityError:
            if existante := Transaction.objects.filter(id=tx_id).first():
                return _rejeu(existante, boutique)
            # Seule autre contrainte d'unicité : un solde d'ouverture par compte.
            raise Conflict("Un solde d'ouverture existe déjà pour ce compte. Utilisez « Corriger le solde ».")
        return Response(TransactionSerializer(tx).data, status=status.HTTP_201_CREATED)


class TransactionDetailView(BoutiqueScopedMixin, generics.RetrieveAPIView):
    """Lecture seule : une transaction n'est jamais modifiée ni supprimée (ADR 0002)."""

    queryset = Transaction.objects.select_related("annulee_par")
    serializer_class = TransactionSerializer


class AnnulerTransactionView(BoutiqueScopedMixin, generics.GenericAPIView):
    """Annule une écriture en créant l'écriture opposée (E4). Idempotent sur l'UUID fourni."""

    queryset = Transaction.objects.all()
    serializer_class = AnnulationSerializer

    def post(self, request, pk):
        boutique = self.get_boutique()
        originale = self.get_object()  # 404 si elle appartient à une autre boutique
        serializer = AnnulationSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        annulation_id = serializer.validated_data["id"]

        if existante := Transaction.objects.filter(id=annulation_id).first():
            return _rejeu(existante, boutique, lambda tx: tx.annulation_de_id == originale.id)

        if originale.est_annulation:
            raise exceptions.ValidationError("Une annulation ne peut pas être annulée.")
        if originale.type == TypeTransaction.OUVERTURE:
            raise exceptions.ValidationError("Un solde d'ouverture se corrige avec « Corriger le solde ».")
        if originale.transfert_id:
            raise exceptions.ValidationError("Un transfert s'annule depuis la Trésorerie.")
        if Transaction.objects.filter(annulation_de=originale).exists():
            raise Conflict("Cette transaction est déjà annulée.")

        try:
            with db_transaction.atomic():
                annulation = Transaction.objects.create(
                    id=annulation_id,
                    boutique=boutique,
                    type=originale.type,
                    compte=originale.compte,
                    montant=-originale.montant,
                    date_operation=timezone.now(),
                    categorie=originale.categorie,
                    note=serializer.validated_data.get("note", ""),
                    annulation_de=originale,
                    created_at=serializer.validated_data.get("created_at", timezone.now()),
                )
        except IntegrityError:
            # Deux annulations simultanées de la même écriture.
            if existante := Transaction.objects.filter(id=annulation_id).first():
                return _rejeu(existante, boutique, lambda tx: tx.annulation_de_id == originale.id)
            raise Conflict("Cette transaction est déjà annulée.")
        return Response(TransactionSerializer(annulation).data, status=status.HTTP_201_CREATED)


class SoldesView(BoutiqueScopedMixin, generics.GenericAPIView):
    """Solde de chaque compte, **calculé** depuis les transactions (règle n°2)."""

    queryset = Transaction.objects.all()
    serializer_class = SoldeSerializer
    pagination_class = None

    def get(self, request):
        sommes = dict(
            self.get_queryset().values_list("compte").annotate(total=Sum("montant")).values_list(
                "compte", "total"
            )
        )
        soldes = [{"compte": c.value, "solde": sommes.get(c.value) or 0} for c in Compte]
        return Response(
            {
                "comptes": SoldeSerializer(soldes, many=True).data,
                "total": sum(s["solde"] for s in soldes),
            }
        )
