// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/repositories/rbac_admin_repository.dart';
import 'package:mugen_ui/features/rbac_admin/infrastructure/repositories/rbac_admin_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

enum RbacAdminTab {
  globalRoles,
  permissionObjects,
  permissionTypes,
  globalGrants,
  tenantRoles,
  roleMemberships,
  tenantGrants,
}

class RbacAdminState {
  const RbacAdminState({
    required this.tenants,
    required this.globalRoles,
    required this.tenantRoles,
    required this.permissionObjects,
    required this.permissionTypes,
    required this.globalPermissionEntries,
    required this.tenantPermissionEntries,
    required this.tenantRoleMemberships,
    required this.tenantMembers,
    required this.activeTab,
    required this.isLoadingGlobal,
    required this.isLoadingTenantScoped,
    required this.isMutating,
    this.selectedTenantId,
    this.errorMessage,
  });

  final List<RbacTenantSummaryEntity> tenants;
  final List<RbacRoleEntity> globalRoles;
  final List<RbacRoleEntity> tenantRoles;
  final List<RbacPermissionObjectEntity> permissionObjects;
  final List<RbacPermissionTypeEntity> permissionTypes;
  final List<RbacPermissionEntryEntity> globalPermissionEntries;
  final List<RbacPermissionEntryEntity> tenantPermissionEntries;
  final List<RbacRoleMembershipEntity> tenantRoleMemberships;
  final List<RbacTenantMemberEntity> tenantMembers;
  final RbacAdminTab activeTab;
  final bool isLoadingGlobal;
  final bool isLoadingTenantScoped;
  final bool isMutating;
  final String? selectedTenantId;
  final String? errorMessage;

  RbacTenantSummaryEntity? get selectedTenant {
    if (selectedTenantId == null) {
      return null;
    }

    for (final tenant in tenants) {
      if (tenant.id == selectedTenantId) {
        return tenant;
      }
    }

    return null;
  }

  RbacAdminState copyWith({
    List<RbacTenantSummaryEntity>? tenants,
    List<RbacRoleEntity>? globalRoles,
    List<RbacRoleEntity>? tenantRoles,
    List<RbacPermissionObjectEntity>? permissionObjects,
    List<RbacPermissionTypeEntity>? permissionTypes,
    List<RbacPermissionEntryEntity>? globalPermissionEntries,
    List<RbacPermissionEntryEntity>? tenantPermissionEntries,
    List<RbacRoleMembershipEntity>? tenantRoleMemberships,
    List<RbacTenantMemberEntity>? tenantMembers,
    RbacAdminTab? activeTab,
    bool? isLoadingGlobal,
    bool? isLoadingTenantScoped,
    bool? isMutating,
    String? selectedTenantId,
    bool clearSelectedTenant = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return RbacAdminState(
      tenants: tenants ?? this.tenants,
      globalRoles: globalRoles ?? this.globalRoles,
      tenantRoles: tenantRoles ?? this.tenantRoles,
      permissionObjects: permissionObjects ?? this.permissionObjects,
      permissionTypes: permissionTypes ?? this.permissionTypes,
      globalPermissionEntries:
          globalPermissionEntries ?? this.globalPermissionEntries,
      tenantPermissionEntries:
          tenantPermissionEntries ?? this.tenantPermissionEntries,
      tenantRoleMemberships:
          tenantRoleMemberships ?? this.tenantRoleMemberships,
      tenantMembers: tenantMembers ?? this.tenantMembers,
      activeTab: activeTab ?? this.activeTab,
      isLoadingGlobal: isLoadingGlobal ?? this.isLoadingGlobal,
      isLoadingTenantScoped:
          isLoadingTenantScoped ?? this.isLoadingTenantScoped,
      isMutating: isMutating ?? this.isMutating,
      selectedTenantId: clearSelectedTenant
          ? null
          : (selectedTenantId ?? this.selectedTenantId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final rbacAdminRepositoryProvider = Provider<RbacAdminRepository>((ref) {
  return RbacAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final rbacAdminControllerProvider =
    StateNotifierProvider<RbacAdminController, RbacAdminState>((ref) {
      return RbacAdminController(ref);
    });

class RbacAdminController extends StateNotifier<RbacAdminState> {
  RbacAdminController(this.ref)
    : super(
        const RbacAdminState(
          tenants: <RbacTenantSummaryEntity>[],
          globalRoles: <RbacRoleEntity>[],
          tenantRoles: <RbacRoleEntity>[],
          permissionObjects: <RbacPermissionObjectEntity>[],
          permissionTypes: <RbacPermissionTypeEntity>[],
          globalPermissionEntries: <RbacPermissionEntryEntity>[],
          tenantPermissionEntries: <RbacPermissionEntryEntity>[],
          tenantRoleMemberships: <RbacRoleMembershipEntity>[],
          tenantMembers: <RbacTenantMemberEntity>[],
          activeTab: RbacAdminTab.globalRoles,
          isLoadingGlobal: false,
          isLoadingTenantScoped: false,
          isMutating: false,
        ),
      );

  final Ref ref;

  Future<void> loadInitialData() async {
    state = state.copyWith(isLoadingGlobal: true, clearError: true);

    final repository = ref.read(rbacAdminRepositoryProvider);
    final tenantsResult = await repository.fetchTenants();
    final globalRolesResult = await repository.fetchGlobalRoles();
    final permissionObjectsResult = await repository.fetchPermissionObjects();
    final permissionTypesResult = await repository.fetchPermissionTypes();
    final globalEntriesResult = await repository.fetchGlobalPermissionEntries();

    final tenants = tenantsResult.data ?? state.tenants;
    final selectedTenantId = _resolveSelectedTenantId(
      availableTenants: tenants,
      previousSelectedTenantId: state.selectedTenantId,
    );

    state = state.copyWith(
      tenants: tenants,
      globalRoles: globalRolesResult.data ?? state.globalRoles,
      permissionObjects:
          permissionObjectsResult.data ?? state.permissionObjects,
      permissionTypes: permissionTypesResult.data ?? state.permissionTypes,
      globalPermissionEntries:
          globalEntriesResult.data ?? state.globalPermissionEntries,
      selectedTenantId: selectedTenantId,
      isLoadingGlobal: false,
      clearError: true,
    );

    final firstFailure =
        tenantsResult.failure ??
        globalRolesResult.failure ??
        permissionObjectsResult.failure ??
        permissionTypesResult.failure ??
        globalEntriesResult.failure;

    if (selectedTenantId == null) {
      state = state.copyWith(
        tenantRoles: const <RbacRoleEntity>[],
        tenantPermissionEntries: const <RbacPermissionEntryEntity>[],
        tenantRoleMemberships: const <RbacRoleMembershipEntity>[],
        tenantMembers: const <RbacTenantMemberEntity>[],
      );
      if (firstFailure != null) {
        _applyFailure(firstFailure, fallback: 'Could not load RBAC resources.');
      }
      return;
    }

    await loadTenantScopedData(tenantId: selectedTenantId);
    if (firstFailure != null) {
      _applyFailure(firstFailure, fallback: 'Could not load RBAC resources.');
    }
  }

  Future<void> refresh() async {
    await loadInitialData();
  }

  Future<void> selectTenant(String tenantId) async {
    if (tenantId == state.selectedTenantId) {
      return;
    }

    state = state.copyWith(selectedTenantId: tenantId);
    await loadTenantScopedData(tenantId: tenantId);
  }

  void setActiveTab(RbacAdminTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<void> loadTenantScopedData({String? tenantId}) async {
    final effectiveTenantId = tenantId ?? state.selectedTenantId;
    if (effectiveTenantId == null || effectiveTenantId.isEmpty) {
      state = state.copyWith(
        tenantRoles: const <RbacRoleEntity>[],
        tenantPermissionEntries: const <RbacPermissionEntryEntity>[],
        tenantRoleMemberships: const <RbacRoleMembershipEntity>[],
        tenantMembers: const <RbacTenantMemberEntity>[],
      );
      return;
    }

    state = state.copyWith(isLoadingTenantScoped: true, clearError: true);

    final repository = ref.read(rbacAdminRepositoryProvider);
    final tenantRolesResult = await repository.fetchTenantRoles(
      tenantId: effectiveTenantId,
    );
    final tenantEntriesResult = await repository.fetchTenantPermissionEntries(
      tenantId: effectiveTenantId,
    );
    final roleMembershipsResult = await repository.fetchTenantRoleMemberships(
      tenantId: effectiveTenantId,
    );
    final tenantMembersResult = await repository.fetchTenantMembers(
      tenantId: effectiveTenantId,
    );

    state = state.copyWith(
      tenantRoles: tenantRolesResult.data ?? state.tenantRoles,
      tenantPermissionEntries:
          tenantEntriesResult.data ?? state.tenantPermissionEntries,
      tenantRoleMemberships:
          roleMembershipsResult.data ?? state.tenantRoleMemberships,
      tenantMembers: tenantMembersResult.data ?? state.tenantMembers,
      isLoadingTenantScoped: false,
      clearError: true,
    );

    final firstFailure =
        tenantRolesResult.failure ??
        tenantEntriesResult.failure ??
        roleMembershipsResult.failure ??
        tenantMembersResult.failure;
    if (firstFailure != null) {
      _applyFailure(
        firstFailure,
        fallback: 'Could not load tenant RBAC resources.',
      );
    }
  }

  Future<bool> createGlobalRole(RbacCreateGlobalRoleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).createGlobalRole(input),
      conflictMessage: 'Global roles changed on the server. Reloading list.',
      reloadOnSuccess: _reloadGlobalRoles,
      reloadOnConflict: _reloadGlobalRoles,
    );
  }

  Future<bool> updateGlobalRole(RbacUpdateGlobalRoleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).updateGlobalRole(input),
      conflictMessage: 'Global roles changed on the server. Reloading list.',
      reloadOnSuccess: _reloadGlobalRoles,
      reloadOnConflict: _reloadGlobalRoles,
    );
  }

  Future<bool> createTenantRole(RbacCreateTenantRoleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).createTenantRole(input),
      conflictMessage: 'Tenant roles changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> updateTenantRole(RbacUpdateTenantRoleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).updateTenantRole(input),
      conflictMessage: 'Tenant roles changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> deprecateTenantRole(RbacTenantRoleLifecycleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).deprecateTenantRole(input),
      conflictMessage: 'Tenant roles changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> reactivateTenantRole(RbacTenantRoleLifecycleInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).reactivateTenantRole(input),
      conflictMessage: 'Tenant roles changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  ) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).createPermissionObject(input),
      conflictMessage:
          'Permission objects changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionObjects,
      reloadOnConflict: _reloadPermissionObjects,
    );
  }

  Future<bool> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .deprecatePermissionObject(input),
      conflictMessage:
          'Permission objects changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionObjects,
      reloadOnConflict: _reloadPermissionObjects,
    );
  }

  Future<bool> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .reactivatePermissionObject(input),
      conflictMessage:
          'Permission objects changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionObjects,
      reloadOnConflict: _reloadPermissionObjects,
    );
  }

  Future<bool> createPermissionType(RbacCreatePermissionTypeInput input) async {
    return _runMutation(
      () => ref.read(rbacAdminRepositoryProvider).createPermissionType(input),
      conflictMessage:
          'Permission types changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionTypes,
      reloadOnConflict: _reloadPermissionTypes,
    );
  }

  Future<bool> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _runMutation(
      () =>
          ref.read(rbacAdminRepositoryProvider).deprecatePermissionType(input),
      conflictMessage:
          'Permission types changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionTypes,
      reloadOnConflict: _reloadPermissionTypes,
    );
  }

  Future<bool> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _runMutation(
      () =>
          ref.read(rbacAdminRepositoryProvider).reactivatePermissionType(input),
      conflictMessage:
          'Permission types changed on the server. Reloading list.',
      reloadOnSuccess: _reloadPermissionTypes,
      reloadOnConflict: _reloadPermissionTypes,
    );
  }

  Future<bool> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .createGlobalPermissionEntry(input),
      conflictMessage: 'Global grants changed on the server. Reloading list.',
      reloadOnSuccess: _reloadGlobalPermissionEntries,
      reloadOnConflict: _reloadGlobalPermissionEntries,
    );
  }

  Future<bool> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .updateGlobalPermissionEntry(input),
      conflictMessage: 'Global grants changed on the server. Reloading list.',
      reloadOnSuccess: _reloadGlobalPermissionEntries,
      reloadOnConflict: _reloadGlobalPermissionEntries,
    );
  }

  Future<bool> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .deleteGlobalPermissionEntry(input),
      conflictMessage: 'Global grants changed on the server. Reloading list.',
      reloadOnSuccess: _reloadGlobalPermissionEntries,
      reloadOnConflict: _reloadGlobalPermissionEntries,
    );
  }

  Future<bool> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .createTenantPermissionEntry(input),
      conflictMessage: 'Tenant grants changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .updateTenantPermissionEntry(input),
      conflictMessage: 'Tenant grants changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .deleteTenantPermissionEntry(input),
      conflictMessage: 'Tenant grants changed on the server. Reloading list.',
      reloadOnSuccess: () => loadTenantScopedData(tenantId: input.tenantId),
      reloadOnConflict: () => loadTenantScopedData(tenantId: input.tenantId),
    );
  }

  Future<bool> createTenantRoleMembership(
    RbacCreateRoleMembershipInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .createTenantRoleMembership(input),
      conflictMessage:
          'Role memberships changed on the server. Reloading list.',
      reloadOnSuccess: () => _reloadTenantRoleMemberships(input.tenantId),
      reloadOnConflict: () => _reloadTenantRoleMemberships(input.tenantId),
    );
  }

  Future<bool> deleteTenantRoleMembership(
    RbacDeleteRoleMembershipInput input,
  ) async {
    return _runMutation(
      () => ref
          .read(rbacAdminRepositoryProvider)
          .deleteTenantRoleMembership(input),
      conflictMessage:
          'Role memberships changed on the server. Reloading list.',
      reloadOnSuccess: () => _reloadTenantRoleMemberships(input.tenantId),
      reloadOnConflict: () => _reloadTenantRoleMemberships(input.tenantId),
    );
  }

  Future<void> _reloadGlobalRoles() async {
    final response = await ref
        .read(rbacAdminRepositoryProvider)
        .fetchGlobalRoles();
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load global roles.',
      );
      return;
    }

    state = state.copyWith(globalRoles: response.data!, clearError: true);
  }

  Future<void> _reloadPermissionObjects() async {
    final response = await ref
        .read(rbacAdminRepositoryProvider)
        .fetchPermissionObjects();
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load permission objects.',
      );
      return;
    }

    state = state.copyWith(permissionObjects: response.data!, clearError: true);
  }

  Future<void> _reloadPermissionTypes() async {
    final response = await ref
        .read(rbacAdminRepositoryProvider)
        .fetchPermissionTypes();
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load permission types.',
      );
      return;
    }

    state = state.copyWith(permissionTypes: response.data!, clearError: true);
  }

  Future<void> _reloadGlobalPermissionEntries() async {
    final response = await ref
        .read(rbacAdminRepositoryProvider)
        .fetchGlobalPermissionEntries();
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load global grants.',
      );
      return;
    }

    state = state.copyWith(
      globalPermissionEntries: response.data!,
      clearError: true,
    );
  }

  Future<void> _reloadTenantRoleMemberships(String tenantId) async {
    final response = await ref
        .read(rbacAdminRepositoryProvider)
        .fetchTenantRoleMemberships(tenantId: tenantId);
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load role memberships.',
      );
      return;
    }

    state = state.copyWith(
      tenantRoleMemberships: response.data!,
      clearError: true,
    );
  }

  Future<bool> _runMutation(
    Future<Result<void>> Function() run, {
    required String conflictMessage,
    required Future<void> Function() reloadOnSuccess,
    required Future<void> Function() reloadOnConflict,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);

    final response = await run();
    state = state.copyWith(isMutating: false);

    if (response.isSuccess) {
      await reloadOnSuccess();
      return true;
    }

    final failure = response.failure!;
    if (failure is ApiFailure && failure.statusCode == 409) {
      await reloadOnConflict();
      state = state.copyWith(errorMessage: conflictMessage);
      return false;
    }

    _applyFailure(failure, fallback: 'API error.');
    return false;
  }

  void _applyFailure(Failure failure, {required String fallback}) {
    if (failure is SessionExpiredFailure) {
      ref.read(authControllerProvider.notifier).refreshSession();
    }

    state = state.copyWith(
      errorMessage: failure.message.isEmpty ? fallback : failure.message,
    );
  }

  String? _resolveSelectedTenantId({
    required List<RbacTenantSummaryEntity> availableTenants,
    required String? previousSelectedTenantId,
  }) {
    if (availableTenants.isEmpty) {
      return null;
    }

    if (previousSelectedTenantId == null) {
      return availableTenants.first.id;
    }

    final exists = availableTenants.any(
      (tenant) => tenant.id == previousSelectedTenantId,
    );
    return exists ? previousSelectedTenantId : availableTenants.first.id;
  }
}
