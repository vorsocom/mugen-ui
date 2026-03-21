// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_admin_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$userAdminRepositoryHash() =>
    r'817d72081725de3eea6de00f8177c2f535a2199b';

/// See also [userAdminRepository].
@ProviderFor(userAdminRepository)
final userAdminRepositoryProvider = Provider<UserAdminRepository>.internal(
  userAdminRepository,
  name: r'userAdminRepositoryProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userAdminRepositoryHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserAdminRepositoryRef = ProviderRef<UserAdminRepository>;
String _$userAdminServiceHash() => r'b03f14bb4b1ab5064d66cf89d06c2dcc869138b3';

/// See also [userAdminService].
@ProviderFor(userAdminService)
final userAdminServiceProvider = Provider<UserAdminService>.internal(
  userAdminService,
  name: r'userAdminServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$userAdminServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef UserAdminServiceRef = ProviderRef<UserAdminService>;
String _$userAdminControllerHash() =>
    r'280c66c6f24330e6e7473e15f0e34864da43199c';

/// See also [UserAdminController].
@ProviderFor(UserAdminController)
final userAdminControllerProvider =
    NotifierProvider<UserAdminController, UserAdminState>.internal(
      UserAdminController.new,
      name: r'userAdminControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$userAdminControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$UserAdminController = Notifier<UserAdminState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
