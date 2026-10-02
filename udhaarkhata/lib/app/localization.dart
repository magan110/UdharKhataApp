import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../features/auth/session_controller.dart';
import '../features/settings/settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DeviceSettingsRepository(
    const FlutterSecureStorage(),
    accountId: ref.watch(sessionProvider).value?.id.value,
  ),
);
final localeProvider = AsyncNotifierProvider<LocaleController, Locale>(
  LocaleController.new,
);

class LocaleController extends AsyncNotifier<Locale> {
  @override
  Future<Locale> build() async =>
      Locale(await ref.watch(settingsRepositoryProvider).languageCode());
  Future<void> setLanguageCode(String code) async {
    await ref.read(settingsRepositoryProvider).setLanguageCode(code);
    state = AsyncData(Locale(code));
  }
}
