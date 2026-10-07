from django.db import IntegrityError, transaction
from django.db.models import Count, IntegerField, OuterRef, Subquery
from django.db.models.functions import Coalesce
from rest_framework import exceptions, generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from core import supabase_admin
from core.scoping import resolve_boutique
from core.views import Conflict
from tresorerie.models import Compte, Transaction, TypeTransaction

from .models import Boutique, Membre
from .serializers import BoutiqueSerializer


def boutiques_of(user):
    return Boutique.objects.filter(membres__user_id=user.id, deleted_at__isnull=True)


class MeView(APIView):
    """Utilisateur courant et ses boutiques. Permet à l'app de savoir si l'onboarding est fait.

    `ouverture_faite` : les soldes d'ouverture des 3 comptes sont saisis (dernière étape).
    """

    def get(self, request):
        ouvertures = (
            Transaction.objects.filter(
                boutique=OuterRef("pk"), type=TypeTransaction.OUVERTURE, annulation_de__isnull=True
            )
            .values("boutique")
            .annotate(n=Count("compte", distinct=True))
            .values("n")
        )
        boutiques = boutiques_of(request.user).annotate(
            nb_ouvertures=Coalesce(Subquery(ouvertures, output_field=IntegerField()), 0)
        )
        return Response(
            {
                "id": str(request.user.id),
                "phone": request.user.phone,
                "boutiques": [
                    BoutiqueSerializer(b).data | {"ouverture_faite": b.nb_ouvertures == len(Compte)}
                    for b in boutiques
                ],
            }
        )


class ServiceIndisponible(exceptions.APIException):
    status_code = status.HTTP_503_SERVICE_UNAVAILABLE
    default_detail = "La suppression du compte a échoué. Réessayez plus tard."
    default_code = "service_indisponible"


class SuppressionCompteView(APIView):
    """Suppression définitive du compte (A8, exigence Apple + Google).

    Efface les boutiques de l'utilisateur (transactions comprises) puis l'utilisateur
    Supabase. Si Supabase échoue, rien n'est effacé (transaction SQL annulée).
    """

    def delete(self, request):
        user_id = request.user.id
        try:
            with transaction.atomic():
                # MVP : l'utilisateur est seul membre de sa boutique (P2 : ne supprimer
                # que les boutiques dont il est le seul propriétaire).
                for boutique in Boutique.objects.filter(membres__user_id=user_id):
                    boutique.delete()
                Membre.objects.filter(user_id=user_id).delete()
                supabase_admin.delete_user(user_id)
        except supabase_admin.SupabaseAdminError as exc:
            raise ServiceIndisponible() from exc
        return Response(status=status.HTTP_204_NO_CONTENT)


class BoutiqueCreateView(APIView):
    """Création de la boutique à l'onboarding. Idempotent sur l'UUID fourni par l'app."""

    def post(self, request):
        serializer = BoutiqueSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        boutique_id = serializer.validated_data["id"]

        existing = self._existing(boutique_id, request.user)
        if existing:
            return Response(BoutiqueSerializer(existing).data, status=status.HTTP_200_OK)
        # MVP : une seule boutique par utilisateur.
        if boutiques_of(request.user).exists():
            raise Conflict("Cet utilisateur a déjà une boutique.")

        try:
            with transaction.atomic():
                boutique = serializer.save()
                Membre.objects.create(
                    boutique=boutique, user_id=request.user.id, role=Membre.Role.PROPRIETAIRE
                )
        except IntegrityError:
            # Deux envois simultanés du même UUID (rejeu de la file de sync).
            existing = self._existing(boutique_id, request.user)
            if existing:
                return Response(BoutiqueSerializer(existing).data, status=status.HTTP_200_OK)
            raise
        return Response(BoutiqueSerializer(boutique).data, status=status.HTTP_201_CREATED)

    @staticmethod
    def _existing(boutique_id, user):
        boutique = Boutique.objects.filter(id=boutique_id).first()
        if boutique is None:
            return None
        if not boutique.membres.filter(user_id=user.id).exists():
            raise Conflict("Cet identifiant est déjà utilisé.")
        return boutique


class BoutiqueCouranteView(generics.RetrieveUpdateAPIView):
    """Boutique de l'utilisateur : lecture et modification (nom, activité)."""

    serializer_class = BoutiqueSerializer
    http_method_names = ["get", "patch", "options"]

    def get_object(self):
        return resolve_boutique(self.request)
