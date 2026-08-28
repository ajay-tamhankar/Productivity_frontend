import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/vistar_app.dart';

/// The signed-in identity the launcher hands to a sibling Vistar app.
@immutable
class VistarSsoIdentity {
  final String email;
  final String name;
  final String role;

  /// The password the user typed on the launcher's own login form.
  ///
  /// Present so a target app can call its **own** `/auth/login` with it
  /// and drop the user straight onto its home page — the whole point of
  /// not signing in twice. `null` when the launcher no longer holds it
  /// (e.g. after a browser refresh on a non-portal account), in which
  /// case the hand-off degrades to an identity hint.
  final String? password;

  const VistarSsoIdentity({
    required this.email,
    required this.name,
    required this.role,
    this.password,
  });

  bool get canAutoLogin => (password ?? '').isNotEmpty;

  /// Keeps the password out of logs and crash reports.
  @override
  String toString() =>
      'VistarSsoIdentity($email, $role, password: ${canAutoLogin ? '••••••••' : 'none'})';
}

/// Builds and opens the single-sign-on hand-off link for a Vistar app.
///
/// ## Why credentials and not a token
///
/// A browser will not let this app write a session into another origin:
/// same-origin policy rules out touching the target's localStorage, and
/// `.workers.dev` / `.pages.dev` sit on the public-suffix list so a
/// shared parent-domain cookie is impossible too. Something inside each
/// target app therefore has to receive the hand-off — there is no
/// zero-change path. Given that, the cheapest thing a target can act on
/// is the credentials themselves: it already has a working login call.
///
/// See `SSO_RECEIVER.md` in this folder for the ~15-line receiver each
/// app needs.
///
/// ## The contract
///
/// Every tile opens `<app url>` carrying:
///
/// | param   | meaning                                                     |
/// |---------|-------------------------------------------------------------|
/// | `vsso`  | base64url JSON envelope — identity, credentials, audience   |
/// | `email` | flat e-mail hint, for apps that only prefill their form      |
/// | `src`   | always `vistar-workspace`, so targets can log the origin     |
///
/// The `vsso` envelope decodes to:
///
/// ```json
/// {"v":2,"src":"vistar-workspace","app":"kra","sub":"user@vistarlogitek.com",
///  "pwd":"…","name":"Prashant Tamhankar","role":"VISTAR_WORKSPACE",
///  "iat":1770000000,"exp":1770000060}
/// ```
///
/// A target auto-signs-in by decoding `vsso`, checking `exp` and `app`,
/// POSTing `sub`/`pwd` to its own login endpoint, then scrubbing the URL
/// with `history.replaceState`.
///
/// ## Trust boundary — read this before shipping it wide
///
/// Three things are true and none of them are subtle:
///
/// 1. **The envelope is encoded, not encrypted.** base64url is not a
///    secret. Anyone who sees the URL can read the password out of it.
/// 2. **Query transport reaches the server.** With
///    [VistarSsoTransport.query] the envelope lands in Cloudflare access
///    logs and in any `Referer` the target later emits. Switch an app to
///    [VistarSsoTransport.fragment] once its hash route is known —
///    fragments are never transmitted.
/// 3. **[ttlSeconds] is the only real containment.** It is deliberately
///    short so a URL copied out of history stops working quickly.
///
/// The correct end state is a server-signed, single-use token that
/// carries no password at all: add a `POST /portal/sso/token` endpoint,
/// return a signed JWT, and have targets exchange it for a session. The
/// param names here are chosen so that swap needs no change in any
/// target app — only [_issueToken] moves.
///
/// ## Why token issuance stays synchronous
///
/// On web, [launchUrl] must run inside the user's click gesture or the
/// browser blocks the new tab. Issuing the token synchronously keeps the
/// launch inside that gesture. If issuance ever becomes a network call,
/// pre-fetch tokens when the launcher loads rather than awaiting inside
/// the tap handler.
class VistarSsoHandoff {
  const VistarSsoHandoff();

  /// Value of the `src` param — lets target apps distinguish a portal
  /// hand-off from a normal visit in their logs.
  static const String source = 'vistar-workspace';

  /// How long a hand-off stays valid, in seconds.
  ///
  /// Held to one minute because the envelope carries a password through a
  /// URL, and a URL outlives the click — it sits in history, and under
  /// the query transport in server logs. The window only has to cover a
  /// tab opening, so a minute is generous.
  static const int ttlSeconds = 60;

  static const String envelopeParam = 'vsso';
  static const String emailParam = 'email';
  static const String sourceParam = 'src';

  /// The exact URL a tile opens.
  ///
  /// Query transport preserves any params already on the app's URL and
  /// merges the hand-off on top. Fragment transport leaves the query
  /// untouched and writes `#<hashRoute>?vsso=…` instead, keeping the
  /// envelope off the wire.
  Uri buildUrl(VistarApp app, VistarSsoIdentity identity, {DateTime? now}) {
    final base = Uri.parse(app.url);
    if (app.sso == VistarSsoMode.plain) return base;

    final envelope = _issueToken(app, identity, now ?? DateTime.now());

    switch (app.transport) {
      case VistarSsoTransport.query:
        final params = Map<String, String>.from(base.queryParameters)
          ..[envelopeParam] = envelope
          ..[emailParam] = identity.email
          ..[sourceParam] = source;
        return base.replace(queryParameters: params);

      case VistarSsoTransport.fragment:
        final route = app.hashRoute.startsWith('/')
            ? app.hashRoute
            : '/${app.hashRoute}';
        final handoff = Uri(
          queryParameters: <String, String>{
            envelopeParam: envelope,
            emailParam: identity.email,
            sourceParam: source,
          },
        ).query;
        return base.replace(fragment: '$route?$handoff');
    }
  }

  /// Opens [app] in a new browser tab (web) or the device browser
  /// (Android / iOS). Returns `false` when the platform refused to open
  /// the link — typically a blocked pop-up.
  Future<bool> open(VistarApp app, VistarSsoIdentity identity) {
    return launchUrl(
      buildUrl(app, identity),
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
  }

  String _issueToken(VistarApp app, VistarSsoIdentity identity, DateTime now) {
    final issuedAt = now.toUtc().millisecondsSinceEpoch ~/ 1000;
    final envelope = <String, dynamic>{
      'v': 2,
      'src': source,
      'app': app.id,
      'sub': identity.email,
      'name': identity.name,
      'role': identity.role,
      'iat': issuedAt,
      'exp': issuedAt + ttlSeconds,
      // Omitted rather than sent null when the launcher no longer holds
      // the password — a target can then tell "no auto-login available"
      // from "auto-login failed".
      if (identity.canAutoLogin) 'pwd': identity.password,
    };
    // base64url without `=` padding so the value stays URL-clean.
    return base64Url
        .encode(utf8.encode(jsonEncode(envelope)))
        .replaceAll('=', '');
  }
}

final vistarSsoHandoffProvider = Provider<VistarSsoHandoff>(
  (ref) => const VistarSsoHandoff(),
);
