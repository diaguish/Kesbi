import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../domain/compte.dart';
import '../domain/transaction.dart';

/// Copie locale des transactions (sqflite), source des écrans hors ligne (ADR 0002).
///
/// Les écritures sont immuables : on insère, on change seulement l'état de sync.
class TransactionStore {
  TransactionStore(this._open);

  final Future<Database> Function() _open;
  Future<Database>? _db;

  Future<Database> get _database => _db ??= _open();

  static const _table = 'transactions';

  static Future<void> createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE $_table (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        compte TEXT NOT NULL,
        montant INTEGER NOT NULL,
        date_operation TEXT NOT NULL,
        created_at TEXT NOT NULL,
        categorie TEXT NOT NULL DEFAULT '',
        note TEXT NOT NULL DEFAULT '',
        annulation_de TEXT,
        sync_status TEXT NOT NULL,
        sync_error TEXT
      )''');
    await db.execute('CREATE INDEX tx_date ON $_table (date_operation DESC)');
    await db.execute(
      'CREATE INDEX tx_sync ON $_table (sync_status, created_at)',
    );
    await db.execute('CREATE INDEX tx_annulation ON $_table (annulation_de)');
  }

  /// Base de l'app sur le téléphone.
  static Future<Database> openDefault() async => openDatabase(
    p.join(await getDatabasesPath(), 'kesbi.db'),
    version: 1,
    onCreate: (db, _) => createSchema(db),
  );

  Future<void> insert(TransactionFinanciere tx) async {
    final db = await _database;
    await db.insert(
      _table,
      _toRow(tx),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  /// Copie serveur → locale. N'écrase jamais une écriture locale non synchronisée.
  Future<void> upsertFromServer(
    List<TransactionFinanciere> transactions,
  ) async {
    final db = await _database;
    await db.transaction((txn) async {
      for (final tx in transactions) {
        await txn.insert(
          _table,
          _toRow(tx),
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
        await txn.update(
          _table,
          {'sync_status': SyncStatus.synced.name, 'sync_error': null},
          where: 'id = ?',
          whereArgs: [tx.id],
        );
      }
    });
  }

  Future<List<TransactionFinanciere>> list({
    Compte? compte,
    Set<TypeTransaction>? types,
    DateTime? depuis,
    int? limit,
  }) async {
    final db = await _database;
    final where = <String>[];
    final args = <Object>[];
    if (compte != null) {
      where.add('t.compte = ?');
      args.add(compte.api);
    }
    if (types != null && types.isNotEmpty) {
      where.add('t.type IN (${List.filled(types.length, '?').join(', ')})');
      args.addAll(types.map((t) => t.api));
    }
    if (depuis != null) {
      where.add('t.date_operation >= ?');
      args.add(depuis.toUtc().toIso8601String());
    }
    final rows = await db.rawQuery('''
      SELECT t.*, a.id AS annulee_par
      FROM $_table t LEFT JOIN $_table a ON a.annulation_de = t.id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY t.date_operation DESC, t.created_at DESC
      ${limit == null ? '' : 'LIMIT $limit'}''', args);
    return rows.map(_fromRow).toList();
  }

  Future<TransactionFinanciere?> get(String id) async {
    final db = await _database;
    final rows = await db.rawQuery(
      '''
      SELECT t.*, a.id AS annulee_par
      FROM $_table t LEFT JOIN $_table a ON a.annulation_de = t.id
      WHERE t.id = ?''',
      [id],
    );
    return rows.isEmpty ? null : _fromRow(rows.single);
  }

  /// À envoyer au serveur, dans l'ordre de création (une annulation après son originale).
  Future<List<TransactionFinanciere>> pending() async {
    final db = await _database;
    final rows = await db.query(
      _table,
      where: 'sync_status = ?',
      whereArgs: [SyncStatus.pending.name],
      orderBy: 'created_at ASC',
    );
    return rows.map(_fromRow).toList();
  }

  Future<int> countPending() async {
    final db = await _database;
    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM $_table WHERE sync_status = ?',
            [SyncStatus.pending.name],
          ),
        ) ??
        0;
  }

  Future<void> markSynced(String id) => _setStatus(id, SyncStatus.synced, null);

  Future<void> markError(String id, String message) =>
      _setStatus(id, SyncStatus.error, message);

  /// Soldes calculés (règle n°2) : écritures en attente comprises, en erreur exclues.
  Future<Map<Compte, int>> soldes() async {
    final db = await _database;
    final rows = await db.rawQuery(
      'SELECT compte, SUM(montant) AS solde FROM $_table WHERE sync_status != ? GROUP BY compte',
      [SyncStatus.error.name],
    );
    final parCompte = {
      for (final r in rows) r['compte'] as String: (r['solde'] as int?) ?? 0,
    };
    return {for (final c in Compte.values) c: parCompte[c.api] ?? 0};
  }

  /// Déconnexion / suppression de compte : plus aucune donnée sur le téléphone.
  Future<void> clear() async {
    final db = await _database;
    await db.delete(_table);
  }

  Future<void> _setStatus(String id, SyncStatus status, String? error) async {
    final db = await _database;
    await db.update(
      _table,
      {'sync_status': status.name, 'sync_error': error},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Map<String, Object?> _toRow(TransactionFinanciere tx) => {
    'id': tx.id,
    'type': tx.type.api,
    'compte': tx.compte.api,
    'montant': tx.montant,
    'date_operation': tx.dateOperation.toUtc().toIso8601String(),
    'created_at': tx.createdAt.toUtc().toIso8601String(),
    'categorie': tx.categorie,
    'note': tx.note,
    'annulation_de': tx.annulationDe,
    'sync_status': tx.syncStatus.name,
    'sync_error': tx.syncError,
  };

  static TransactionFinanciere _fromRow(Map<String, Object?> row) =>
      TransactionFinanciere(
        id: row['id']! as String,
        type: TypeTransaction.fromApi(row['type']! as String),
        compte: Compte.fromApi(row['compte']! as String),
        montant: row['montant']! as int,
        dateOperation: DateTime.parse(row['date_operation']! as String).toUtc(),
        createdAt: DateTime.parse(row['created_at']! as String).toUtc(),
        categorie: row['categorie'] as String? ?? '',
        note: row['note'] as String? ?? '',
        annulationDe: row['annulation_de'] as String?,
        annuleePar: row['annulee_par'] as String?,
        syncStatus: SyncStatus.values.byName(row['sync_status']! as String),
        syncError: row['sync_error'] as String?,
      );
}

/// Remplacé dans les tests par une base SQLite en mémoire.
final transactionStoreProvider = Provider<TransactionStore>(
  (ref) => TransactionStore(TransactionStore.openDefault),
);
