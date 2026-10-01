import time
import uuid

from cryptography.hazmat.primitives.asymmetric import ec
from django.urls import reverse

from core.testing import TEST_JWT_SECRET, SupabaseAPITestCase, make_token


class HealthTests(SupabaseAPITestCase):
    def test_public(self):
        response = self.client.get(reverse("health"))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), {"status": "ok"})


class SupabaseJWTAuthenticationTests(SupabaseAPITestCase):
    url = reverse("me")

    def get_with(self, token):
        return self.client.get(self.url, HTTP_AUTHORIZATION=f"Bearer {token}")

    def test_sans_jeton_401(self):
        self.assertEqual(self.client.get(self.url).status_code, 401)

    def test_es256_valide(self):
        user_id = uuid.uuid4()
        response = self.get_with(make_token(user_id))
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["id"], str(user_id))
        self.assertEqual(response.json()["phone"], "221770000000")

    def test_hs256_legacy_valide(self):
        token = make_token(key=TEST_JWT_SECRET, algorithm="HS256")
        self.assertEqual(self.get_with(token).status_code, 200)

    def test_hs256_refuse_sans_secret(self):
        token = make_token(key=TEST_JWT_SECRET, algorithm="HS256")
        with self.settings(SUPABASE_JWT_SECRET=""):
            self.assertEqual(self.get_with(token).status_code, 401)

    def test_expire(self):
        past = int(time.time()) - 3600
        self.assertEqual(self.get_with(make_token(iat=past - 60, exp=past)).status_code, 401)

    def test_mauvaise_audience(self):
        self.assertEqual(self.get_with(make_token(aud="anon")).status_code, 401)

    def test_mauvais_emetteur(self):
        token = make_token(iss="https://autre-projet.supabase.co/auth/v1")
        self.assertEqual(self.get_with(token).status_code, 401)

    def test_mauvaise_signature(self):
        other_key = ec.generate_private_key(ec.SECP256R1())
        self.assertEqual(self.get_with(make_token(key=other_key)).status_code, 401)

    def test_sub_manquant(self):
        self.assertEqual(self.get_with(make_token(sub=None)).status_code, 401)

    def test_alg_none_refuse(self):
        header = "eyJhbGciOiJub25lIiwidHlwIjoiSldUIn0"  # {"alg":"none","typ":"JWT"}
        payload = make_token().split(".")[1]
        self.assertEqual(self.get_with(f"{header}.{payload}.").status_code, 401)

    def test_session_anonyme_refusee(self):
        self.assertEqual(self.get_with(make_token(is_anonymous=True)).status_code, 401)

    def test_jeton_illisible(self):
        self.assertEqual(self.get_with("pas-un-jwt").status_code, 401)
