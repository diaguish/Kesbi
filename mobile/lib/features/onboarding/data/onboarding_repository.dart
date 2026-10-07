import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/api/api_client.dart';
import '../../tresorerie/domain/compte.dart';

/// Profil renvoyé par `GET /api/me/`.
class MonProfil {
  const MonProfil({required this.phone, this.boutiqueNom, this.ouvertureFaite = false});

  final String phone;
  final String? boutiqueNom;
  final bool ouvertureFaite;

  bool get aUneBoutique => boutiqueNom != null;

  factory MonProfil.fromJson(Map<String, dynamic> json) {
    final boutiques = (json['boutiques'] as List).cast<Map<String, dynamic>>();
    final boutique = boutiques.isEmpty ? null : boutiques.first;
    return MonProfil(
      phone: json['phone'] as String? ?? '',
      boutiqueNom: boutique?['nom'] as String?,
      ouvertureFaite: boutique?['ouverture_faite'] as bool? ?? false,
    );
  }
}

/// Appels de l'onboarding (A6, A7) et de la suppression de compte (A8).
///
/// Nécessite le réseau : l'inscription se fait en ligne (OTP). Les UUID sont
/// générés ici (ADR 0002) et les rejeux sont sans effet côté serveur.
class OnboardingRepository {
  OnboardingRepository(this._api, {Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final ApiClient _api;
  final Uuid _uuid;

  Future<MonProfil> monProfil() async => MonProfil.fromJson(await _api.getJson('/api/me/'));

  Future<void> creerBoutique({required String nom, String activite = ''}) async {
    try {
      await _api.postJson('/api/boutiques/', {
        'id': _uuid.v4(),
        'nom': nom.trim(),
        'activite': activite.trim(),
        'created_at': DateTime.now().toUtc().toIso8601String(),
      });
    } on ApiException catch (e) {
      // 409 : la boutique existe déjà (envoi précédent arrivé malgré une erreur réseau).
      if (e.statusCode != 409) rethrow;
    }
  }

  /// Soldes d'ouverture (« Ignorer » = 0), un par compte (ADR 0004).
  Future<void> enregistrerSoldesOuverture(Map<Compte, int> soldes) async {
    for (final compte in Compte.values) {
      try {
        await _api.postJson('/api/transactions/', {
          'id': _uuid.v4(),
          'type': 'ouverture',
          'compte': compte.api,
          'montant': soldes[compte] ?? 0,
          'created_at': DateTime.now().toUtc().toIso8601String(),
        });
      } on ApiException catch (e) {
        // 409 : déjà enregistré lors d'une tentative précédente.
        if (e.statusCode != 409) rethrow;
      }
    }
  }

  /// Suppression définitive : boutique, transactions et compte Supabase.
  Future<void> supprimerCompte() => _api.delete('/api/compte/');
}

final onboardingRepositoryProvider = Provider<OnboardingRepository>(
  (ref) => OnboardingRepository(ref.watch(apiClientProvider)),
);
