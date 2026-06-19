import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_assignable_user_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/repositories/rbac_admin_repository.dart';
import 'package:mugen_ui/features/rbac_admin/infrastructure/repositories/rbac_admin_repository_impl.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/providers/rbac_admin_providers.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test('rbacAdminRepository provider builds default implementation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(rbacAdminRepositoryProvider);
    expect(repository, isA<RbacAdminRepositoryImpl>());
  });

  test('RbacAdminController loads global and tenant-scoped data', () async {
    final repository = _FakeRbacAdminRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        rbacAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(rbacAdminControllerProvider.notifier);
    await notifier.loadInitialData();

    final state = container.read(rbacAdminControllerProvider);
    expect(state.tenants, hasLength(2));
    expect(state.globalRoles, hasLength(1));
    expect(state.permissionObjects, hasLength(1));
    expect(state.permissionTypes, hasLength(1));
    expect(state.globalPermissionEntries, hasLength(1));
    expect(state.globalRoleMemberships, hasLength(1));
    expect(state.globalUsers, hasLength(2));
    expect(state.selectedTenantId, 'tenant-1');
    expect(state.tenantRoles, hasLength(1));
    expect(state.tenantPermissionEntries, hasLength(1));
    expect(state.tenantRoleMemberships, hasLength(1));
    expect(state.tenantMembers, hasLength(1));

    await notifier.selectTenant('tenant-2');
    expect(
      container.read(rbacAdminControllerProvider).selectedTenantId,
      'tenant-2',
    );
    expect(repository.lastTenantRoleTenantId, 'tenant-2');
    expect(repository.lastTenantEntryTenantId, 'tenant-2');
    expect(repository.lastTenantRoleMembershipTenantId, 'tenant-2');
    expect(repository.lastTenantMemberTenantId, 'tenant-2');
    expect(repository.fetchTenantRolesCallCount, greaterThanOrEqualTo(2));
    expect(repository.fetchTenantEntriesCallCount, greaterThanOrEqualTo(2));
    expect(
      repository.fetchTenantRoleMembershipsCallCount,
      greaterThanOrEqualTo(2),
    );
    expect(repository.fetchTenantMembersCallCount, greaterThanOrEqualTo(2));
  });

  test('RbacAdminController mutation success and conflict paths', () async {
    final repository = _FakeRbacAdminRepository();
    final auth = _TestAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        rbacAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => auth),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(rbacAdminControllerProvider.notifier);
    await notifier.loadInitialData();

    final createGlobalRoleOk = await notifier.createGlobalRole(
      const RbacCreateGlobalRoleInput(
        namespace: 'acp',
        name: 'auditor',
        displayName: 'Auditor',
      ),
    );
    expect(createGlobalRoleOk, isTrue);
    expect(repository.createGlobalRoleInputs, hasLength(1));

    final createTenantGrantOk = await notifier.createTenantPermissionEntry(
      const RbacCreateTenantPermissionEntryInput(
        tenantId: 'tenant-1',
        roleId: 'tr-1',
        permissionObjectId: 'po-1',
        permissionTypeId: 'pt-1',
        permitted: true,
      ),
    );
    expect(createTenantGrantOk, isTrue);
    expect(repository.createTenantPermissionEntryInputs, hasLength(1));

    final globalRoleMembershipFetchesBeforeCreate =
        repository.fetchGlobalRoleMembershipsCallCount;
    final createGlobalRoleMembershipOk = await notifier
        .createGlobalRoleMembership(
          const RbacCreateGlobalRoleMembershipInput(
            roleId: 'gr-1',
            userId: 'user-2',
          ),
        );
    expect(createGlobalRoleMembershipOk, isTrue);
    expect(repository.createGlobalRoleMembershipInputs, hasLength(1));
    expect(
      repository.fetchGlobalRoleMembershipsCallCount,
      greaterThan(globalRoleMembershipFetchesBeforeCreate),
    );

    final roleMembershipFetchesBeforeCreate =
        repository.fetchTenantRoleMembershipsCallCount;
    final createRoleMembershipOk = await notifier.createTenantRoleMembership(
      const RbacCreateRoleMembershipInput(
        tenantId: 'tenant-1',
        roleId: 'tr-1',
        userId: 'user-2',
      ),
    );
    expect(createRoleMembershipOk, isTrue);
    expect(repository.createTenantRoleMembershipInputs, hasLength(1));
    expect(
      repository.fetchTenantRoleMembershipsCallCount,
      greaterThan(roleMembershipFetchesBeforeCreate),
    );

    repository.mutationResult = const Result<void>.failure(
      ApiFailure(409, 'Conflict'),
    );
    final conflict = await notifier.updateTenantPermissionEntry(
      const RbacUpdateTenantPermissionEntryInput(
        tenantId: 'tenant-1',
        entryId: 'tpe-1',
        rowVersion: 1,
        permitted: false,
      ),
    );
    expect(conflict, isFalse);
    expect(
      container.read(rbacAdminControllerProvider).errorMessage,
      'Tenant grants changed on the server. Reloading list.',
    );

    final roleMembershipFetchesBeforeConflict =
        repository.fetchTenantRoleMembershipsCallCount;
    final roleMembershipConflict = await notifier.deleteTenantRoleMembership(
      const RbacDeleteRoleMembershipInput(
        tenantId: 'tenant-1',
        membershipId: 'rm-1',
        rowVersion: 1,
      ),
    );
    expect(roleMembershipConflict, isFalse);
    expect(repository.deleteTenantRoleMembershipInputs, hasLength(1));
    expect(
      repository.fetchTenantRoleMembershipsCallCount,
      greaterThan(roleMembershipFetchesBeforeConflict),
    );
    expect(
      container.read(rbacAdminControllerProvider).errorMessage,
      'Tenant role memberships changed on the server. Reloading list.',
    );

    repository.mutationResult = const Result<void>.failure(
      SessionExpiredFailure(),
    );
    final expired = await notifier.createPermissionObject(
      const RbacCreatePermissionObjectInput(namespace: 'acp', name: 'tenant'),
    );
    expect(expired, isFalse);
    expect(auth.refreshCallCount, 1);
  });

  test('RbacAdminController load failures set error message', () async {
    final repository = _FakeRbacAdminRepository()
      ..fetchGlobalRolesResult = const Result<List<RbacRoleEntity>>.failure(
        UnexpectedFailure('global roles failed'),
      );
    final container = ProviderContainer(
      overrides: <Override>[
        rbacAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
    );
    addTearDown(container.dispose);

    await container
        .read(rbacAdminControllerProvider.notifier)
        .loadInitialData();
    expect(
      container.read(rbacAdminControllerProvider).errorMessage,
      'global roles failed',
    );
  });

  test(
    'RbacAdminController clears tenant-scoped state without tenants',
    () async {
      final repository = _FakeRbacAdminRepository()..returnNoTenants = true;
      final container = ProviderContainer(
        overrides: <Override>[
          rbacAdminRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(rbacAdminControllerProvider.notifier)
          .loadInitialData();

      final state = container.read(rbacAdminControllerProvider);
      expect(state.selectedTenantId, isNull);
      expect(state.tenantRoles, isEmpty);
      expect(state.tenantPermissionEntries, isEmpty);
      expect(state.tenantRoleMemberships, isEmpty);
      expect(state.tenantMembers, isEmpty);
      expect(repository.fetchTenantRoleMembershipsCallCount, 0);
      expect(repository.fetchTenantMembersCallCount, 0);
    },
  );
}

class _TestAuthController extends AuthController {
  int refreshCallCount = 0;

  @override
  AuthControllerState build() {
    return const AuthControllerState(isLoading: false, session: null);
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> logout() async => true;

  @override
  void refreshSession() {
    refreshCallCount += 1;
  }

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}

class _FakeRbacAdminRepository implements RbacAdminRepository {
  _FakeRbacAdminRepository()
    : _tenants = const <RbacTenantSummaryEntity>[
        RbacTenantSummaryEntity(
          id: 'tenant-1',
          name: 'Tenant One',
          slug: 'tenant-one',
          status: 'Active',
          rowVersion: 1,
        ),
        RbacTenantSummaryEntity(
          id: 'tenant-2',
          name: 'Tenant Two',
          slug: 'tenant-two',
          status: 'Active',
          rowVersion: 2,
        ),
      ],
      _globalRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'gr-1',
          namespace: 'acp',
          name: 'administrator',
          displayName: 'Administrator',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: null,
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'tr-1',
          namespace: 'acp',
          name: 'member',
          displayName: 'Member',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: 'tenant-1',
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionObjects = <RbacPermissionObjectEntity>[
        RbacPermissionObjectEntity(
          id: 'po-1',
          namespace: 'acp',
          name: 'tenant',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionTypes = <RbacPermissionTypeEntity>[
        RbacPermissionTypeEntity(
          id: 'pt-1',
          namespace: 'acp',
          name: 'manage',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'gpe-1',
          tenantId: null,
          roleId: 'gr-1',
          roleDisplayName: 'Administrator',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalRoleMemberships = <RbacRoleMembershipEntity>[
        RbacRoleMembershipEntity(
          id: 'grm-1',
          tenantId: null,
          roleId: 'gr-1',
          userId: 'user-1',
          roleDisplayName: 'Administrator',
          roleKey: 'acp:administrator',
          roleNamespace: 'acp',
          roleName: 'administrator',
          userDisplayName: 'alice@example.com',
          userEmail: 'alice@example.com',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalUsers = const <RbacAssignableUserEntity>[
        RbacAssignableUserEntity(
          id: 'user-1',
          username: 'alice-login',
          displayName: 'alice@example.com',
          email: 'alice@example.com',
          deleted: false,
          seedData: false,
        ),
        RbacAssignableUserEntity(
          id: 'user-2',
          username: 'bob-login',
          displayName: 'bob@example.com',
          email: 'bob@example.com',
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'tpe-1',
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          roleDisplayName: 'Member',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantRoleMemberships = <RbacRoleMembershipEntity>[
        RbacRoleMembershipEntity(
          id: 'rm-1',
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          userId: 'user-1',
          roleDisplayName: 'Member',
          roleKey: 'acp:member',
          roleNamespace: 'acp',
          roleName: 'member',
          userDisplayName: 'alice@example.com',
          userEmail: 'alice@example.com',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantMembers = <RbacTenantMemberEntity>[
        const RbacTenantMemberEntity(
          membershipId: 'tm-1',
          tenantId: 'tenant-1',
          userId: 'user-1',
          username: 'alice-login',
          displayName: 'alice@example.com',
          email: 'alice@example.com',
          status: 'active',
          deleted: false,
        ),
      ];

  final List<RbacTenantSummaryEntity> _tenants;
  final List<RbacRoleEntity> _globalRoles;
  final List<RbacRoleEntity> _tenantRoles;
  final List<RbacPermissionObjectEntity> _permissionObjects;
  final List<RbacPermissionTypeEntity> _permissionTypes;
  final List<RbacPermissionEntryEntity> _globalEntries;
  final List<RbacRoleMembershipEntity> _globalRoleMemberships;
  final List<RbacAssignableUserEntity> _globalUsers;
  final List<RbacPermissionEntryEntity> _tenantEntries;
  final List<RbacRoleMembershipEntity> _tenantRoleMemberships;
  final List<RbacTenantMemberEntity> _tenantMembers;

  bool returnNoTenants = false;

  Result<List<RbacTenantSummaryEntity>> fetchTenantsResult =
      const Result<List<RbacTenantSummaryEntity>>.success(
        <RbacTenantSummaryEntity>[],
      );
  Result<List<RbacRoleEntity>> fetchGlobalRolesResult =
      const Result<List<RbacRoleEntity>>.success(<RbacRoleEntity>[]);
  Result<List<RbacRoleEntity>> fetchTenantRolesResult =
      const Result<List<RbacRoleEntity>>.success(<RbacRoleEntity>[]);
  Result<List<RbacPermissionObjectEntity>> fetchPermissionObjectsResult =
      const Result<List<RbacPermissionObjectEntity>>.success(
        <RbacPermissionObjectEntity>[],
      );
  Result<List<RbacPermissionTypeEntity>> fetchPermissionTypesResult =
      const Result<List<RbacPermissionTypeEntity>>.success(
        <RbacPermissionTypeEntity>[],
      );
  Result<List<RbacPermissionEntryEntity>> fetchGlobalEntriesResult =
      const Result<List<RbacPermissionEntryEntity>>.success(
        <RbacPermissionEntryEntity>[],
      );
  Result<List<RbacRoleMembershipEntity>> fetchGlobalRoleMembershipsResult =
      const Result<List<RbacRoleMembershipEntity>>.success(
        <RbacRoleMembershipEntity>[],
      );
  Result<List<RbacAssignableUserEntity>> fetchGlobalUsersResult =
      const Result<List<RbacAssignableUserEntity>>.success(
        <RbacAssignableUserEntity>[],
      );
  Result<List<RbacPermissionEntryEntity>> fetchTenantEntriesResult =
      const Result<List<RbacPermissionEntryEntity>>.success(
        <RbacPermissionEntryEntity>[],
      );
  Result<List<RbacRoleMembershipEntity>> fetchTenantRoleMembershipsResult =
      const Result<List<RbacRoleMembershipEntity>>.success(
        <RbacRoleMembershipEntity>[],
      );
  Result<List<RbacTenantMemberEntity>> fetchTenantMembersResult =
      const Result<List<RbacTenantMemberEntity>>.success(
        <RbacTenantMemberEntity>[],
      );

  Result<void> mutationResult = const Result<void>.success(null);

  int fetchTenantRolesCallCount = 0;
  int fetchTenantEntriesCallCount = 0;
  int fetchGlobalRoleMembershipsCallCount = 0;
  int fetchTenantRoleMembershipsCallCount = 0;
  int fetchTenantMembersCallCount = 0;
  String? lastTenantRoleTenantId;
  String? lastTenantEntryTenantId;
  String? lastTenantRoleMembershipTenantId;
  String? lastTenantMemberTenantId;

  final List<RbacCreateGlobalRoleInput> createGlobalRoleInputs =
      <RbacCreateGlobalRoleInput>[];
  final List<RbacCreateTenantPermissionEntryInput>
  createTenantPermissionEntryInputs = <RbacCreateTenantPermissionEntryInput>[];
  final List<RbacCreateRoleMembershipInput> createTenantRoleMembershipInputs =
      <RbacCreateRoleMembershipInput>[];
  final List<RbacCreateGlobalRoleMembershipInput>
  createGlobalRoleMembershipInputs = <RbacCreateGlobalRoleMembershipInput>[];
  final List<RbacDeleteRoleMembershipInput> deleteTenantRoleMembershipInputs =
      <RbacDeleteRoleMembershipInput>[];
  final List<RbacDeleteGlobalRoleMembershipInput>
  deleteGlobalRoleMembershipInputs = <RbacDeleteGlobalRoleMembershipInput>[];

  @override
  Future<Result<void>> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> createGlobalRole(RbacCreateGlobalRoleInput input) async {
    createGlobalRoleInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> createGlobalRoleMembership(
    RbacCreateGlobalRoleMembershipInput input,
  ) async {
    createGlobalRoleMembershipInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> createPermissionType(
    RbacCreatePermissionTypeInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  ) async {
    createTenantPermissionEntryInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantRoleMembership(
    RbacCreateRoleMembershipInput input,
  ) async {
    createTenantRoleMembershipInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantRole(RbacCreateTenantRoleInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deleteGlobalRoleMembership(
    RbacDeleteGlobalRoleMembershipInput input,
  ) async {
    deleteGlobalRoleMembershipInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deleteTenantRoleMembership(
    RbacDeleteRoleMembershipInput input,
  ) async {
    deleteTenantRoleMembershipInputs.add(input);
    return mutationResult;
  }

  @override
  Future<Result<void>> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deprecateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchGlobalPermissionEntries({
    int top = 200,
  }) async {
    if (fetchGlobalEntriesResult.isSuccess &&
        fetchGlobalEntriesResult.data!.isEmpty) {
      return Result<List<RbacPermissionEntryEntity>>.success(_globalEntries);
    }

    return fetchGlobalEntriesResult;
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchGlobalRoles({int top = 200}) async {
    if (fetchGlobalRolesResult.isSuccess &&
        fetchGlobalRolesResult.data!.isEmpty) {
      return Result<List<RbacRoleEntity>>.success(_globalRoles);
    }

    return fetchGlobalRolesResult;
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchGlobalRoleMemberships({
    int top = 200,
  }) async {
    fetchGlobalRoleMembershipsCallCount += 1;
    if (fetchGlobalRoleMembershipsResult.isSuccess &&
        fetchGlobalRoleMembershipsResult.data!.isEmpty) {
      return Result<List<RbacRoleMembershipEntity>>.success(
        _globalRoleMemberships,
      );
    }

    return fetchGlobalRoleMembershipsResult;
  }

  @override
  Future<Result<List<RbacAssignableUserEntity>>> fetchGlobalUsers({
    int top = 200,
  }) async {
    if (fetchGlobalUsersResult.isSuccess &&
        fetchGlobalUsersResult.data!.isEmpty) {
      return Result<List<RbacAssignableUserEntity>>.success(_globalUsers);
    }

    return fetchGlobalUsersResult;
  }

  @override
  Future<Result<List<RbacPermissionObjectEntity>>> fetchPermissionObjects({
    int top = 200,
  }) async {
    if (fetchPermissionObjectsResult.isSuccess &&
        fetchPermissionObjectsResult.data!.isEmpty) {
      return Result<List<RbacPermissionObjectEntity>>.success(
        _permissionObjects,
      );
    }

    return fetchPermissionObjectsResult;
  }

  @override
  Future<Result<List<RbacPermissionTypeEntity>>> fetchPermissionTypes({
    int top = 200,
  }) async {
    if (fetchPermissionTypesResult.isSuccess &&
        fetchPermissionTypesResult.data!.isEmpty) {
      return Result<List<RbacPermissionTypeEntity>>.success(_permissionTypes);
    }

    return fetchPermissionTypesResult;
  }

  @override
  Future<Result<List<RbacTenantSummaryEntity>>> fetchTenants({
    int top = 200,
  }) async {
    if (returnNoTenants) {
      return const Result<List<RbacTenantSummaryEntity>>.success(
        <RbacTenantSummaryEntity>[],
      );
    }
    if (fetchTenantsResult.isSuccess && fetchTenantsResult.data!.isEmpty) {
      return Result<List<RbacTenantSummaryEntity>>.success(_tenants);
    }

    return fetchTenantsResult;
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchTenantPermissionEntries({
    required String tenantId,
    int top = 200,
  }) async {
    fetchTenantEntriesCallCount += 1;
    lastTenantEntryTenantId = tenantId;
    if (fetchTenantEntriesResult.isSuccess &&
        fetchTenantEntriesResult.data!.isEmpty) {
      return Result<List<RbacPermissionEntryEntity>>.success(_tenantEntries);
    }

    return fetchTenantEntriesResult;
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchTenantRoleMemberships({
    required String tenantId,
    int top = 200,
  }) async {
    fetchTenantRoleMembershipsCallCount += 1;
    lastTenantRoleMembershipTenantId = tenantId;
    if (fetchTenantRoleMembershipsResult.isSuccess &&
        fetchTenantRoleMembershipsResult.data!.isEmpty) {
      return Result<List<RbacRoleMembershipEntity>>.success(
        _tenantRoleMemberships,
      );
    }

    return fetchTenantRoleMembershipsResult;
  }

  @override
  Future<Result<List<RbacTenantMemberEntity>>> fetchTenantMembers({
    required String tenantId,
    int top = 200,
  }) async {
    fetchTenantMembersCallCount += 1;
    lastTenantMemberTenantId = tenantId;
    if (fetchTenantMembersResult.isSuccess &&
        fetchTenantMembersResult.data!.isEmpty) {
      return Result<List<RbacTenantMemberEntity>>.success(_tenantMembers);
    }

    return fetchTenantMembersResult;
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchTenantRoles({
    required String tenantId,
    int top = 200,
  }) async {
    fetchTenantRolesCallCount += 1;
    lastTenantRoleTenantId = tenantId;
    if (fetchTenantRolesResult.isSuccess &&
        fetchTenantRolesResult.data!.isEmpty) {
      return Result<List<RbacRoleEntity>>.success(_tenantRoles);
    }

    return fetchTenantRolesResult;
  }

  @override
  Future<Result<void>> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> reactivateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateGlobalRole(RbacUpdateGlobalRoleInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateTenantRole(RbacUpdateTenantRoleInput input) async {
    return mutationResult;
  }
}
