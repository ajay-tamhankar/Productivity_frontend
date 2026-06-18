/// Runtime feature switches for the DPL module.
///
/// Flags live here (not on a server response) because the gates they
/// drive are UI shape decisions, not policy. Flipping one off should
/// be a one-line edit + redeploy, used as a fast rollback lever if a
/// new flow misbehaves in the field.
///
/// Default values reflect the *current* production posture, not the
/// legacy posture. A flag set to `true` means the new behaviour is
/// already in the user's hands.
class DplFeatureFlags {
  /// Trip-driven dispatch (migration 048).
  ///
  /// When `true`:
  ///   * The dispatcher landing screen shows the "Open Trips" section
  ///     at the top.
  ///   * The legacy per-plant manual machine-picker form inside
  ///     `PlantCard` is hidden — dispatchers cut slips by ticking
  ///     plans on a manager-submitted trip.
  ///
  /// When `false`:
  ///   * Open Trips section disappears (Phase 2 widget renders empty).
  ///   * Legacy machine-picker form is restored as the only slip
  ///     creation path.
  ///
  /// Backend supports both shapes simultaneously (`POST /dispatch/slips`
  /// auto-detects via `trip_id` presence), so flipping this is safe.
  static const bool enableDispatchTrips = true;
}
