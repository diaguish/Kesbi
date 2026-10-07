import uuid
from datetime import timedelta

from django.db import IntegrityError, transaction
from django.test import TestCase
from django.urls import reverse
from django.utils import timezone

from boutiques.models import Boutique, Membre
from core.testing import SupabaseAPITestCase

from .models import Transaction, TypeTransaction


def creer_boutique(user_id, nom="Boutique Awa"):
    boutique = Boutique.objects.create(id=uuid.uuid4(), nom=nom)
    Membre.objects.create(boutique=boutique, user_id=user_id)
    return boutique


class TransactionAPITests(SupabaseAPITestCase):
    url = reverse("transactions")
    soldes_url = reverse("soldes")

    def setUp(self):
        super().setUp()
        self.user_id = self.authenticate()
        self.boutique = creer_boutique(self.user_id)

    def poster(self, **champs):
        payload = {
            "id": str(uuid.uuid4()),
            "type": "encaissement",
            "compte": "caisse",
            "montant": 25000,
            "categorie": "Vente comptant",
        } | champs
        return self.client.post(self.url, payload, format="json")

    def soldes(self):
        data = self.client.get(self.soldes_url).json()
        return {c["compte"]: c["solde"] for c in data["comptes"]}, data["total"]

    # --- Création ---------------------------------------------------------------

    def test_encaissement_cree(self):
        response = self.poster()
        self.assertEqual(response.status_code, 201, response.content)
        tx = Transaction.objects.get()
        self.assertEqual((tx.montant, tx.boutique_id), (25000, self.boutique.id))

    def test_rejeu_idempotent(self):
        tx_id = str(uuid.uuid4())
        self.assertEqual(self.poster(id=tx_id).status_code, 201)
        rejeu = self.poster(id=tx_id, montant=99999)
        self.assertEqual(rejeu.status_code, 200)
        self.assertEqual(rejeu.json()["montant"], 25000)  # l'existante, inchangée
        self.assertEqual(Transaction.objects.count(), 1)

    def test_uuid_d_une_autre_boutique_409(self):
        tx_id = str(uuid.uuid4())
        self.poster(id=tx_id)
        autre_user = self.authenticate()
        creer_boutique(autre_user, "Autre")
        self.assertEqual(self.poster(id=tx_id).status_code, 409)

    def test_boutique_imposee_par_le_serveur(self):
        autre = creer_boutique(uuid.uuid4(), "Autre")
        self.poster(boutique=str(autre.id))
        self.assertEqual(Transaction.objects.get().boutique_id, self.boutique.id)

    def test_montant_entier_obligatoire(self):
        self.assertEqual(self.poster(montant=2500.5).status_code, 400)
        self.assertEqual(self.poster(montant="abc").status_code, 400)

    def test_signe_selon_le_type(self):
        self.assertEqual(self.poster(montant=-100).status_code, 400)  # encaissement négatif
        self.assertEqual(self.poster(type="depense", montant=8000, categorie="Transport").status_code, 400)
        self.assertEqual(self.poster(type="depense", montant=-8000, categorie="Transport").status_code, 201)
        self.assertEqual(self.poster(type="ajustement", montant=0, categorie="").status_code, 400)
        self.assertEqual(self.poster(type="ajustement", montant=-500, categorie="").status_code, 201)

    def test_categorie_obligatoire_pour_l_activite(self):
        self.assertEqual(self.poster(categorie="").status_code, 400)
        self.assertEqual(self.poster(type="ouverture", montant=0, categorie="").status_code, 201)

    def test_transfert_non_creable_directement(self):
        self.assertEqual(self.poster(type="transfert_entree").status_code, 400)

    def test_compte_inconnu(self):
        self.assertEqual(self.poster(compte="banque").status_code, 400)

    def test_date_dans_le_futur_refusee(self):
        demain = (timezone.now() + timedelta(days=2)).isoformat()
        self.assertEqual(self.poster(date_operation=demain).status_code, 400)

    def test_une_seule_ouverture_par_compte(self):
        self.assertEqual(self.poster(type="ouverture", montant=10000).status_code, 201)
        self.assertEqual(self.poster(type="ouverture", montant=20000).status_code, 409)
        self.assertEqual(self.poster(type="ouverture", compte="wave", montant=0).status_code, 201)

    def test_pas_de_modification_ni_suppression(self):
        tx_id = self.poster().json()["id"]
        detail = reverse("transaction", args=[tx_id])
        self.assertEqual(self.client.patch(detail, {"montant": 1}, format="json").status_code, 405)
        self.assertEqual(self.client.delete(detail).status_code, 405)

    # --- Soldes -----------------------------------------------------------------

    def test_soldes_calcules(self):
        self.poster(type="ouverture", montant=200000)
        self.poster(type="ouverture", compte="wave", montant=150000)
        self.poster(montant=25000)
        self.poster(type="depense", montant=-8000, categorie="Transport")
        self.poster(type="ajustement", compte="wave", montant=-2000, categorie="")
        par_compte, total = self.soldes()
        self.assertEqual(par_compte, {"caisse": 217000, "wave": 148000, "orange_money": 0})
        self.assertEqual(total, 365000)

    # --- Annulation -------------------------------------------------------------

    def annuler(self, tx_id, annulation_id=None):
        return self.client.post(
            reverse("transaction-annuler", args=[tx_id]),
            {"id": str(annulation_id or uuid.uuid4())},
            format="json",
        )

    def test_annulation_neutralise_le_solde(self):
        tx_id = self.poster(montant=25000).json()["id"]
        response = self.annuler(tx_id)
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.json()["montant"], -25000)
        self.assertEqual(response.json()["annulation_de"], tx_id)
        self.assertEqual(self.soldes()[1], 0)
        originale = self.client.get(reverse("transaction", args=[tx_id])).json()
        self.assertEqual(originale["annulee_par"], response.json()["id"])
        self.assertEqual(originale["montant"], 25000)  # jamais modifiée

    def test_annulation_idempotente(self):
        tx_id = self.poster().json()["id"]
        annulation_id = uuid.uuid4()
        self.assertEqual(self.annuler(tx_id, annulation_id).status_code, 201)
        self.assertEqual(self.annuler(tx_id, annulation_id).status_code, 200)
        self.assertEqual(Transaction.objects.count(), 2)

    def test_double_annulation_refusee(self):
        tx_id = self.poster().json()["id"]
        annulation = self.annuler(tx_id).json()
        self.assertEqual(self.annuler(tx_id).status_code, 409)
        self.assertEqual(self.annuler(annulation["id"]).status_code, 400)

    def test_ouverture_non_annulable(self):
        tx_id = self.poster(type="ouverture", montant=1000).json()["id"]
        self.assertEqual(self.annuler(tx_id).status_code, 400)

    # --- Liste ------------------------------------------------------------------

    def test_liste_filtrable_et_triee(self):
        maintenant = timezone.now()
        self.poster(date_operation=(maintenant - timedelta(days=3)).isoformat(), note="ancienne")
        self.poster(date_operation=maintenant.isoformat(), note="recente")
        self.poster(type="depense", montant=-500, categorie="Transport", compte="wave")

        tout = self.client.get(self.url).json()["results"]
        self.assertEqual(len(tout), 3)
        self.assertEqual(tout[-1]["note"], "ancienne")

        wave = self.client.get(self.url, {"compte": "wave"}).json()["results"]
        self.assertEqual([t["type"] for t in wave], ["depense"])

        depuis = (maintenant - timedelta(days=1)).isoformat()
        recentes = self.client.get(self.url, {"depuis": depuis}).json()["results"]
        self.assertEqual(len(recentes), 2)

        self.assertEqual(self.client.get(self.url, {"depuis": "hier"}).status_code, 400)

    # --- Isolation --------------------------------------------------------------

    def test_isolation_entre_boutiques(self):
        tx_id = self.poster(type="ouverture", montant=50000).json()["id"]

        autre_user = self.authenticate()
        creer_boutique(autre_user, "Autre")
        self.assertEqual(self.client.get(self.url).json()["results"], [])
        self.assertEqual(self.soldes()[1], 0)
        self.assertEqual(self.client.get(reverse("transaction", args=[tx_id])).status_code, 404)
        self.assertEqual(self.annuler(tx_id).status_code, 404)

    def test_sans_boutique_404(self):
        self.authenticate()
        self.assertEqual(self.poster().status_code, 404)
        self.assertEqual(self.client.get(self.soldes_url).status_code, 404)

    def test_sans_jeton_401(self):
        self.client.credentials()
        self.assertEqual(self.client.get(self.url).status_code, 401)


class ContraintesBaseTests(TestCase):
    """Les règles tiennent même si un bug contourne l'API."""

    def setUp(self):
        self.boutique = creer_boutique(uuid.uuid4())

    def creer(self, **champs):
        valeurs = {
            "id": uuid.uuid4(),
            "boutique": self.boutique,
            "type": TypeTransaction.ENCAISSEMENT,
            "compte": "caisse",
            "montant": 1000,
        } | champs
        with transaction.atomic():
            return Transaction.objects.create(**valeurs)

    def test_signe_impose_en_base(self):
        with self.assertRaises(IntegrityError):
            self.creer(montant=-1000)
        with self.assertRaises(IntegrityError):
            self.creer(type=TypeTransaction.DEPENSE, montant=1000)
        with self.assertRaises(IntegrityError):
            self.creer(type=TypeTransaction.AJUSTEMENT, montant=0)

    def test_annulation_signe_inverse(self):
        originale = self.creer()
        self.creer(montant=-1000, annulation_de=originale)
        with self.assertRaises(IntegrityError):
            self.creer(montant=-1000, annulation_de=originale)  # une seule annulation

    def test_montant_borne(self):
        with self.assertRaises(IntegrityError):
            self.creer(montant=10**12)

    def test_suppression_de_la_boutique_emporte_ses_transactions(self):
        originale = self.creer()
        self.creer(montant=-1000, annulation_de=originale)
        self.boutique.delete()
        self.assertEqual(Transaction.objects.count(), 0)

    def test_ecriture_annulee_non_supprimable_seule(self):
        from django.db.models import RestrictedError

        originale = self.creer()
        self.creer(montant=-1000, annulation_de=originale)
        with self.assertRaises(RestrictedError):
            originale.delete()
