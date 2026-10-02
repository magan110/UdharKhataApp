import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';

import '../auth/account.dart';
import '../network/contracts.dart';
import 'account_database.dart';
import 'migrations.dart';

final class SqliteAccountDatabase implements AccountDatabase {
  SqliteAccountDatabase({DatabaseFactory? factory, this.directory})
    : factory = factory ?? databaseFactory;

  final DatabaseFactory factory;
  final String? directory;
  Database? _database;
  String? _accountId;
  Future<void> _lifecycle = Future.value();
  int _generation = 0;
  int get generation => _generation;
  void invalidateGeneration() {
    _generation++;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final next = _lifecycle.then((_) => action());
    _lifecycle = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> openForAccount(OpaqueId accountId) =>
      _serialize(() => _open(accountId));
  Future<void> openExistingForAccount(OpaqueId accountId, AccountRole role) =>
      _serialize(() => _open(accountId, existingRole: role));
  DateTime? _accessDeadline;
  DateTime Function()? _accessClock;
  void requireLocalAccess(DateTime deadline, DateTime Function() clock) {
    _accessDeadline = deadline;
    _accessClock = clock;
  }

  Future<void> _open(OpaqueId accountId, {AccountRole? existingRole}) async {
    await _close();
    final root = directory ?? await factory.getDatabasesPath();
    // Fixed length, preserves case distinctions; local_account also checks identity.
    final namespace = sha256.convert(utf8.encode(accountId.value)).toString();
    final path = '$root/account_$namespace.sqlite';
    if (existingRole != null && !await factory.databaseExists(path)) {
      throw StateError('Existing account cache required');
    }
    final db = await factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: localSchemaVersion,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys=ON'),
        onCreate: createLocalSchema,
        onUpgrade: upgradeLocalSchema,
        onDowngrade: (db, oldVersion, newVersion) async {
          throw StateError(
            'Unsupported local schema downgrade: $oldVersion to $newVersion',
          );
        },
      ),
    );
    try {
      await db.transaction((tx) async {
        if (existingRole == null) {
          await tx.insert('local_account', {
            'singleton': 1,
            'user_id': accountId.value,
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        }
        final rows = await tx.query('local_account');
        if (rows.length != 1 ||
            rows.single['user_id'] != accountId.value ||
            (existingRole != null &&
                (rows.single['role'] != existingRole.name ||
                    rows.single['last_verified_at_ms'] == null))) {
          throw StateError('Account database mismatch');
        }
      });
    } catch (_) {
      await db.close();
      rethrow;
    }
    _database = db;
    _accountId = accountId.value;
  }

  @override
  Future<void> lock() => _serialize(_close);

  Future<void> _close() async {
    _generation++;
    _accessDeadline = null;
    _accessClock = null;
    final db = _database;
    _database = null;
    _accountId = null;
    await db?.close();
  }

  Future<T> transaction<T>(
    OpaqueId accountId,
    Future<T> Function(Transaction) action, {
    int? expectedGeneration,
  }) async {
    final db = _database;
    void accessGuard() {
      final deadline = _accessDeadline;
      if (deadline != null) {
        final now = _accessClock!();
        if (!now.isBefore(deadline) ||
            now.isBefore(deadline.subtract(const Duration(days: 30)))) {
          throw StateError('Local access expired');
        }
      }
    }

    accessGuard();
    if (db == null ||
        _accountId != accountId.value ||
        (expectedGeneration != null && expectedGeneration != generation)) {
      throw StateError('Account database locked');
    }
    return db.transaction((tx) async {
      if (_database != db ||
          _accountId != accountId.value ||
          (expectedGeneration != null && expectedGeneration != generation)) {
        throw StateError('Account database locked');
      }
      accessGuard();
      final result = await action(tx);
      accessGuard();
      if (_database != db ||
          _accountId != accountId.value ||
          (expectedGeneration != null && expectedGeneration != generation)) {
        throw StateError('Account database locked');
      }
      return result;
    });
  }

  Future<void> verifyAccount(
    OpaqueId accountId,
    AccountRole role,
    int verifiedAtMs,
  ) => transaction(accountId, (tx) async {
    await tx.update('local_account', {
      'role': role.name,
      'last_verified_at_ms': timestampMs(verifiedAtMs),
    }, where: 'singleton=1');
  });
}
