// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reports_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReportsController)
final reportsControllerProvider = ReportsControllerProvider._();

final class ReportsControllerProvider
    extends $NotifierProvider<ReportsController, ReportsState> {
  ReportsControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reportsControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reportsControllerHash();

  @$internal
  @override
  ReportsController create() => ReportsController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReportsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReportsState>(value),
    );
  }
}

String _$reportsControllerHash() => r'10497ca21f85fba12e8f0afcdf42cdb37a2c059e';

abstract class _$ReportsController extends $Notifier<ReportsState> {
  ReportsState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<ReportsState, ReportsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReportsState, ReportsState>,
              ReportsState,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
