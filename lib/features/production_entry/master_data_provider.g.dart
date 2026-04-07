// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master_data_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(MasterDataController)
final masterDataControllerProvider = MasterDataControllerProvider._();

final class MasterDataControllerProvider
    extends $AsyncNotifierProvider<MasterDataController, MasterDataState> {
  MasterDataControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'masterDataControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$masterDataControllerHash();

  @$internal
  @override
  MasterDataController create() => MasterDataController();
}

String _$masterDataControllerHash() =>
    r'7bfa8b83a7fb7ce15a2aed2e59216afb03526636';

abstract class _$MasterDataController extends $AsyncNotifier<MasterDataState> {
  FutureOr<MasterDataState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<MasterDataState>, MasterDataState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<MasterDataState>, MasterDataState>,
              AsyncValue<MasterDataState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
