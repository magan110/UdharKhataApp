import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/contracts.dart';
import 'local_access_grant.dart';

final class SessionStore {
  SessionStore(this.storage);
  final FlutterSecureStorage storage;
  Future<Map<String, Object?>?> read() async {
    final value = await storage.read(key: 'app_session');
    if (value == null) return null;
    try {
      return jsonObject(jsonDecode(value));
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> save(Map<String, Object?> value) =>
      storage.write(key: 'app_session', value: jsonEncode(value));
  Future<void> clear() => storage.delete(key: 'app_session');
  Future<LocalAccessGrant?> readLocalGrant() async {
    final value = await storage.read(key: 'local_access_grant');
    if (value == null) return null;
    try {
      return LocalAccessGrant.fromJson(jsonDecode(value));
    } on FormatException {
      await clearLocalGrant();
      return null;
    }
  }

  Future<void> saveLocalGrant(LocalAccessGrant grant) =>
      storage.write(key: 'local_access_grant', value: jsonEncode(grant.json));
  Future<void> clearLocalGrant() => storage.delete(key: 'local_access_grant');
  Future<String> deviceId() async {
    final existing = await storage.read(key: 'device_id');
    if (existing != null) return OpaqueId.fromJson(existing).value;
    final random = Random.secure();
    final id = List.generate(
      32,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    await storage.write(key: 'device_id', value: id);
    return id;
  }
}
