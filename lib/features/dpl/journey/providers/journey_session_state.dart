import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A single successful journey action the user has taken THIS SESSION.
/// Purely in-memory — cleared on app restart or logout. Used to power
/// the "Recent activity" list and the session counter on the Security
/// / QRE home dashboards.
///
/// A backend-scoped "actions I performed today" endpoint doesn't exist
/// yet; when it lands, wire that in alongside this session state (this
/// stays useful for the immediate-since-open list).
@immutable
class JourneyActivity {
  final int tripId;
  final int? tripNumber;
  final String? plant;
  final String? vehicleNo;
  final String event;   // 'gate_out' | 'tata_dock_in' | 'tata_dock_out'
  final DateTime at;
  final Map<String, dynamic> extras;

  const JourneyActivity({
    required this.tripId,
    required this.event,
    required this.at,
    this.tripNumber,
    this.plant,
    this.vehicleNo,
    this.extras = const {},
  });
}

/// Base Notifier for a session-local capped list of journey activities.
/// Riverpod 3 pattern (matches DplActiveOrganization elsewhere in this
/// project). Concrete subclasses exist so we can wire two independent
/// providers — one per journey role — without them sharing state.
abstract class _JourneyActivityBase extends Notifier<List<JourneyActivity>> {
  static const int _cap = 20;

  @override
  List<JourneyActivity> build() => const [];

  /// Prepend a new activity; cap at 20 entries so the dashboard list
  /// stays snappy even in a marathon shift.
  void add(JourneyActivity a) {
    final next = <JourneyActivity>[a, ...state];
    if (next.length > _cap) next.removeRange(_cap, next.length);
    state = next;
  }

  void clear() => state = const [];
}

class SecurityRecent extends _JourneyActivityBase {}
class QreRecent extends _JourneyActivityBase {}

/// Session activity for the currently-logged-in Security user.
final securityRecentProvider =
    NotifierProvider<SecurityRecent, List<JourneyActivity>>(
  SecurityRecent.new,
);

/// Session activity for the currently-logged-in QRE user.
final qreRecentProvider =
    NotifierProvider<QreRecent, List<JourneyActivity>>(
  QreRecent.new,
);
