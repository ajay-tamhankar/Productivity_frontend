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
import '../../features/dpl/manager/screens/buffer_norms_screen.dart';
import '../../features/dpl/manager/screens/dispatch_plan_view_screen.dart';
import '../../features/dpl/manager/screens/dispatch_planning_hub_screen.dart';
import '../../features/dpl/manager/screens/morning_stock_update_screen.dart';
import '../../features/dpl/manager/screens/part_field_edit_screen.dart';
import '../../features/dpl/manager/screens/plan_detail_screen.dart';
import '../../features/dpl/manager/screens/plan_trip_screen.dart';
import '../../features/dpl/manager/screens/todays_dispatch_plan_screen.dart';
import '../../features/dpl/models/dpl_part_field.dart';
import '../../features/dpl/manager/screens/upload_plan_screen.dart';
import '../../features/dpl/summary/summary_shell.dart';
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
      const dplSummaryPath = '/dpl/summary';

      final isAuth = authState.value != null;
      final isLoggingIn = state.matchedLocation == loginPath;
      final role = authState.value?.role ?? '';
      final isAdminRole = AppConstants.isAdminDashboardRole(role);
      final isBrinRole = AppConstants.isBrinRole(role);
      final isDplManagerRole = AppConstants.isDplManagerRole(role);
      final isDplSupervisorRole = AppConstants.isDplSupervisorRole(role);
      final isDplCustomerRole = AppConstants.isDplCustomerRole(role);
      final isDplSummaryViewerRole =
          AppConstants.isDplSummaryViewerRole(role);

      final defaultDashboardPath = isDplManagerRole
          ? dplManagerPath
          : isDplSupervisorRole
              ? dplSupervisorPath
              : isDplCustomerRole
                  ? dplManagerPath
                  : isDplSummaryViewerRole
                      ? dplSummaryPath
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
          (isAdminRole ||
              isBrinRole ||
              isDplManagerRole ||
              isDplSupervisorRole ||
              isDplCustomerRole ||
              isDplSummaryViewerRole)) {
        return defaultDashboardPath;
      }
      if (state.matchedLocation == newEntryPath && isBrinRole) {
        return brinDashboardPath;
      }

      // Sandbox DPL routes to DPL roles only.
      // DPL Customer can enter `/dpl/manager` shell and view plan detail,
      // but write-only routes (upload, masters, identity audit) are blocked.
      if (state.matchedLocation.startsWith('/dpl/manager') &&
          !(isDplManagerRole || isDplCustomerRole)) {
        return defaultDashboardPath;
      }
      if (isDplCustomerRole) {
        final loc = state.matchedLocation;
        final isWriteOnlyDplRoute = loc.startsWith('/dpl/manager/upload-plan') ||
            loc.startsWith('/dpl/manager/masters') ||
            loc.startsWith('/dpl/manager/identity-audit');
        if (isWriteOnlyDplRoute) {
          return dplManagerPath;
        }
      }
      if (state.matchedLocation.startsWith('/dpl/supervisor') &&
          !isDplSupervisorRole) {
        return defaultDashboardPath;
      }
      // Sandbox the Production Summary shell to the three summary-only
      // roles. Manager / Supervisor / Customer have their own shells —
      // they should never end up under /dpl/summary.
      if (state.matchedLocation.startsWith('/dpl/summary') &&
          !isDplSummaryViewerRole) {
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
            path: 'todays-dispatch-plan',
            builder: (context, state) => const TodaysDispatchPlanScreen(),
          ),
          GoRoute(
            path: 'buffer-norms',
            builder: (context, state) => const BufferNormsScreen(),
          ),
          GoRoute(
            path: 'morning-stock',
            builder: (context, state) => const MorningStockUpdateScreen(),
          ),
          // ───── Simple dispatch planning (3 master fields + computed view) ─────
          GoRoute(
            path: 'dispatch-planning',
            builder: (context, state) => const DispatchPlanningHubScreen(),
          ),
          GoRoute(
            path: 'stocking-norms',
            builder: (context, state) => const PartFieldEditScreen(
              kind: DplPartFieldKind.stockingNorm,
            ),
          ),
          GoRoute(
            path: 'customer-opening-stocks',
            builder: (context, state) => const PartFieldEditScreen(
              kind: DplPartFieldKind.customerOpeningStock,
            ),
          ),
          GoRoute(
            path: 'customer-todays-plans',
            builder: (context, state) => const PartFieldEditScreen(
              kind: DplPartFieldKind.customerTodayPlan,
            ),
          ),
          GoRoute(
            path: 'packaging-qtys',
            builder: (context, state) => const PartFieldEditScreen(
              kind: DplPartFieldKind.packagingQty,
            ),
          ),
          GoRoute(
            path: 'dispatch-plan-view',
            builder: (context, state) => const DispatchPlanViewScreen(),
          ),
          GoRoute(
            path: 'plan-trip',
            builder: (context, state) => const PlanTripScreen(),
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
      // DPL Production Summary — single-tab shell shared by the
      // Dispatch / QA / PDI roles. AppBar title is picked from the
      // authenticated user's role inside the shell.
      GoRoute(
        path: '/dpl/summary',
        builder: (context, state) => const DplSummaryShell(),
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
