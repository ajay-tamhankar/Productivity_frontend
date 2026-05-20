import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/admin_dashboard_screen.dart';
import '../../features/dashboard/brin_dashboard_screen.dart';
import '../../features/dashboard/operator_dashboard_screen.dart';
import '../../features/dpl/manager/manager_shell.dart';
import '../../features/dpl/manager/screens/masters/downtime_reasons_master_screen.dart';
import '../../features/dpl/manager/screens/masters/machines_master_screen.dart';
import '../../features/dpl/manager/screens/masters/manpower_master_screen.dart';
import '../../features/dpl/manager/screens/masters/parts_master_screen.dart';
import '../../features/dpl/manager/screens/identity_audit_screen.dart';
import '../../features/dpl/manager/screens/masters/shifts_master_screen.dart';
import '../../features/dpl/manager/screens/plan_detail_screen.dart';
import '../../features/dpl/manager/screens/upload_plan_screen.dart';
import '../../features/dpl/supervisor/screens/machine_plan_screen.dart';
import '../../features/dpl/supervisor/screens/plan_execution_screen.dart';
import '../../features/dpl/supervisor/screens/supervisor_shell.dart';
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
      const dplManagerPath = '/dpl/manager';
      const dplSupervisorPath = '/dpl/supervisor';

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == loginPath;
      final role = authState.value?.role ?? '';
      final isAdminRole = AppConstants.isAdminDashboardRole(role);
      final isBrinRole = AppConstants.isBrinRole(role);
      final isDplManagerRole = AppConstants.isDplManagerRole(role);
      final isDplSupervisorRole = AppConstants.isDplSupervisorRole(role);

      final defaultDashboardPath = isDplManagerRole
          ? dplManagerPath
          : isDplSupervisorRole
              ? dplSupervisorPath
              : isAdminRole
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
          (isAdminRole || isBrinRole || isDplManagerRole || isDplSupervisorRole)) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation == newEntryPath && isBrinRole) {
        return brinDashboardPath;
      }

      // Sandbox DPL routes to DPL roles only.
      if (state.matchedLocation.startsWith('/dpl/manager') && !isDplManagerRole) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation.startsWith('/dpl/supervisor') &&
          !isDplSupervisorRole) {
        return defaultDashboardPath;
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
      // DPL Manager — shell with bottom nav for 4 tabs.
      GoRoute(
        path: '/dpl/manager',
        builder: (context, state) => const DplManagerShell(),
        routes: [
          GoRoute(
            path: 'upload-plan',
            builder: (context, state) => const DplUploadPlanScreen(),
          ),
          GoRoute(
            path: 'plans/:id',
            builder: (context, state) {
              final raw = state.pathParameters['id'] ?? '';
              final id = int.tryParse(raw) ?? 0;
              return DplPlanDetailScreen(planId: id);
            },
          ),
          GoRoute(
            path: 'masters/machines',
            builder: (context, state) => const DplMachinesMasterScreen(),
          ),
          GoRoute(
            path: 'masters/parts',
            builder: (context, state) => const DplPartsMasterScreen(),
          ),
          GoRoute(
            path: 'masters/downtime-reasons',
            builder: (context, state) =>
                const DplDowntimeReasonsMasterScreen(),
          ),
          GoRoute(
            path: 'masters/shifts',
            builder: (context, state) => const DplShiftsMasterScreen(),
          ),
          GoRoute(
            path: 'masters/manpower',
            builder: (context, state) => const DplManpowerMasterScreen(),
          ),
          GoRoute(
            path: 'identity-audit',
            builder: (context, state) => const DplIdentityAuditScreen(),
          ),
        ],
      ),
      // DPL Supervisor — Phase 2 shell with bottom nav.
      GoRoute(
        path: '/dpl/supervisor',
        builder: (context, state) => const SupervisorShell(),
        routes: [
          GoRoute(
            path: 'machine/:planId',
            builder: (context, state) {
              final id = int.tryParse(
                    state.pathParameters['planId'] ?? '',
                  ) ??
                  0;
              return MachinePlanScreen(planId: id);
            },
            routes: [
              GoRoute(
                path: 'execute/:itemId',
                builder: (context, state) {
                  final planId = int.tryParse(
                        state.pathParameters['planId'] ?? '',
                      ) ??
                      0;
                  final itemId = int.tryParse(
                        state.pathParameters['itemId'] ?? '',
                      ) ??
                      0;
                  return PlanExecutionScreen(
                    planId: planId,
                    itemId: itemId,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
