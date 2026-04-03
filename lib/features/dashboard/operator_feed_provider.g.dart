// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'operator_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OperatorFeedController)
final operatorFeedControllerProvider = OperatorFeedControllerProvider._();

final class OperatorFeedControllerProvider
    extends $AsyncNotifierProvider<OperatorFeedController, PaginatedFeedState> {
  OperatorFeedControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'operatorFeedControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$operatorFeedControllerHash();

  @$internal
  @override
  OperatorFeedController create() => OperatorFeedController();
}

String _$operatorFeedControllerHash() =>
    r'91453f366917c15abd191ae7f04971074d357eaf';

abstract class _$OperatorFeedController
    extends $AsyncNotifier<PaginatedFeedState> {
  FutureOr<PaginatedFeedState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<PaginatedFeedState>, PaginatedFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PaginatedFeedState>, PaginatedFeedState>,
              AsyncValue<PaginatedFeedState>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
