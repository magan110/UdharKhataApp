import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class SettingsRepository {
  Future<String> languageCode();
  Future<void> setLanguageCode(String languageCode);
}

class DeviceSettingsRepository implements SettingsRepository {
  const DeviceSettingsRepository(this.storage, {this.accountId});
  final FlutterSecureStorage storage;
  final String? accountId;
  String get _key =>
      accountId == null ? 'language_device' : 'language_account_$accountId';
  @override
  Future<String> languageCode() async {
    final value =
        await storage.read(key: _key) ??
        await storage.read(key: 'language_device');
    return value == 'hi' ? 'hi' : 'en';
  }

  @override
  Future<void> setLanguageCode(String code) async {
    if (!['en', 'hi'].contains(code)) {
      throw ArgumentError('Unsupported language');
    }
    await storage.write(key: _key, value: code);
    await storage.write(key: 'language_device', value: code);
  }
}
