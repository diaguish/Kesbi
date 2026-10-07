"""Isolation des données par boutique (règle n°4, ADR 0007).

Django se connecte à Postgres avec un rôle privilégié : la RLS ne le protège pas.
**Toute vue qui lit ou écrit des données métier DOIT utiliser `BoutiqueScopedMixin`.**
"""

import uuid

from rest_framework import exceptions

BOUTIQUE_HEADER = "X-Boutique-Id"


def resolve_boutique(request):
    """Boutique courante de l'utilisateur authentifié (mise en cache sur la requête).

    MVP : l'utilisateur a une seule boutique, l'en-tête est facultatif. Si un jour
    il en a plusieurs (P2), l'app devra préciser `X-Boutique-Id`.
    """
    if hasattr(request, "_kesbi_boutique"):
        return request._kesbi_boutique

    from boutiques.models import Boutique

    boutiques = Boutique.objects.filter(membres__user_id=request.user.id, deleted_at__isnull=True)
    requested = request.headers.get(BOUTIQUE_HEADER)
    if requested:
        try:
            boutiques = boutiques.filter(id=uuid.UUID(requested))
        except ValueError as exc:
            raise exceptions.ValidationError({BOUTIQUE_HEADER: "UUID invalide."}) from exc

    found = list(boutiques[:2])
    if not found:
        # Même réponse que « n'existe pas » : ne révèle pas les boutiques des autres.
        raise exceptions.NotFound("Aucune boutique pour cet utilisateur.")
    if len(found) > 1:
        raise exceptions.ValidationError({BOUTIQUE_HEADER: "Plusieurs boutiques : en-tête requis."})

    request._kesbi_boutique = found[0]
    return found[0]


class BoutiqueScopedMixin:
    """À mettre en premier dans les vues métier (avant `GenericAPIView`).

    - lecture : uniquement les lignes de la boutique courante, hors suppressions logiques ;
    - création : `boutique` imposée par le serveur, jamais lue depuis le corps de la requête.
    """

    include_deleted = False

    def get_boutique(self):
        return resolve_boutique(self.request)

    def get_queryset(self):
        queryset = super().get_queryset().filter(boutique=self.get_boutique())
        if not self.include_deleted:
            queryset = queryset.filter(deleted_at__isnull=True)
        return queryset

    def perform_create(self, serializer):
        serializer.save(boutique=self.get_boutique())
