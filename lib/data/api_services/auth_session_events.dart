import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Broadcast bus the Dio 401 interceptor uses to tell the rest of the
/// app that the server has invalidated the current JWT. The auth
/// controller listens to this stream and drops its in-memory user, so
/// the router redirects back to /login on the next frame.
///
/// We use a small bus instead of importing the auth provider directly
/// because [auth_repository.dart] already depends on [api_client.dart];
/// importing the auth provider here would create an import cycle.
class AuthSessionEvents {
  AuthSessionEvents() : _controller = StreamController<void>.broadcast();

  final StreamController<void> _controller;

  Stream<void> get onUnauthorized => _controller.stream;

  void notifyUnauthorized() {
    if (_controller.isClosed) return;
    _controller.add(null);
  }

  void dispose() {
    _controller.close();
  }
}

final authSessionEventsProvider = Provider<AuthSessionEvents>((ref) {
  final bus = AuthSessionEvents();
  ref.onDispose(bus.dispose);
  return bus;
});
