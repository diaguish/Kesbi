"""Appels à l'API d'administration de Supabase Auth (clé secrète, serveur uniquement)."""

import json
import urllib.error
import urllib.request
import uuid

from django.conf import settings


class SupabaseAdminError(Exception):
    pass


def _headers() -> dict[str, str]:
    key = settings.SUPABASE_SECRET_KEY
    if not key:
        raise SupabaseAdminError("SUPABASE_SECRET_KEY non configurée.")
    headers = {"apikey": key, "Content-Type": "application/json"}
    # Clé « legacy » service_role (JWT) : aussi en Bearer. Les clés `sb_secret_…` n'en ont pas besoin.
    if not key.startswith("sb_"):
        headers["Authorization"] = f"Bearer {key}"
    return headers


def delete_user(user_id: uuid.UUID) -> None:
    """Supprime l'utilisateur Supabase. Déjà supprimé (404) = succès (idempotent)."""
    request = urllib.request.Request(
        f"{settings.SUPABASE_URL}/auth/v1/admin/users/{user_id}",
        method="DELETE",
        headers=_headers(),
        data=json.dumps({"should_soft_delete": False}).encode(),
    )
    try:
        with urllib.request.urlopen(request, timeout=15):
            return
    except urllib.error.HTTPError as exc:
        if exc.code == 404:
            return
        raise SupabaseAdminError(f"Supabase a répondu {exc.code}.") from exc
    except (urllib.error.URLError, TimeoutError) as exc:
        raise SupabaseAdminError("Supabase injoignable.") from exc
