# Vistar Workspace — receiver contract

The Workspace launcher (`/apps` in this app) opens each sibling Vistar app
with a hand-off attached. **Until the target app reads it, nothing
auto-logs-in** — the tile just opens that app's normal login page.

This file is the whole spec plus a drop-in receiver. Hand it to whoever
owns each app repo; it's a single function and one call from `main()`.

## Why the target has to do the work

The launcher cannot write a session into another origin. Same-origin
policy blocks reaching into `kra.…workers.dev`'s localStorage from
`productivity-frontend.…workers.dev`, and `.workers.dev` / `.pages.dev`
are on the browser public-suffix list, so a shared parent-domain cookie
is impossible too. A receiver in the target app is the only path.

## What arrives

Query transport (default):

```
https://kra.flutter-developer.workers.dev/?vsso=<base64url>&email=<addr>&src=vistar-workspace
```

Fragment transport (preferred once your hash route is known — the
fragment is never sent to the server, so it stays out of access logs):

```
https://kra.flutter-developer.workers.dev/#/login?vsso=<base64url>&email=<addr>&src=vistar-workspace
```

`vsso` is base64url (no `=` padding) of:

```json
{
  "v": 2,
  "src": "vistar-workspace",
  "app": "kra",
  "sub": "prashant.tamhankar@vistarlogitek.com",
  "pwd": "…",
  "name": "Prashant Tamhankar",
  "role": "VISTAR_WORKSPACE",
  "iat": 1770000000,
  "exp": 1770000060
}
```

| field | meaning |
|-------|---------|
| `v`   | envelope version, currently `2` |
| `app` | audience — your app's id. Reject if it isn't yours. |
| `sub` | username to log in as |
| `pwd` | password to log in with. **Absent** when the launcher no longer holds it — treat as "no auto-login available" and show your login form. |
| `exp` | unix seconds. Reject once past. TTL is 60s. |

## Receiver rules — all four matter

1. **Check `exp`.** A stale URL out of someone's history must not sign anyone in.
2. **Check `app`.** Refuse an envelope minted for a different app.
3. **Scrub the URL immediately** via `history.replaceState`, before your first
   `await`. This keeps the password out of the address bar, out of any
   `Referer` your page later emits, and out of what a user might copy.
4. **Fail open to your login form.** Never surface a raw error — a bad or
   expired hand-off should look like an ordinary visit.

## Drop-in for a Flutter web target

```dart
// lib/core/auth/vistar_sso_receiver.dart
import 'dart:convert';
import 'package:web/web.dart' as web;

/// Credentials handed over by the Vistar Workspace launcher, or `null` if
/// this is an ordinary visit. Scrubs the URL as a side effect.
({String username, String password})? readVistarHandoff({
  required String myAppId,
}) {
  // Envelope may ride in the query or inside the hash route's query.
  final uri = Uri.base;
  var raw = uri.queryParameters['vsso'];
  if (raw == null && uri.fragment.contains('vsso=')) {
    final q = uri.fragment.split('?');
    if (q.length > 1) raw = Uri.splitQueryString(q[1])['vsso'];
  }
  if (raw == null || raw.isEmpty) return null;

  // Rule 3: scrub before anything can fail or await.
  web.window.history.replaceState(null, '', uri.path);

  try {
    final padded = raw.padRight((raw.length + 3) & ~3, '=');
    final env =
        jsonDecode(utf8.decode(base64Url.decode(padded))) as Map<String, dynamic>;

    if (env['app'] != myAppId) return null;                       // rule 2
    final exp = env['exp'] as int? ?? 0;
    if (DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000 > exp) {
      return null;                                                 // rule 1
    }

    final username = env['sub'] as String? ?? '';
    final password = env['pwd'] as String? ?? '';
    if (username.isEmpty || password.isEmpty) return null;
    return (username: username, password: password);
  } catch (_) {
    return null;                                                   // rule 4
  }
}
```

Then in your app's startup, before the router decides where to land:

```dart
final handoff = readVistarHandoff(myAppId: 'kra');
if (handoff != null) {
  // Your existing login call — nothing special about it.
  await authController.login(handoff.username, handoff.password);
}
// Router now sees an authenticated user and lands on the home page.
```

`package:web` is already a transitive dependency of every Flutter web
app, so there is nothing to add to `pubspec.yaml`.

## Drop-in for a non-Flutter target

```js
function readVistarHandoff(myAppId) {
  const url = new URL(location.href);
  let raw = url.searchParams.get('vsso');
  if (!raw && location.hash.includes('vsso=')) {
    raw = new URLSearchParams(location.hash.split('?')[1] || '').get('vsso');
  }
  if (!raw) return null;

  history.replaceState(null, '', url.pathname);   // rule 3

  try {
    const b64 = raw.replace(/-/g, '+').replace(/_/g, '/');
    const env = JSON.parse(atob(b64.padEnd(Math.ceil(b64.length / 4) * 4, '=')));
    if (env.app !== myAppId) return null;                          // rule 2
    if (Math.floor(Date.now() / 1000) > (env.exp || 0)) return null; // rule 1
    if (!env.sub || !env.pwd) return null;
    return { username: env.sub, password: env.pwd };
  } catch {
    return null;                                                    // rule 4
  }
}
```

## App ids to match against

| app | id |
|-----|----|
| Vistar Pulse | `vistar-pulse` |
| VTMS | `vtms` |
| Gate App | `gate-app` |
| Sangopan | `sangopan` |
| KRA | `kra` |
| Vistar Hire | `vistar-hire` |
| Note for Approval | `note-for-approval` |
| Audit Management | `audit-management` |
| Client Entry Portal | `client-entry-portal` |
| Reminder App | `reminder-app` |
| Complaint App | `complaint-app` |

Ids are the audience claim — they are stable identifiers, not labels.
Renaming one invalidates hand-offs to that app.

## Where this should end up

Shipping a password through a URL is a compromise, taken because it is
the only thing that works with no backend change. base64url is encoding,
not encryption: whoever sees the URL can read the password.

The proper version removes the password entirely:

1. Add `POST /portal/sso/token` to `vistar_CRM`, returning a short-lived
   **signed** JWT for `{user, audience}`.
2. The launcher sends that instead of `pwd` — only `_issueToken` in
   `services/vistar_sso_handoff.dart` changes.
3. Targets verify the signature and exchange the token for a session.

Param names and envelope shape here were chosen so that swap costs
**zero** change in any target app. Implementing this receiver now is not
wasted work.
