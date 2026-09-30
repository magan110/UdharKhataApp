import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/auth/account.dart';
import '../core/network/app_failure.dart';
import '../features/auth/session_controller.dart';
import '../features/auth/welcome_page.dart';
import '../features/ledger/customer_shell.dart';
import '../features/shop/owner_shell.dart';
import 'app_strings.dart';
import 'status_page.dart';

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
      GoRoute(path: '/', builder: (_, _) => const WelcomePage()),
      GoRoute(
        path: '/loading',
        builder: (_, _) => const StatusPage(
          title: 'Opening your account',
          message: 'Please wait.',
          loading: true,
        ),
      ),
      GoRoute(
        path: '/error',
        builder: (_, _) {
          final error = ref.read(sessionProvider).error;
          return StatusPage(
            title: 'Could not open your account',
            message: errorMessage(
              error is AppFailure ? error.messageKey : 'api.internalError',
            ),
            onRetry: () => ref.invalidate(sessionProvider),
          );
        },
      ),
      GoRoute(path: '/owner', builder: (_, _) => const OwnerShell()),
      GoRoute(path: '/customer', builder: (_, _) => const CustomerShell()),
    ],
    errorBuilder: (_, _) => const StatusPage(
      title: 'Page unavailable',
      message: 'This page could not be opened.',
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
