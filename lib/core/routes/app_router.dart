import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/admin_dashboard_screen.dart';
import '../../features/dashboard/brin_dashboard_screen.dart';
import '../../features/dashboard/operator_dashboard_screen.dart';
import '../../features/production_entry/production_entry_screen.dart';
import '../constants/app_constants.dart';

part 'app_router.g.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

@riverpod
GoRouter appRouter(Ref ref) {
  final authState = ref.watch(authControllerProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      const loginPath = '/login';
      const adminDashboardPath = '/admin-dashboard';
      const brinDashboardPath = '/brin-dashboard';
      const operatorDashboardPath = '/operator-dashboard';
      const newEntryPath = '/new-entry';

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == loginPath;
      final role = authState.value?.role ?? '';
      final isAdminRole = AppConstants.isAdminDashboardRole(role);
      final isBrinRole = AppConstants.isBrinRole(role);
      final defaultDashboardPath = isAdminRole
          ? adminDashboardPath
          : isBrinRole
              ? brinDashboardPath
              : operatorDashboardPath;

      // If still loading init state, don't redirect aggressively
      if (authState.isLoading && !isAuth) return null;

      if (!isAuth) {
        return isLoggingIn ? null : loginPath;
      }

      if (isLoggingIn || state.matchedLocation == '/') {
        return defaultDashboardPath;
      }

      // Keep users in role-appropriate dashboard routes.
      if (state.matchedLocation == adminDashboardPath && !isAdminRole) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation == brinDashboardPath && !isBrinRole) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation == operatorDashboardPath &&
          (isAdminRole || isBrinRole)) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation == newEntryPath && isBrinRole) {
        return brinDashboardPath;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/admin-dashboard',
        builder: (context, state) => const AdminDashboardScreen(),
      ),
      GoRoute(
        path: '/operator-dashboard',
        builder: (context, state) => const OperatorDashboardScreen(),
      ),
      GoRoute(
        path: '/brin-dashboard',
        builder: (context, state) => const BrinDashboardScreen(),
      ),
      GoRoute(
        path: '/new-entry',
        builder: (context, state) => const ProductionEntryScreen(),
      ),
    ],
  );
}
