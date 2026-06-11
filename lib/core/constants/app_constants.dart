class AppConstants {
  static const String appName = 'Vistar Pulse';
  static const String apiBaseUrl =
      'https://vistar-crm.onrender.com/api/v1/productivity';

  // Base URL for the Daily Production Loading (DPL) module. The DPL
  // endpoints live under a parallel path on the same backend host.
  static const String dplApiBaseUrl =
      'https://vistar-crm.onrender.com/api/v1/dpl';

  // Shared Preferences Keys
  static const String tokenKey = 'AUTH_TOKEN';
  static const String userRoleKey = 'USER_ROLE';
  static const String userIdKey = 'USER_ID';
  static const String usernameKey = 'USERNAME';
  static const String userNameKey = 'USER_NAME';
  static const String offlineEntriesKey = 'OFFLINE_ENTRIES';
  static const String themeModeKey = 'THEME_MODE';

  // DPL active-organization snapshot — written on login, read on app
  // restart so the AppBar pill renders without an extra round-trip.
  static const String dplOrgIdKey = 'DPL_ORG_ID';
  static const String dplOrgCodeKey = 'DPL_ORG_CODE';
  static const String dplOrgNameKey = 'DPL_ORG_NAME';

  // Roles
  static const String roleAdmin = 'ADMIN';
  static const String roleSupervisor = 'SUPERVISOR';
  static const String roleBrin = 'BRIN';
  static const String roleOperator = 'OPERATOR';
  static const String roleDplManager = 'DPL_MANAGER';
  static const String roleDplSupervisor = 'DPL_SUPERVISOR';
  /// Read-only DPL viewer — sees the Manager Dashboard + Plans tab but
  /// cannot create / edit / delete anything.
  static const String roleDplCustomer = 'DPL_CUSTOMER';

  /// Downstream "production summary" viewers — Dispatch / QA / PDI.
  /// They share a single Production Summary screen and have no other
  /// access into the DPL module.
  static const String roleDplDispatch = 'DPL_DISPATCH';
  static const String roleDplQa = 'DPL_QA';
  static const String roleDplPdi = 'DPL_PDI';

  static const List<String> assignableRoles = <String>[
    roleAdmin,
    roleSupervisor,
    roleBrin,
    roleOperator,
  ];

  static String normalizeRole(String role) => role.trim().toUpperCase();

  static String roleLabel(String role) {
    switch (normalizeRole(role)) {
      case roleAdmin:
        return 'Admin';
      case roleSupervisor:
        return 'Supervisor';
      case roleBrin:
        return 'BRIN';
      case roleOperator:
        return 'Operator';
      case roleDplManager:
        return 'DPL Manager';
      case roleDplSupervisor:
        return 'DPL Supervisor';
      case roleDplCustomer:
        return 'DPL Customer';
      case roleDplDispatch:
        return 'DPL Dispatch';
      case roleDplQa:
        return 'DPL QA';
      case roleDplPdi:
        return 'DPL PDI';
      default:
        return normalizeRole(role);
    }
  }

  static bool isSupervisorRole(String role) =>
      normalizeRole(role) == roleSupervisor;

  static bool isBrinRole(String role) => normalizeRole(role) == roleBrin;

  static bool isAdminDashboardRole(String role) {
    final normalized = normalizeRole(role);
    return normalized == roleAdmin || normalized == roleSupervisor;
  }

  static bool isDplManagerRole(String role) =>
      normalizeRole(role) == roleDplManager;

  static bool isDplSupervisorRole(String role) =>
      normalizeRole(role) == roleDplSupervisor;

  static bool isDplCustomerRole(String role) =>
      normalizeRole(role) == roleDplCustomer;

  static bool isDplDispatchRole(String role) =>
      normalizeRole(role) == roleDplDispatch;

  static bool isDplQaRole(String role) => normalizeRole(role) == roleDplQa;

  static bool isDplPdiRole(String role) => normalizeRole(role) == roleDplPdi;

  /// Any of the three downstream "summary-only" roles. These users land
  /// on the Production Summary screen and have no other DPL access.
  static bool isDplSummaryViewerRole(String role) =>
      isDplDispatchRole(role) || isDplQaRole(role) || isDplPdiRole(role);

  static bool isDplRole(String role) =>
      isDplManagerRole(role) ||
      isDplSupervisorRole(role) ||
      isDplCustomerRole(role) ||
      isDplSummaryViewerRole(role);
}
