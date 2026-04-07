// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'production_entry_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProductionEntryController)
final productionEntryControllerProvider = ProductionEntryControllerProvider._();

final class ProductionEntryControllerProvider
    extends $NotifierProvider<ProductionEntryController, AsyncValue<void>> {
  ProductionEntryControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'productionEntryControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$productionEntryControllerHash();

  @$internal
  @override
  ProductionEntryController create() => ProductionEntryController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$productionEntryControllerHash() =>
    r'dfe535f4e67bf3c709144cedcb1e7a79d92fa7d6';

abstract class _$ProductionEntryController extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
              AsyncValue<void>,
              Object?,
              Object?
            >;
    element.handleCreate(ref, build);
  }
}
