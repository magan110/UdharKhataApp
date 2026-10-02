import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'app_strings.dart';
import 'localization.dart';
import '../features/ledger/sync_service.dart';

class MainApp extends ConsumerWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => SyncLifecycle(
    child: MaterialApp.router(
      title: 'Udhaar Khata',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B45)),
        useMaterial3: true,
      ),
      locale: ref.watch(localeProvider).asData?.value ?? const Locale('en'),
      localizationsDelegates: const [
        AppStrings.delegate,
        ...GlobalMaterialLocalizations.delegates,
      ],
      supportedLocales: AppStrings.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    ),
  );
}
