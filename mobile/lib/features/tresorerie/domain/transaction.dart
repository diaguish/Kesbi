import 'compte.dart';

/// Types de transaction (ADR 0004, 0009).
enum TypeTransaction {
  encaissement('encaissement', 'Encaissement'),
  depense('depense', 'Dépense'),
  ouverture('ouverture', "Solde d'ouverture"),
  ajustement('ajustement', 'Correction de solde'),
  transfertSortie('transfert_sortie', 'Transfert (sortie)'),
  transfertEntree('transfert_entree', 'Transfert (entrée)');

  const TypeTransaction(this.api, this.label);

  final String api;
  final String label;

  static TypeTransaction fromApi(String value) =>
      values.firstWhere((t) => t.api == value);
}

/// État de synchronisation d'une écriture locale (ADR 0002).
enum SyncStatus {
  /// Enregistrée sur le téléphone, pas encore acceptée par le serveur.
  pending,

  /// Acceptée par le serveur.
  synced,

  /// Refusée par le serveur (donnée invalide) : ne sera pas renvoyée telle quelle.
  error,
}

/// Saisies du commerçant : le montant est tapé en positif, le signe vient du type.
enum TypeSaisie {
  encaissement(TypeTransaction.encaissement, categoriesEncaissement),
  depense(TypeTransaction.depense, categoriesDepense);

  const TypeSaisie(this.type, this.categories);

  final TypeTransaction type;
  final List<String> categories;

  /// Montant signé (ADR 0009) : une dépense diminue le solde.
  int montantSigne(int montantSaisi) => this == depense ? -montantSaisi : montantSaisi;
}

/// Catégories proposées pour une dépense. « Frais de transfert » est créée
/// automatiquement par les transferts (S6).
const categoriesDepense = [
  'Achat de marchandises',
  'Transport',
  'Loyer',
  'Salaires',
  'Électricité / eau',
  'Téléphone / internet',
  'Taxes et impôts',
  'Autre',
];

/// Catégories proposées pour un encaissement. « Règlement créance » arrive avec
/// le module Créances (S7).
const categoriesEncaissement = [
  'Vente comptant',
  'Vente en gros',
  'Prestation de service',
  'Autre',
];

/// Écriture financière. `montant` en FCFA, signé : effet sur le solde (ADR 0009).
class TransactionFinanciere {
  const TransactionFinanciere({
    required this.id,
    required this.type,
    required this.compte,
    required this.montant,
    required this.dateOperation,
    required this.createdAt,
    this.categorie = '',
    this.note = '',
    this.annulationDe,
    this.annuleePar,
    this.syncStatus = SyncStatus.pending,
    this.syncError,
  });

  final String id;
  final TypeTransaction type;
  final Compte compte;
  final int montant;

  /// UTC. Affichage : heure de Dakar (UTC+0 toute l'année).
  final DateTime dateOperation;
  final DateTime createdAt;
  final String categorie;
  final String note;

  /// Écriture annulée par celle-ci (montant opposé).
  final String? annulationDe;

  /// Écriture qui annule celle-ci, si elle existe.
  final String? annuleePar;
  final SyncStatus syncStatus;
  final String? syncError;

  bool get estAnnulation => annulationDe != null;
  bool get estAnnulee => annuleePar != null;

  /// Seuls encaissements et dépenses s'annulent ici (ADR 0009).
  bool get annulable =>
      !estAnnulation &&
      !estAnnulee &&
      syncStatus != SyncStatus.error &&
      (type == TypeTransaction.encaissement || type == TypeTransaction.depense);

  Map<String, Object?> toApi() => {
    'id': id,
    'type': type.api,
    'compte': compte.api,
    'montant': montant,
    'date_operation': dateOperation.toUtc().toIso8601String(),
    'categorie': categorie,
    'note': note,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  factory TransactionFinanciere.fromApi(Map<String, dynamic> json) =>
      TransactionFinanciere(
        id: json['id'] as String,
        type: TypeTransaction.fromApi(json['type'] as String),
        compte: Compte.fromApi(json['compte'] as String),
        montant: json['montant'] as int,
        dateOperation: DateTime.parse(json['date_operation'] as String).toUtc(),
        createdAt: DateTime.parse(json['created_at'] as String).toUtc(),
        categorie: json['categorie'] as String? ?? '',
        note: json['note'] as String? ?? '',
        annulationDe: json['annulation_de'] as String?,
        annuleePar: json['annulee_par'] as String?,
        syncStatus: SyncStatus.synced,
      );
}
