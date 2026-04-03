// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_storage_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sharedPreferences)
final sharedPreferencesProvider = SharedPreferencesProvider._();

final class SharedPreferencesProvider
    extends
        $FunctionalProvider<
          AsyncValue<SharedPreferences>,
          SharedPreferences,
          FutureOr<SharedPreferences>
        >
    with
        $FutureModifier<SharedPreferences>,
        $FutureProvider<SharedPreferences> {
  SharedPreferencesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sharedPreferencesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sharedPreferencesHash();

  @$internal
  @override
  $FutureProviderElement<SharedPreferences> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SharedPreferences> create(Ref ref) {
    return sharedPreferences(ref);
  }
}

String _$sharedPreferencesHash() => r'dc403fbb1d968c7d5ab4ae1721a29ffe173701c7';

@ProviderFor(localStorageRepository)
final localStorageRepositoryProvider = LocalStorageRepositoryProvider._();

final class LocalStorageRepositoryProvider
    extends
        $FunctionalProvider<
          LocalStorageRepository,
          LocalStorageRepository,
          LocalStorageRepository
        >
    with $Provider<LocalStorageRepository> {
  LocalStorageRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'localStorageRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$localStorageRepositoryHash();

  @$internal
  @override
  $ProviderElement<LocalStorageRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LocalStorageRepository create(Ref ref) {
    return localStorageRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LocalStorageRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LocalStorageRepository>(value),
    );
  }
}

String _$localStorageRepositoryHash() =>
    r'4d627194f47f5b3c2ded17f7ed3c5d2893565b73';
