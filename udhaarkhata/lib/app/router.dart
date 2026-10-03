import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/account.dart';
import '../core/network/app_failure.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/welcome_page.dart';
import '../features/ledger/customer_shell.dart';
import '../features/ledger/credit_form.dart';
import '../features/ledger/payment_form.dart';
import '../features/ledger/history_page.dart';
import '../features/shop/owner_shell.dart';
import '../features/shop/customer_list.dart';
import '../features/qr/scanner_page.dart';
import '../core/network/contracts.dart';
import 'app_strings.dart';
import 'status_page.dart';
import '../features/settings/settings_page.dart';
import '../features/settings/recovery_help.dart';
import '../features/sharing/statement_share_page.dart';
import '../features/disputes/dispute_page.dart';
import '../features/disputes/dispute_entry_context.dart';

class _RouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh();
  ref.listen(sessionProvider, (_, _) => refresh.refresh());
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (_, state) {
      final session = ref.read(sessionProvider);
      final path = state.uri.path;
      if (session.isLoading) return path == '/loading' ? null : '/loading';
      if (session.hasError) return path == '/error' ? null : '/error';
      final account = session.value;
      if (account == null) return path == '/' ? null : '/';
      final home = account.role == AccountRole.owner ? '/owner' : '/customer';
      if (path == '/' ||
          path == '/loading' ||
          path == '/error' ||
          (account.role == AccountRole.owner && path.startsWith('/customer')) ||
          (account.role == AccountRole.customer && path.startsWith('/owner'))) {
        return home;
      }
      return null;
    },
    routes: [
      GoRoute(path: '/settings', builder: (context, _) => SettingsPage()),
      GoRoute(path: '/recovery', builder: (context, _) => RecoveryHelpPage()),
      GoRoute(path: '/', builder: (context, _) => WelcomePage()),
      GoRoute(
        path: '/loading',
        builder: (context, _) => StatusPage(
          title: AppStrings.of(context).translate('Opening your account'),
          message: AppStrings.of(context).translate('Please wait.'),
          loading: true,
        ),
      ),
      GoRoute(
        path: '/error',
        builder: (context, _) {
          final error = ref.read(sessionProvider).error;
          return StatusPage(
            title: AppStrings.of(context)
                .translate('Could not open your account'),
            message: errorMessage(
              error is AppFailure ? error.messageKey : 'api.internalError',
              languageCode: AppStrings.of(context).languageCode,
            ),
            onRetry: () => ref.invalidate(sessionProvider),
          );
        },
      ),
      GoRoute(
        path: '/owner',
        builder: (context, state) => OwnerShell(
          key: ValueKey(ref.read(sessionProvider).value?.id.value),
          tab: state.uri.queryParameters['tab'] ?? '',
        ),
        routes: [
          GoRoute(
            path: 'statement/:shopId/:linkId',
            builder: (_, state) => StatementSharePage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']).value,
              linkId: OpaqueId.fromJson(state.pathParameters['linkId']).value,
            ),
          ),
          GoRoute(
            path: 'disputes/:shopId',
            builder: (_, state) => DisputePage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']).value,
              customer: false,
            ),
          ),
          GoRoute(
            path: 'history/:shopId/:linkId',
            builder: (context, state) => HistoryPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']).value,
              linkId: OpaqueId.fromJson(state.pathParameters['linkId']).value,
              confirmedOnly: state.uri.queryParameters['source'] == 'server',
            ),
          ),
          GoRoute(
            path: 'payment/:shopId/:linkId',
            builder: (context, state) => PaymentPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']),
              linkId: OpaqueId.fromJson(state.pathParameters['linkId']),
            ),
          ),
          GoRoute(
            path: 'credit/:shopId/:linkId',
            builder: (context, state) => CreditPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']),
              linkId: OpaqueId.fromJson(state.pathParameters['linkId']),
            ),
          ),
          GoRoute(
            path: 'scan/:shopId',
            builder: (context, state) => ScannerPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']),
            ),
          ),
          GoRoute(
            path: 'customer/:shopId/:linkId',
            builder: (context, state) => OwnerCustomerPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']),
              linkId: OpaqueId.fromJson(state.pathParameters['linkId']),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/customer',
        builder: (context, state) => CustomerShell(
          key: ValueKey(ref.read(sessionProvider).value?.id.value),
          tab: state.uri.queryParameters['tab'] ?? '',
        ),
        routes: [
          GoRoute(
            path: 'disputes/:shopId',
            builder: (_, state) => DisputePage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']).value,
              customer: true,
              entryId: state.uri.queryParameters['entry'],
              entryContext: state.extra is DisputeEntryContext
                  ? state.extra as DisputeEntryContext
                  : null,
            ),
          ),
          GoRoute(
            path: 'history/:shopId',
            builder: (context, state) => HistoryPage(
              shopId: OpaqueId.fromJson(state.pathParameters['shopId']).value,
            ),
          ),
        ],
      ),
    ],
    errorBuilder: (context, _) => StatusPage(
      title: AppStrings.of(context).translate('Page unavailable'),
      message: AppStrings.of(context)
          .translate('This page could not be opened.'),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
