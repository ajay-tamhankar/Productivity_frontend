class AppConstants {
  static const String appName = 'Production Sync';
  static const String apiBaseUrl =
      'https://productivity-backend-1-cvtc.onrender.com/api';

  // Shared Preferences Keys
  static const String tokenKey = 'AUTH_TOKEN';
  static const String userRoleKey = 'USER_ROLE';
  static const String userIdKey = 'USER_ID';
  static const String usernameKey = 'USERNAME';
  static const String userNameKey = 'USER_NAME';
  static const String offlineEntriesKey = 'OFFLINE_ENTRIES';
  static const String themeModeKey = 'THEME_MODE';

  // Roles
  static const String roleAdmin = 'ADMIN';
  static const String roleSupervisor = 'SUPERVISOR';
  static const String roleBrin = 'BRIN';
  static const String roleOperator = 'OPERATOR';

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
}
