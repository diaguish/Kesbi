from django.db import IntegrityError, transaction
from rest_framework import generics, status
from rest_framework.response import Response
from rest_framework.views import APIView

from core.scoping import resolve_boutique
from core.views import Conflict

from .models import Boutique, Membre
from .serializers import BoutiqueSerializer


def boutiques_of(user):
    return Boutique.objects.filter(membres__user_id=user.id, deleted_at__isnull=True)


class MeView(APIView):
    """Utilisateur courant et ses boutiques. Permet à l'app de savoir si l'onboarding est fait."""

    def get(self, request):
        return Response(
            {
                "id": str(request.user.id),
                "phone": request.user.phone,
                "boutiques": BoutiqueSerializer(boutiques_of(request.user), many=True).data,
            }
        )


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
