import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/admin_dashboard_screen.dart';
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
      const operatorDashboardPath = '/operator-dashboard';

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == loginPath;
      final role = authState.value?.role.trim().toUpperCase();
      final isAdminRole =
          role == AppConstants.roleAdmin || role == AppConstants.roleSupervisor;
      
      // If still loading init state, don't redirect aggressively
      if (authState.isLoading && !isAuth) return null;

      if (!isAuth) {
        return isLoggingIn ? null : loginPath;
      }

      if (isLoggingIn || state.matchedLocation == '/') {
        return isAdminRole ? adminDashboardPath : operatorDashboardPath;
      }

      // Keep users in role-appropriate dashboard routes.
      if (state.matchedLocation == adminDashboardPath && !isAdminRole) {
        return operatorDashboardPath;
      }
      if (state.matchedLocation == operatorDashboardPath && isAdminRole) {
        return adminDashboardPath;
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
        path: '/new-entry',
        builder: (context, state) => const ProductionEntryScreen(),
      ),
    ],
  );
}
