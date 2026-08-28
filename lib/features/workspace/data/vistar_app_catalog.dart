import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/workspace_theme.dart';
import '../models/vistar_app.dart';

/// The Vistar app family, in the order it should appear on the launcher.
///
/// Adding an app = adding one entry here. The launcher derives its grid,
/// its category chips, its search index and its header counts from this
/// list, so nothing in the UI needs to change.
///
/// The catalog is a compile-time constant today. When the backend grows a
/// per-user entitlement endpoint (`GET /portal/apps`), swap the body of
/// [vistarAppCatalogProvider] for the network call and keep this list as
/// the offline fallback — the widgets stay untouched.
const List<VistarApp> kVistarAppCatalog = <VistarApp>[
  VistarApp(
    id: 'vistar-pulse',
    name: 'Vistar Pulse',
    tagline:
        'Daily production loading, shift execution, dispatch slips and live trip tracking.',
    url: 'https://productivity-frontend.flutter-developer.workers.dev/',
    category: 'Operations',
    icon: Icons.monitor_heart_outlined,
    accent: <Color>[VistarPalette.purple, VistarPalette.pink],
  ),
  VistarApp(
    id: 'vtms',
    name: 'VTMS',
    tagline:
        'Vehicle & transport management — LR entry, trip costing and freight reconciliation.',
    url: 'https://lr-management.pages.dev/',
    category: 'Logistics',
    icon: Icons.local_shipping_outlined,
    accent: <Color>[VistarPalette.violet, VistarPalette.orangeRed],
  ),
  VistarApp(
    id: 'gate-app',
    name: 'Gate App',
    tagline:
        'Security gate in/out register for vehicles, visitors and material movement.',
    url: 'https://gate-app.flutter-developer.workers.dev/',
    category: 'Operations',
    icon: Icons.sensor_door_outlined,
    accent: <Color>[VistarPalette.red, VistarPalette.orange],
  ),
  VistarApp(
    id: 'sangopan',
    name: 'Sangopan',
    tagline:
        'Preventive maintenance and asset upkeep schedules across plants and machines.',
    url: 'https://sangopan.pages.dev/',
    category: 'Operations',
    icon: Icons.handyman_outlined,
    accent: <Color>[VistarPalette.orange, VistarPalette.amber],
  ),
  VistarApp(
    id: 'kra',
    name: 'KRA',
    tagline:
        'Key result areas, goal setting and periodic performance reviews for every role.',
    url: 'https://kra.flutter-developer.workers.dev/',
    category: 'People',
    icon: Icons.track_changes_outlined,
    accent: <Color>[VistarPalette.magenta, VistarPalette.pink],
  ),
  VistarApp(
    id: 'vistar-hire',
    name: 'Vistar Hire',
    tagline:
        'Requisitions, candidate pipeline, interview scorecards and offer tracking.',
    url: 'https://vistar-hire.flutter-developer.workers.dev/',
    category: 'People',
    icon: Icons.badge_outlined,
    accent: <Color>[VistarPalette.pink, VistarPalette.orangeRed],
  ),
  VistarApp(
    id: 'note-for-approval',
    name: 'Note for Approval',
    tagline:
        'Raise, route and sign off internal approval notes with a full audit trail.',
    url: 'https://note-for-approval.flutter-developer.workers.dev/',
    category: 'Governance',
    icon: Icons.fact_check_outlined,
    accent: <Color>[VistarPalette.purple, VistarPalette.violet],
  ),
  VistarApp(
    id: 'audit-management',
    name: 'Audit Management',
    tagline:
        'Audit plans, checklists, non-conformance capture and corrective-action closure.',
    url:
        'https://audit-management-app-frontend.flutter-developer.workers.dev/',
    category: 'Governance',
    icon: Icons.rule_folder_outlined,
    accent: <Color>[VistarPalette.violet, VistarPalette.magenta],
  ),
  VistarApp(
    id: 'client-entry-portal',
    name: 'Client Entry Portal',
    tagline:
        'Client onboarding and master data entry — the front door for new accounts.',
    url:
        'https://client-entry-portal-frontend.flutter-developer.workers.dev/',
    category: 'Clients',
    icon: Icons.how_to_reg_outlined,
    accent: <Color>[VistarPalette.pink, VistarPalette.amber],
  ),
  // NOTE: this URL is intentionally the same host as `client-entry-portal`
  // — that is what was supplied when the tile was requested. Point it at
  // the reminder app's own deployment once that URL is confirmed.
  VistarApp(
    id: 'reminder-app',
    name: 'Reminder App',
    tagline:
        'Scheduled reminders and follow-up nudges for renewals, dues and commitments.',
    url:
        'https://client-entry-portal-frontend.flutter-developer.workers.dev/',
    category: 'Clients',
    icon: Icons.notifications_active_outlined,
    accent: <Color>[VistarPalette.amber, VistarPalette.yellow],
    note: 'Shares the Client Entry Portal host',
  ),
  VistarApp(
    id: 'complaint-app',
    name: 'Complaint App',
    tagline:
        'Log customer complaints, assign owners and track resolution to closure.',
    url: 'https://complaint-app.flutter-developer.workers.dev/',
    category: 'Clients',
    icon: Icons.support_agent_outlined,
    accent: <Color>[VistarPalette.orangeRed, VistarPalette.magenta],
  ),
];

/// The apps this user may launch.
///
/// Swap the body for a `FutureProvider` hitting the entitlements endpoint
/// when per-user app access lands; the launcher already handles an
/// arbitrary-length, arbitrary-category list.
final vistarAppCatalogProvider = Provider<List<VistarApp>>(
  (ref) => kVistarAppCatalog,
);

/// Categories in first-appearance order, used for the filter chips.
final vistarAppCategoriesProvider = Provider<List<String>>((ref) {
  final seen = <String>{};
  final ordered = <String>[];
  for (final app in ref.watch(vistarAppCatalogProvider)) {
    if (seen.add(app.category)) ordered.add(app.category);
  }
  return ordered;
});
