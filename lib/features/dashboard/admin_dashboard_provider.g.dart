// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'admin_dashboard_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AdminDashboardController)
final adminDashboardControllerProvider = AdminDashboardControllerProvider._();

final class AdminDashboardControllerProvider
    extends
        $AsyncNotifierProvider<AdminDashboardController, AdminDashboardState> {
  AdminDashboardControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'adminDashboardControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$adminDashboardControllerHash();

  @$internal
  @override
  AdminDashboardController create() => AdminDashboardController();
}

String _$adminDashboardControllerHash() =>
    r'f29fe71ce2bbb1ac83523db05b097896b271feae';

abstract class _$AdminDashboardController
    extends $AsyncNotifier<AdminDashboardState> {
  FutureOr<AdminDashboardState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<AdminDashboardState>, AdminDashboardState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<AdminDashboardState>, AdminDashboardState>,
              AsyncValue<AdminDashboardState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
