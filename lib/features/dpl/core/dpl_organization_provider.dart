import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/repositories/local_storage_repository.dart';
import '../models/dpl_organization.dart';
import 'dpl_api_service.dart';

/// Active tenant the logged-in DPL user belongs to.
///
/// Hydrated from local storage at app start so the AppBar pill renders
/// without an extra round-trip. Updated by the auth controller on login.
/// Optionally refreshable from `/auth/me` via [refresh].
class DplActiveOrganization extends Notifier<DplOrganization?> {
  @override
  DplOrganization? build() {
    final prefs = ref.read(localStorageRepositoryProvider);
    final snap = prefs.getDplOrganization();
    if (snap == null) return null;
    return DplOrganization(id: snap.id, code: snap.code, name: snap.name);
  }

  /// Replaces the cached org and persists it. Called by the auth
  /// controller right after a successful login or a `/me` hydrate.
  Future<void> set(DplOrganization org) async {
    state = org;
    await ref.read(localStorageRepositoryProvider).saveDplOrganization(
          id: org.id,
          code: org.code,
          name: org.name,
        );
  }

  /// Wipes the snapshot. Called on logout / ORG_MISMATCH.
  Future<void> clear() async {
    state = null;
    await ref.read(localStorageRepositoryProvider).clearDplOrganization();
  }

  /// Best-effort re-hydrate from `/auth/me`. Safe to call from screens
  /// that want fresh tenant info after a server-side admin reassignment.
  /// Silently no-ops on network errors — the cached org keeps rendering.
  Future<void> refresh() async {
    final res = await ref.read(dplApiServiceProvider).me();
    if (res.isError) return;
    final org = res.data?.organization;
    if (org != null) await set(org);
  }
}

final dplActiveOrganizationProvider =
    NotifierProvider<DplActiveOrganization, DplOrganization?>(
  DplActiveOrganization.new,
);
