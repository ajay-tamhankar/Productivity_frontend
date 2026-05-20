/// Role → human-readable label mapping.
///
/// Backend hands us raw enum strings ("DPL_MANAGER", "DPL_SUPERVISOR")
/// which must never be shown to end users — UI always renders through
/// [labelFor].
class DplRole {
  const DplRole._();

  static const String manager = 'DPL_MANAGER';
  static const String supervisor = 'DPL_SUPERVISOR';

  static String labelFor(String? role) {
    if (role == null) return 'User';
    switch (role.trim().toUpperCase()) {
      case manager:
        return 'Production Manager';
      case supervisor:
        return 'Production Supervisor';
      case 'DPL_ADMIN':
        return 'Plant Admin';
      default:
        // Strip the namespace prefix + title-case anything we don't
        // recognise so the UI is still safe.
        final cleaned = role
            .replaceFirst(RegExp(r'^DPL_', caseSensitive: false), '')
            .replaceAll('_', ' ')
            .toLowerCase();
        if (cleaned.isEmpty) return 'User';
        return cleaned[0].toUpperCase() + cleaned.substring(1);
    }
  }

  static bool isManager(String? role) =>
      (role ?? '').toUpperCase() == manager;

  static bool isSupervisor(String? role) =>
      (role ?? '').toUpperCase() == supervisor;
}
