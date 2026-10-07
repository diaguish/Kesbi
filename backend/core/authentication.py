"""Authentification DRF par JWT Supabase (ADR 0007).

L'app obtient un JWT auprès de Supabase Auth (OTP SMS) et l'envoie dans
`Authorization: Bearer <jwt>`. Django le vérifie à chaque requête :
signature, expiration, audience `authenticated`, émetteur du projet.

- Projets récents (clés asymétriques ES256/RS256) : clé publique via JWKS.
- Projets « legacy » (HS256) : secret partagé `SUPABASE_JWT_SECRET`.
"""

import uuid
from dataclasses import dataclass, field
from functools import lru_cache

import jwt
from django.conf import settings
from rest_framework import authentication, exceptions

ASYMMETRIC_ALGORITHMS = {"ES256", "RS256"}
LEEWAY_SECONDS = 30


@dataclass(frozen=True)
class SupabaseUser:
    """Utilisateur authentifié, construit depuis les claims du JWT (pas de table locale)."""

    id: uuid.UUID
    phone: str = ""
    claims: dict = field(default_factory=dict, repr=False, compare=False)

    is_authenticated = True
    is_anonymous = False


@lru_cache(maxsize=1)
def get_jwks_client(jwks_url: str) -> jwt.PyJWKClient:
    # Le client met en cache le jeu de clés (5 min) : pas d'appel réseau par requête.
    return jwt.PyJWKClient(jwks_url, cache_jwk_set=True, lifespan=300, timeout=5)


def issuer() -> str:
    return f"{settings.SUPABASE_URL}/auth/v1"


def decode_supabase_jwt(token: str) -> dict:
    """Vérifie le JWT et renvoie ses claims. Lève `jwt.InvalidTokenError` sinon."""
    if not settings.SUPABASE_URL:
        raise jwt.InvalidTokenError("SUPABASE_URL non configurée.")

    algorithm = jwt.get_unverified_header(token).get("alg")
    if algorithm in ASYMMETRIC_ALGORITHMS:
        try:
            key = get_jwks_client(f"{issuer()}/.well-known/jwks.json").get_signing_key_from_jwt(token).key
        except jwt.PyJWKClientError as exc:
            raise jwt.InvalidTokenError(f"Clé de signature introuvable : {exc}") from exc
    elif algorithm == "HS256" and settings.SUPABASE_JWT_SECRET:
        key = settings.SUPABASE_JWT_SECRET
    else:
        raise jwt.InvalidAlgorithmError(f"Algorithme non accepté : {algorithm}")

    return jwt.decode(
        token,
        key,
        algorithms=[algorithm],
        audience=settings.SUPABASE_JWT_AUDIENCE,
        issuer=issuer(),
        leeway=LEEWAY_SECONDS,
        options={"require": ["exp", "iat", "sub", "aud", "iss"]},
    )


class SupabaseJWTAuthentication(authentication.BaseAuthentication):
    keyword = "Bearer"

    def authenticate(self, request):
        header = authentication.get_authorization_header(request).split()
        if not header or header[0].lower() != self.keyword.lower().encode():
            return None
        if len(header) != 2:
            raise exceptions.AuthenticationFailed("En-tête Authorization invalide.")

        try:
            claims = decode_supabase_jwt(header[1].decode())
        except (jwt.InvalidTokenError, UnicodeDecodeError) as exc:
            raise exceptions.AuthenticationFailed("Jeton invalide ou expiré.") from exc

        # Les connexions anonymes Supabase ne donnent pas accès à l'API.
        if claims.get("is_anonymous"):
            raise exceptions.AuthenticationFailed("Session anonyme refusée.")
        try:
            user_id = uuid.UUID(claims["sub"])
        except ValueError as exc:
            raise exceptions.AuthenticationFailed("Identifiant utilisateur invalide.") from exc

        return SupabaseUser(id=user_id, phone=claims.get("phone", ""), claims=claims), claims

    def authenticate_header(self, request):
        # Permet à DRF de répondre 401 (et non 403) sans jeton.
        return f'{self.keyword} realm="api"'
