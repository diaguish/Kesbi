import uuid

from django.urls import reverse

from core.testing import SupabaseAPITestCase

from .models import Boutique, Membre


class BoutiqueTests(SupabaseAPITestCase):
    create_url = reverse("boutique-create")
    courante_url = reverse("boutique-courante")

    def creer(self, boutique_id=None, nom="Boutique Awa"):
        payload = {"id": str(boutique_id or uuid.uuid4()), "nom": nom, "activite": "Alimentation"}
        return self.client.post(self.create_url, payload, format="json")

    def test_creation_rattache_le_proprietaire(self):
        user_id = self.authenticate()
        response = self.creer()
        self.assertEqual(response.status_code, 201)
        membre = Membre.objects.get()
        self.assertEqual(membre.user_id, user_id)
        self.assertEqual(membre.role, Membre.Role.PROPRIETAIRE)
        self.assertEqual(str(membre.boutique_id), response.json()["id"])

    def test_creation_idempotente(self):
        self.authenticate()
        boutique_id = uuid.uuid4()
        first = self.creer(boutique_id)
        replay = self.creer(boutique_id, nom="Nom différent au rejeu")
        self.assertEqual(first.status_code, 201)
        self.assertEqual(replay.status_code, 200)
        self.assertEqual(replay.json()["nom"], "Boutique Awa")
        self.assertEqual(Boutique.objects.count(), 1)

    def test_une_seule_boutique_par_utilisateur(self):
        self.authenticate()
        self.creer()
        self.assertEqual(self.creer().status_code, 409)

    def test_uuid_d_un_autre_utilisateur(self):
        boutique_id = uuid.uuid4()
        self.authenticate()
        self.creer(boutique_id)
        self.authenticate()
        self.assertEqual(self.creer(boutique_id).status_code, 409)

    def test_nom_obligatoire(self):
        self.authenticate()
        self.assertEqual(self.creer(nom="   ").status_code, 400)

    def test_boutique_courante_isolee(self):
        self.authenticate()
        self.creer(nom="Boutique A")
        self.authenticate()
        self.creer(nom="Boutique B")
        response = self.client.get(self.courante_url)
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json()["nom"], "Boutique B")

    def test_sans_boutique_404(self):
        self.authenticate()
        self.assertEqual(self.client.get(self.courante_url).status_code, 404)

    def test_en_tete_boutique_d_un_autre_404(self):
        self.authenticate()
        autre = uuid.UUID(self.creer().json()["id"])
        self.authenticate()
        self.creer()
        response = self.client.get(self.courante_url, HTTP_X_BOUTIQUE_ID=str(autre))
        self.assertEqual(response.status_code, 404)

    def test_modification_nom_sans_changer_l_id(self):
        self.authenticate()
        boutique_id = self.creer().json()["id"]
        response = self.client.patch(
            self.courante_url, {"nom": "Nouveau nom", "id": str(uuid.uuid4())}, format="json"
        )
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.json(), response.json() | {"id": boutique_id, "nom": "Nouveau nom"})

    def test_me_liste_les_boutiques(self):
        self.authenticate()
        self.assertEqual(self.client.get(reverse("me")).json()["boutiques"], [])
        self.creer()
        self.assertEqual(len(self.client.get(reverse("me")).json()["boutiques"]), 1)
