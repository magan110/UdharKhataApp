abstract interface class SettingsRepository {
  Future<String> languageCode();
  Future<void> setLanguageCode(String languageCode);
}
