"""Outils de test : faux JWT Supabase signés avec une clé locale."""

import time
import uuid
from types import SimpleNamespace
from unittest import mock

import jwt
from cryptography.hazmat.primitives.asymmetric import ec
from django.test import override_settings
from rest_framework.test import APITestCase

TEST_SUPABASE_URL = "https://test-project.supabase.co"
TEST_JWT_SECRET = "test-legacy-secret-with-at-least-32-bytes!"
TEST_PRIVATE_KEY = ec.generate_private_key(ec.SECP256R1())


def make_token(user_id=None, *, key=TEST_PRIVATE_KEY, algorithm="ES256", **claims):
    now = int(time.time())
    payload = {
        "sub": str(user_id or uuid.uuid4()),
        "aud": "authenticated",
        "role": "authenticated",
        "iss": f"{TEST_SUPABASE_URL}/auth/v1",
        "iat": now,
        "exp": now + 3600,
        "phone": "221770000000",
    }
    payload.update(claims)
    payload = {k: v for k, v in payload.items() if v is not None}
    return jwt.encode(payload, key, algorithm=algorithm, headers={"kid": "test-key"})


class FakeJWKSClient:
    def get_signing_key_from_jwt(self, token):
        return SimpleNamespace(key=TEST_PRIVATE_KEY.public_key())


@override_settings(SUPABASE_URL=TEST_SUPABASE_URL, SUPABASE_JWT_SECRET=TEST_JWT_SECRET)
class SupabaseAPITestCase(APITestCase):
    """Les requêtes sont authentifiées par un JWT ES256 vérifié via un faux JWKS."""

    def setUp(self):
        super().setUp()
        patcher = mock.patch("core.authentication.get_jwks_client", return_value=FakeJWKSClient())
        patcher.start()
        self.addCleanup(patcher.stop)

    def authenticate(self, user_id=None, **claims):
        user_id = user_id or uuid.uuid4()
        self.client.credentials(HTTP_AUTHORIZATION=f"Bearer {make_token(user_id, **claims)}")
        return user_id
