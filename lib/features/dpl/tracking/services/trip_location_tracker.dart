import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/dpl_api_service.dart';
import '../../models/dpl_trip_location.dart';

/// Where the driver's location sharing currently stands.
enum TripTrackingStatus {
  /// Not sharing. The resting state.
  off,

  /// Permission / first-fix handshake in progress.
  starting,

  /// Streaming fixes. On Android this implies a live foreground service.
  live,

  /// The OS won't give us location and the driver has to fix it —
  /// [TripTrackingState.message] says how, and the UI offers a deep link
  /// into settings.
  blocked,

  /// Something else broke (stream error). Retryable.
  error,
}

@immutable
class TripTrackingState {
  final TripTrackingStatus status;

  /// Trip currently being tracked. Non-null whenever [status] is
  /// `starting` or `live`.
  final int? tripId;

  final DplTripLocation? lastFix;

  /// Fixes captured but not yet accepted by the server — the offline
  /// backlog. Shown to the driver so a dead zone reads as "queued", not
  /// as a failure.
  final int queued;

  final DateTime? lastSyncAt;

  /// Human-readable explanation for `blocked` / `error`.
  final String? message;

  /// The platform reported a mock-location provider on the last fix.
  /// Surfaced rather than silently dropped — a spoofed truck is a
  /// dispatch-integrity problem someone needs to see.
  final bool mockDetected;

  const TripTrackingState({
    this.status = TripTrackingStatus.off,
    this.tripId,
    this.lastFix,
    this.queued = 0,
    this.lastSyncAt,
    this.message,
    this.mockDetected = false,
  });

  bool get isActive =>
      status == TripTrackingStatus.live ||
      status == TripTrackingStatus.starting;

  /// True when this state describes sharing for [id] specifically —
  /// the tracker is a singleton, so every screen must ask about its own
  /// trip rather than reading [isActive] alone.
  bool isTracking(int id) => isActive && tripId == id;

  TripTrackingState copyWith({
    TripTrackingStatus? status,
    int? tripId,
    DplTripLocation? lastFix,
    int? queued,
    DateTime? lastSyncAt,
    String? message,
    bool? mockDetected,
    bool clearTrip = false,
    bool clearMessage = false,
    bool clearFix = false,
  }) {
    return TripTrackingState(
      status: status ?? this.status,
      tripId: clearTrip ? null : (tripId ?? this.tripId),
      lastFix: clearFix ? null : (lastFix ?? this.lastFix),
      queued: queued ?? this.queued,
      lastSyncAt: lastSyncAt ?? this.lastSyncAt,
      message: clearMessage ? null : (message ?? this.message),
      mockDetected: mockDetected ?? this.mockDetected,
    );
  }
}

/// Drives live location sharing for the trip a driver is running.
///
/// ## Why there is no background-location permission here
///
/// On Android the position stream runs under a **foreground service**
/// with a persistent notification (see [_androidSettings]). Android
/// treats that as *while-in-use* access, so `ACCESS_FINE_LOCATION` alone
/// is enough — we never request `ACCESS_BACKGROUND_LOCATION`, which
/// means no Play Store background-location declaration form and no
/// review risk. On iOS the equivalent is `UIBackgroundModes: location`
/// plus `allowBackgroundLocationUpdates` with the blue status bar
/// indicator, which likewise works under plain "When In Use".
///
/// The trade-off is deliberate and it is the right one for a dispatch
/// app: sharing is visible to the driver the entire time it is running,
/// and it only ever runs between an explicit start and the end of the
/// trip.
///
/// ## Capture strategy
///
/// A pure distance filter goes silent when a truck is stuck in traffic,
/// which is indistinguishable from a crashed app. So we run both:
///   * the platform distance filter ([_distanceFilterM]) for movement,
///   * a [_heartbeat] timer that re-emits the last fix when the truck
///     hasn't moved, tagged `isMoving: false`.
///
/// ## Delivery
///
/// Fixes land in a queue persisted to [SharedPreferences] and flush in
/// batches every [_flushEvery] (or as soon as [_flushAtCount] pile up).
/// The queue only clears on a 2xx, so a dead zone on the plant→TATA run
/// backfills the whole trail when signal returns. It is capped at
/// [_maxQueue] and drops **oldest-first** — losing the start of the
/// trail beats losing where the truck is now.
class TripLocationTracker extends Notifier<TripTrackingState> {
  // ── tuning
  /// Metres of movement before the platform emits a new fix. 75m keeps
  /// city-road resolution without waking the radio every few seconds.
  static const int _distanceFilterM = 75;

  /// Stationary re-ping cadence. Must stay comfortably under
  /// [DplTripLocation.staleAfter] so a parked truck never reads as lost.
  static const Duration _heartbeat = Duration(seconds: 60);

  static const Duration _flushEvery = Duration(seconds: 30);
  static const int _flushAtCount = 12;

  /// ~6h of heartbeats. Beyond this the trip has other problems.
  static const int _maxQueue = 720;

  static const String _kActiveTrip = 'dpl_track_active_trip';
  static String _queueKey(int tripId) => 'dpl_track_queue_$tripId';

  StreamSubscription<Position>? _sub;
  Timer? _heartbeatTimer;
  Timer? _flushTimer;

  final List<DplTripLocation> _queue = [];
  bool _flushing = false;

  /// Last fix the platform gave us, reused by the stationary heartbeat.
  Position? _lastPosition;

  @override
  TripTrackingState build() {
    ref.onDispose(_teardown);
    return const TripTrackingState();
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Begins sharing for [tripId]. Safe to call when already tracking the
  /// same trip (no-op); switching trips stops the previous one first.
  ///
  /// Returns true once the stream is running.
  Future<bool> start(int tripId) async {
    if (state.isTracking(tripId)) return true;
    if (state.isActive && state.tripId != tripId) {
      await stop();
    }

    state = state.copyWith(
      status: TripTrackingStatus.starting,
      tripId: tripId,
      clearMessage: true,
    );

    final gate = await _ensurePermission();
    if (gate != null) {
      state = state.copyWith(
        status: TripTrackingStatus.blocked,
        message: gate,
      );
      return false;
    }

    await _restoreQueue(tripId);
    await _rememberActiveTrip(tripId);

    try {
      _sub = Geolocator.getPositionStream(locationSettings: _settings())
          .listen(_onPosition, onError: _onStreamError);
    } catch (e) {
      state = state.copyWith(
        status: TripTrackingStatus.error,
        message: _readable(e),
      );
      return false;
    }

    _heartbeatTimer = Timer.periodic(_heartbeat, (_) => _onHeartbeat());
    _flushTimer = Timer.periodic(_flushEvery, (_) => _flush());

    state = state.copyWith(status: TripTrackingStatus.live);

    // Seed the trail immediately so the manager sees the truck without
    // waiting for it to travel a full distance-filter hop.
    unawaited(_captureNow());
    return true;
  }

  /// Stops sharing and flushes whatever is still queued. Called by the
  /// driver's toggle and automatically when the trip reaches its final
  /// journey event.
  Future<void> stop() async {
    final tripId = state.tripId;
    await _cancelStream();

    // Best-effort drain — the trip is over, but the tail of the trail is
    // still worth having. Anything that doesn't make it stays on disk
    // and goes out on the next start().
    await _flush();

    if (tripId != null && _queue.isEmpty) {
      await _clearQueue(tripId);
    }
    await _rememberActiveTrip(null);

    state = TripTrackingState(
      queued: _queue.length,
      lastSyncAt: state.lastSyncAt,
    );
  }

  /// Re-arms sharing after an app restart / cold start.
  ///
  /// A killed process takes the foreground service with it, so a driver
  /// whose phone rebooted mid-run would otherwise silently stop being
  /// tracked. Call from the driver trip screen; it only resumes when the
  /// persisted trip matches [tripId] and the trip is still in flight.
  Future<void> resumeIfInterrupted(int tripId) async {
    if (state.isActive) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_kActiveTrip) != tripId) return;
    await start(tripId);
  }

  /// Opens the OS screen that resolves the current `blocked` reason —
  /// the location master switch when that's off, app settings when the
  /// permission was permanently denied.
  Future<void> openBlockingSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
      return;
    }
    await Geolocator.openAppSettings();
  }

  /// Re-checks permission after the driver returns from settings.
  Future<void> retry() async {
    final tripId = state.tripId;
    if (tripId == null) return;
    state = state.copyWith(status: TripTrackingStatus.off, clearMessage: true);
    await start(tripId);
  }

  // ---------------------------------------------------------------------------
  // Permission
  // ---------------------------------------------------------------------------

  /// Returns `null` when good to go, otherwise a driver-readable reason.
  Future<String?> _ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      return 'Location is switched off on this phone. Turn on Location '
          '(GPS) to share your trip.';
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.denied:
        return 'Location permission was declined. Vistar Pulse needs it to '
            'share your position with dispatch while the trip is running.';
      case LocationPermission.deniedForever:
        return 'Location permission is blocked for this app. Open Settings '
            '→ Permissions → Location and allow it.';
      case LocationPermission.whileInUse:
      case LocationPermission.always:
      case LocationPermission.unableToDetermine:
        return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Platform settings
  // ---------------------------------------------------------------------------

  LocationSettings _settings() {
    if (kIsWeb) {
      // Browsers have no background execution — this only streams while
      // the tab is in the foreground. The driver flow is an Android app;
      // web is here so the screen doesn't crash under `flutter run -d chrome`.
      return const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterM,
      );
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return _androidSettings();
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return _appleSettings();
      default:
        return const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: _distanceFilterM,
        );
    }
  }

  /// The foreground-service config is what makes screen-off tracking
  /// legal under while-in-use permission. `setOngoing` keeps the driver
  /// from swiping the notification away without stopping the share.
  AndroidSettings _androidSettings() => AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterM,
        // Backstop for the distance filter: even parked, ask the OS for
        // a fix on roughly the heartbeat cadence.
        intervalDuration: _heartbeat,
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'Trip location sharing is on',
          notificationText:
              'Vistar Pulse is sharing your location with dispatch until the '
              'trip is closed.',
          notificationChannelName: 'Trip location sharing',
          notificationIcon: AndroidResource(
            name: 'ic_launcher',
            defType: 'mipmap',
          ),
          enableWakeLock: true,
          setOngoing: true,
        ),
      );

  AppleSettings _appleSettings() => AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: _distanceFilterM,
        activityType: ActivityType.automotiveNavigation,
        // Required for screen-off updates. Paired with the blue status
        // bar indicator so the driver always knows it's running.
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        // iOS pauses updates when it thinks you've arrived; for a trip
        // that stops at a gate for 20 minutes that's exactly wrong.
        pauseLocationUpdatesAutomatically: false,
      );

  // ---------------------------------------------------------------------------
  // Capture
  // ---------------------------------------------------------------------------

  void _onPosition(Position p) {
    _lastPosition = p;
    _record(p, moving: true);
  }

  void _onStreamError(Object e) {
    state = state.copyWith(
      status: TripTrackingStatus.error,
      message: _readable(e),
    );
  }

  /// Stationary tick — re-emits the last known fix so the trail proves
  /// the driver is still there rather than going quiet.
  void _onHeartbeat() {
    final p = _lastPosition;
    if (p == null) {
      unawaited(_captureNow());
      return;
    }
    // The stream already covered this window; don't double-record.
    if (DateTime.now().toUtc().difference(p.timestamp.toUtc()) < _heartbeat) {
      return;
    }
    _record(p, moving: false);
  }

  /// One-shot fix, used to seed the trail at start and to recover when
  /// the heartbeat fires before the stream has produced anything.
  Future<void> _captureNow() async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 20));
      _lastPosition = p;
      _record(p, moving: false);
    } catch (_) {
      // No fix yet (indoors, cold GPS). The stream will catch up.
    }
  }

  void _record(Position p, {required bool moving}) {
    if (!DplTripLocation.isPlausible(p.latitude, p.longitude)) return;

    final fix = DplTripLocation(
      lat: p.latitude,
      lng: p.longitude,
      recordedAt: p.timestamp.toUtc(),
      accuracyM: p.accuracy,
      speedKmph: p.speed.isFinite && p.speed >= 0 ? p.speed * 3.6 : null,
      // Heading is meaningless at rest — platforms return 0 or the last
      // course indefinitely, which would spin the marker at the dock.
      // iOS also reports -1 for "no valid heading", so the range check is
      // not paranoia: sending -1 would fail server validation for the
      // whole batch, and since the queue only clears on a 2xx that single
      // junk reading would wedge every real fix behind it forever.
      headingDeg: (moving &&
              p.heading.isFinite &&
              p.heading >= 0 &&
              p.heading <= 360 &&
              p.speed > 1)
          ? p.heading
          : null,
      isMoving: moving,
    );

    _queue.add(fix);
    if (_queue.length > _maxQueue) {
      _queue.removeRange(0, _queue.length - _maxQueue);
    }

    state = state.copyWith(
      lastFix: fix,
      queued: _queue.length,
      mockDetected: state.mockDetected || p.isMocked,
      // A fix arriving means we recovered from any transient stream error.
      status: state.status == TripTrackingStatus.error
          ? TripTrackingStatus.live
          : state.status,
    );

    unawaited(_persistQueue());
    if (_queue.length >= _flushAtCount) unawaited(_flush());
  }

  // ---------------------------------------------------------------------------
  // Delivery
  // ---------------------------------------------------------------------------

  Future<void> _flush() async {
    if (_flushing) return;
    final tripId = state.tripId;
    if (tripId == null || _queue.isEmpty) return;

    _flushing = true;
    // Snapshot: fixes captured mid-request must survive the splice below.
    final batch = List<DplTripLocation>.unmodifiable(_queue);
    try {
      final res =
          await ref.read(dplApiServiceProvider).postTripLocations(tripId, batch);
      if (res.isError) return; // keep the queue; retry on the next tick

      _queue.removeRange(0, batch.length);
      await _persistQueue();
      state = state.copyWith(
        queued: _queue.length,
        lastSyncAt: DateTime.now(),
        clearMessage: true,
      );
    } finally {
      _flushing = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Persistence — survives the process being killed mid-trip
  // ---------------------------------------------------------------------------

  Future<void> _persistQueue() async {
    final tripId = state.tripId;
    if (tripId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (_queue.isEmpty) {
      await prefs.remove(_queueKey(tripId));
      return;
    }
    await prefs.setStringList(
      _queueKey(tripId),
      [for (final f in _queue) jsonEncode(f.toJson())],
    );
  }

  Future<void> _restoreQueue(int tripId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_queueKey(tripId)) ?? const [];
    _queue
      ..clear()
      ..addAll(
        raw.map((s) {
          try {
            return DplTripLocation.fromJson(
              Map<String, dynamic>.from(jsonDecode(s) as Map),
            );
          } catch (_) {
            return null;
          }
        }).whereType<DplTripLocation>(),
      );
    state = state.copyWith(queued: _queue.length);
  }

  Future<void> _clearQueue(int tripId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_queueKey(tripId));
  }

  Future<void> _rememberActiveTrip(int? tripId) async {
    final prefs = await SharedPreferences.getInstance();
    if (tripId == null) {
      await prefs.remove(_kActiveTrip);
    } else {
      await prefs.setInt(_kActiveTrip, tripId);
    }
  }

  // ---------------------------------------------------------------------------
  // Teardown
  // ---------------------------------------------------------------------------

  Future<void> _cancelStream() async {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _flushTimer?.cancel();
    _flushTimer = null;
    await _sub?.cancel();
    _sub = null;
    _lastPosition = null;
  }

  void _teardown() {
    _heartbeatTimer?.cancel();
    _flushTimer?.cancel();
    unawaited(_sub?.cancel());
  }

  String _readable(Object e) {
    if (e is LocationServiceDisabledException) {
      return 'Location was switched off. Turn GPS back on to keep sharing.';
    }
    if (e is PermissionDeniedException) {
      return 'Location permission was revoked while the trip was running.';
    }
    return e.toString().replaceFirst('Exception: ', '');
  }
}

/// App-scoped on purpose — **not** autoDispose. Sharing has to keep
/// running while the driver navigates away from the trip screen, locks
/// the phone, or takes a call.
final tripLocationTrackerProvider =
    NotifierProvider<TripLocationTracker, TripTrackingState>(
  TripLocationTracker.new,
);
