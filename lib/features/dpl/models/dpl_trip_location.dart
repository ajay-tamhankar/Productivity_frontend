import 'dart:math' as math;

import '_json_helpers.dart';

/// One GPS fix recorded against a dispatch trip while it was in flight.
///
/// The same class is used in both directions:
///   * **outbound** — the driver's device builds these locally and POSTs
///     them in batches to `/dispatch/trips/:id/locations` ([toJson]).
///   * **inbound** — the manager's track map reads them back from
///     `GET /dispatch/trips/:id/locations` ([fromJson]).
///
/// Two clocks are carried on purpose. [recordedAt] is the **device**
/// clock at the moment of the fix; [receivedAt] is the **server** clock
/// when the ping landed. They diverge whenever the driver was offline
/// and the queue flushed late — exactly the case we need to be able to
/// see, so the map draws by [recordedAt] and the "last seen" badge
/// reasons about it too. Both are UTC on the wire.
class DplTripLocation {
  /// Server row id. `null` on locally-built pings not yet accepted.
  final int? id;

  final double lat;
  final double lng;

  /// Horizontal accuracy radius in metres as reported by the platform.
  /// Large values (>100m) mean a cell/wifi fix rather than a true GPS
  /// lock — the map de-emphasises those points.
  final double? accuracyM;

  /// Ground speed in km/h. Converted from the platform's m/s at capture
  /// time so every consumer sees one unit.
  final double? speedKmph;

  /// Course over ground in degrees clockwise from true north. Rotates
  /// the truck marker; `null` when stationary (platforms report garbage
  /// heading at rest).
  final double? headingDeg;

  /// False when this fix came from the stationary heartbeat rather than
  /// the distance filter — i.e. the truck hasn't moved. Lets the map
  /// tell "parked at the dock" apart from "we lost the driver".
  final bool isMoving;

  final DateTime recordedAt;
  final DateTime? receivedAt;

  const DplTripLocation({
    required this.lat,
    required this.lng,
    required this.recordedAt,
    this.id,
    this.accuracyM,
    this.speedKmph,
    this.headingDeg,
    this.isMoving = true,
    this.receivedAt,
  });

  factory DplTripLocation.fromJson(Map<String, dynamic> json) {
    final recorded =
        parseDateTimeOrNull(json['recorded_at'] ?? json['recordedAt']);
    final received =
        parseDateTimeOrNull(json['received_at'] ?? json['receivedAt']);
    return DplTripLocation(
      id: parseIntOrNull(json['id']),
      lat: parseDoubleOr(json['lat'] ?? json['latitude']),
      lng: parseDoubleOr(json['lng'] ?? json['lon'] ?? json['longitude']),
      accuracyM: optDouble(json['accuracy_m'] ?? json['accuracyM']),
      speedKmph: optDouble(json['speed_kmph'] ?? json['speedKmph']),
      headingDeg: optDouble(json['heading_deg'] ?? json['headingDeg']),
      // Absent `is_moving` means a legacy/plain payload — assume moving so
      // an older backend doesn't render every point as a parked heartbeat.
      isMoving: (json['is_moving'] ?? json['isMoving']) != false,
      // A row with neither clock can't be ordered; fall back to the other
      // one, then to epoch so it sorts to the front and reads as visibly
      // wrong rather than silently "now".
      recordedAt: recorded ??
          received ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      receivedAt: received,
    );
  }

  /// Wire shape for the outbound batch POST. Omits the id and
  /// [receivedAt] — the server owns those.
  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'recorded_at': recordedAt.toUtc().toIso8601String(),
        'is_moving': isMoving,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (speedKmph != null) 'speed_kmph': speedKmph,
        if (headingDeg != null) 'heading_deg': headingDeg,
      };

  /// Guards the two junk fixes that actually show up in the wild:
  /// out-of-range values from a bad parse, and Null Island (0,0), which
  /// some devices emit before the first real lock.
  static bool isPlausible(double lat, double lng) =>
      lat >= -90 &&
      lat <= 90 &&
      lng >= -180 &&
      lng <= 180 &&
      !(lat.abs() < 0.0001 && lng.abs() < 0.0001);

  bool get hasPlausibleFix => isPlausible(lat, lng);

  /// How long ago this fix was taken, on the device's clock.
  Duration get age => DateTime.now().toUtc().difference(recordedAt.toUtc());

  /// A fix older than this reads as "last seen …" rather than live.
  /// Sized off the tracker's stationary heartbeat (60s) plus the upload
  /// flush window (30s) plus slack, so a parked-but-healthy truck never
  /// trips it.
  static const Duration staleAfter = Duration(minutes: 4);

  bool get isStale => age > staleAfter;

  /// Great-circle distance to [other] in metres.
  double metresTo(DplTripLocation other) =>
      haversineMetres(lat, lng, other.lat, other.lng);
}

/// Nullable numeric coercion — shared by both models in this file.
double? optDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

/// Great-circle distance between two coordinates, in metres.
double haversineMetres(double lat1, double lon1, double lat2, double lon2) {
  const earthRadiusM = 6371000.0;
  double toRad(double d) => d * math.pi / 180.0;

  final dLat = toRad(lat2 - lat1);
  final dLon = toRad(lon2 - lon1);
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(toRad(lat1)) *
          math.cos(toRad(lat2)) *
          math.sin(dLon / 2) *
          math.sin(dLon / 2);
  return earthRadiusM * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Everything the track map needs for one trip: the breadcrumb trail
/// plus denormalised driver / vehicle labels, so the screen doesn't have
/// to fan out to `GET /dispatch/trips/:id` as well.
///
/// [distanceKm] is read from the server when it sends one and otherwise
/// derived from [points], so the screen renders correctly even against a
/// backend that only stores and returns raw rows.
class DplTripTrack {
  final int tripId;

  /// Oldest-first. The polyline depends on this ordering, so [fromJson]
  /// re-sorts defensively rather than trusting the server.
  final List<DplTripLocation> points;

  final String? driverName;
  final String? vehicleNo;

  /// Server's own view of whether the driver app is streaming right now.
  /// Optional — when absent the screen falls back to fix staleness.
  final bool? sharing;

  final double distanceKm;

  const DplTripTrack({
    required this.tripId,
    this.points = const [],
    this.driverName,
    this.vehicleNo,
    this.sharing,
    this.distanceKm = 0,
  });

  factory DplTripTrack.fromJson(Map<String, dynamic> json, {int? tripId}) {
    List<dynamic> raw = const [];
    for (final key in const ['points', 'locations', 'items', 'data', 'rows']) {
      final v = json[key];
      if (v is List) {
        raw = v;
        break;
      }
    }

    final serverKm = optDouble(json['distance_km'] ?? json['distanceKm']);
    final points = _parsePoints(raw);

    return DplTripTrack(
      tripId: parseIntOr(json['trip_id'] ?? json['tripId'], tripId ?? 0),
      points: points,
      driverName: _optString(json['driver_name'] ?? json['driverName']),
      vehicleNo: _optString(json['vehicle_no'] ?? json['vehicleNo']),
      sharing: (json.containsKey('sharing') || json.containsKey('is_sharing'))
          ? ((json['sharing'] ?? json['is_sharing']) == true)
          : null,
      distanceKm: serverKm ?? distanceKmOf(points),
    );
  }

  /// Bare-list response (`[{...}, {...}]`) — no envelope, no metadata.
  factory DplTripTrack.fromPointList(List<dynamic> raw, {required int tripId}) {
    final points = _parsePoints(raw);
    return DplTripTrack(
      tripId: tripId,
      points: points,
      distanceKm: distanceKmOf(points),
    );
  }

  static List<DplTripLocation> _parsePoints(List<dynamic> raw) {
    final points = raw
        .whereType<Map>()
        .map((e) => DplTripLocation.fromJson(Map<String, dynamic>.from(e)))
        .where((p) => p.hasPlausibleFix)
        .toList();
    points.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return points;
  }

  static String? _optString(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Sums the leg-by-leg great-circle distance, skipping legs whose
  /// length can't be told apart from GPS jitter — otherwise a truck
  /// parked for an hour accumulates phantom kilometres.
  static double distanceKmOf(List<DplTripLocation> pts) {
    var metres = 0.0;
    for (var i = 1; i < pts.length; i++) {
      final leg = pts[i - 1].metresTo(pts[i]);
      final noise = math.max(pts[i - 1].accuracyM ?? 0, pts[i].accuracyM ?? 0);
      if (leg > math.max(noise, 20)) metres += leg;
    }
    return metres / 1000.0;
  }

  bool get isEmpty => points.isEmpty;
  bool get isNotEmpty => points.isNotEmpty;

  DplTripLocation? get last => points.isEmpty ? null : points.last;
  DplTripLocation? get first => points.isEmpty ? null : points.first;

  /// True when we believe the driver app is streaming right now. Prefers
  /// the server's answer, falls back to the freshness of the last fix.
  bool get isLive => sharing ?? (last != null && !last!.isStale);

  /// Wall-clock span the trail covers.
  Duration get elapsed => (first == null || last == null)
      ? Duration.zero
      : last!.recordedAt.difference(first!.recordedAt);

  /// Average speed over the whole trail in km/h. `null` when there isn't
  /// enough of a span to make the number meaningful.
  double? get averageKmph {
    final hours = elapsed.inSeconds / 3600.0;
    if (hours <= 0 || distanceKm <= 0) return null;
    return distanceKm / hours;
  }
}
