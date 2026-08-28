import 'package:flutter/material.dart';

/// How the launcher hands the signed-in identity over to a sibling app.
enum VistarSsoMode {
  /// Append the Vistar single-sign-on hand-off (`vsso` envelope + a flat
  /// `email` hint) so the target app can drop the user straight onto its
  /// dashboard instead of its own login form.
  handoff,

  /// Open the plain URL with no identity attached. Use for apps that have
  /// not adopted the hand-off contract yet, or that must always show
  /// their own login form (e.g. shared kiosk screens).
  plain,
}

/// Where in the URL the hand-off envelope rides.
enum VistarSsoTransport {
  /// `?vsso=…` — works everywhere, including Flutter web apps using
  /// hash-based routing, because the query sits ahead of the `#`.
  ///
  /// Cost: the query string reaches the server, so it lands in Cloudflare
  /// access logs and in any `Referer` header the page later sends.
  query,

  /// `#/<route>?vsso=…` — the envelope rides inside the fragment, which
  /// browsers never transmit, so it stays out of server logs entirely.
  /// Requires knowing the target's hash route ([VistarApp.hashRoute]) and
  /// only works on apps that route off the fragment.
  ///
  /// Prefer this once a target confirms its route — it is the safer of
  /// the two by a wide margin.
  fragment,
}

/// One tile on the Vistar Workspace launcher.
///
/// The launcher is entirely data-driven: cards, category filters, search
/// and the counts in the header are all derived from the catalog list, so
/// onboarding a new Vistar app is a single entry in
/// `data/vistar_app_catalog.dart` — no UI change required.
@immutable
class VistarApp {
  /// Stable slug. Travels in the SSO envelope as the audience claim, so
  /// changing it invalidates hand-offs — treat it as an ID, not a label.
  final String id;

  final String name;

  /// One line describing what the app is for. Shown under the name.
  final String tagline;

  /// Absolute https URL of the app's web front end.
  final String url;

  /// Grouping used by the filter chips. Free-form: any new value shows up
  /// as a new chip automatically.
  final String category;

  final IconData icon;

  /// Two-stop gradient for the tile's icon plate. Pulled from the Vistar
  /// ribbon so every tile stays inside the brand palette.
  final List<Color> accent;

  final VistarSsoMode sso;

  /// Where the envelope rides. Defaults to [VistarSsoTransport.query]
  /// because it works without knowing anything about the target's
  /// routing; switch an app to [VistarSsoTransport.fragment] (and set
  /// [hashRoute]) as soon as that app's route is confirmed.
  final VistarSsoTransport transport;

  /// Hash route the fragment transport lands on, e.g. `/login` for a
  /// Flutter app whose sign-in lives at `#/login`. Ignored when
  /// [transport] is [VistarSsoTransport.query].
  final String hashRoute;

  /// `false` greys the tile out and blocks the tap — use while an app is
  /// being provisioned rather than deleting the entry.
  final bool enabled;

  /// Shown on the tile when the app needs a caveat (e.g. "opens the
  /// shared portal"). Optional.
  final String? note;

  const VistarApp({
    required this.id,
    required this.name,
    required this.tagline,
    required this.url,
    required this.category,
    required this.icon,
    required this.accent,
    this.sso = VistarSsoMode.handoff,
    this.transport = VistarSsoTransport.query,
    this.hashRoute = '/',
    this.enabled = true,
    this.note,
  });

  LinearGradient get accentGradient => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: accent,
  );

  /// Host shown on the tile so the user can confirm where a click lands
  /// before they take it.
  String get host {
    final parsed = Uri.tryParse(url);
    if (parsed == null || parsed.host.isEmpty) return url;
    return parsed.host;
  }

  /// Case-insensitive match across name, tagline, category and host —
  /// what the launcher's search box filters on.
  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return name.toLowerCase().contains(q) ||
        tagline.toLowerCase().contains(q) ||
        category.toLowerCase().contains(q) ||
        host.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q);
  }
}
