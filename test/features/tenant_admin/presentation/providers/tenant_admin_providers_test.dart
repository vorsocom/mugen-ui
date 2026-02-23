import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/repositories/tenant_admin_repository.dart';
import 'package:mugen_ui/features/tenant_admin/infrastructure/repositories/tenant_admin_repository_impl.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/providers/tenant_admin_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test(
    'tenantAdminRepository provider builds default repository implementation',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(tenantAdminRepositoryProvider);
      expect(repository, isA<TenantAdminRepositoryImpl>());
    },
  );

  test(
    'TenantAdminController loads tenants, details, and supports paging/search',
    () async {
      final repository = _FakeTenantAdminRepository();
      final authController = _TestAuthController();
      final container = ProviderContainer(
        overrides: <Override>[
          tenantAdminRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(tenantAdminControllerProvider.notifier);
      await notifier.loadTenants();

      final state = container.read(tenantAdminControllerProvider);
      expect(state.tenants, hasLength(2));
      expect(state.selectedTenantId, 't-1');
      expect(state.domains, hasLength(1));
      expect(state.invitations, hasLength(1));
      expect(state.memberships, hasLength(1));
      expect(repository.fetchTenantsCallCount, 1);
      expect(repository.fetchDomainsCallCount, 1);
      expect(repository.fetchInvitationsCallCount, 1);
      expect(repository.fetchMembershipsCallCount, 1);

      notifier.setRowsPerPage(25);
      notifier.setPage(99);
      notifier.setSearchTerm('alpha');
      await notifier.loadTenants();
      final query = repository.lastTenantQuery!;
      expect(query.pageRequest.pageSize, 25);
      expect(query.searchTerm, 'alpha');

      await notifier.selectTenant('t-2');
      expect(
        container.read(tenantAdminControllerProvider).selectedTenantId,
        't-2',
      );
      expect(repository.fetchDomainsCallCount, greaterThanOrEqualTo(2));
    },
  );

  test('TenantAdminController mutation success and failure branches', () async {
    final repository = _FakeTenantAdminRepository();
    final authController = _TestAuthController();
    final container = ProviderContainer(
      overrides: <Override>[
        tenantAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => authController),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(tenantAdminControllerProvider.notifier);

    await notifier.loadTenants();

    final createTenantOk = await notifier.createTenant(
      const CreateTenantInput(name: 'New', slug: 'new'),
    );
    expect(createTenantOk, isTrue);
    expect(repository.createTenantCallCount, 1);

    final updateTenantOk = await notifier.updateTenant(
      const UpdateTenantInput(
        tenantId: 't-1',
        name: 'Updated',
        slug: 'updated',
        rowVersion: 1,
      ),
    );
    expect(updateTenantOk, isTrue);

    final deactivateOk = await notifier.deactivateTenant(
      const TenantLifecycleInput(tenantId: 't-1', rowVersion: 1),
    );
    expect(deactivateOk, isTrue);

    final reactivateOk = await notifier.reactivateTenant(
      const TenantLifecycleInput(tenantId: 't-1', rowVersion: 1),
    );
    expect(reactivateOk, isTrue);

    final domainOk = await notifier.createDomain(
      const CreateTenantDomainInput(
        tenantId: 't-1',
        domain: 'a.example.com',
        isPrimary: true,
      ),
    );
    expect(domainOk, isTrue);

    final domainUpdateOk = await notifier.updateDomain(
      const UpdateTenantDomainInput(
        tenantId: 't-1',
        domainId: 'd-1',
        domain: 'b.example.com',
        isPrimary: false,
        rowVersion: 1,
      ),
    );
    expect(domainUpdateOk, isTrue);

    final domainDeleteOk = await notifier.deleteDomain(
      const DeleteTenantDomainInput(
        tenantId: 't-1',
        domainId: 'd-1',
        rowVersion: 1,
      ),
    );
    expect(domainDeleteOk, isTrue);

    final inviteCreateOk = await notifier.createInvitation(
      const CreateTenantInvitationInput(
        tenantId: 't-1',
        email: 'user@example.com',
        roleInTenant: 'member',
      ),
    );
    expect(inviteCreateOk, isTrue);

    final inviteResendOk = await notifier.resendInvitation(
      const TenantInvitationActionInput(
        tenantId: 't-1',
        invitationId: 'i-1',
        rowVersion: 1,
      ),
    );
    expect(inviteResendOk, isTrue);

    final inviteRevokeOk = await notifier.revokeInvitation(
      const TenantInvitationActionInput(
        tenantId: 't-1',
        invitationId: 'i-1',
        rowVersion: 1,
      ),
    );
    expect(inviteRevokeOk, isTrue);

    final membershipCreateOk = await notifier.createMembership(
      const CreateTenantMembershipInput(
        tenantId: 't-1',
        userId: 'u-1',
        roleInTenant: 'member',
      ),
    );
    expect(membershipCreateOk, isTrue);

    final membershipUpdateOk = await notifier.updateMembership(
      const UpdateTenantMembershipInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        roleInTenant: 'owner',
        rowVersion: 1,
      ),
    );
    expect(membershipUpdateOk, isTrue);

    final membershipSuspendOk = await notifier.suspendMembership(
      const TenantMembershipActionInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        rowVersion: 1,
      ),
    );
    expect(membershipSuspendOk, isTrue);

    final membershipUnsuspendOk = await notifier.unsuspendMembership(
      const TenantMembershipActionInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        rowVersion: 1,
      ),
    );
    expect(membershipUnsuspendOk, isTrue);

    final membershipRemoveOk = await notifier.removeMembership(
      const TenantMembershipActionInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        rowVersion: 1,
      ),
    );
    expect(membershipRemoveOk, isTrue);

    repository.mutationResult = const Result<void>.failure(
      ApiFailure(409, 'Conflict'),
    );
    final conflict = await notifier.updateMembership(
      const UpdateTenantMembershipInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        roleInTenant: 'owner',
        rowVersion: 1,
      ),
    );
    expect(conflict, isFalse);
    expect(
      container.read(tenantAdminControllerProvider).errorMessage,
      'Membership changed on the server. Reloading list.',
    );

    repository.mutationResult = const Result<void>.failure(
      SessionExpiredFailure(),
    );
    final expired = await notifier.removeMembership(
      const TenantMembershipActionInput(
        tenantId: 't-1',
        membershipId: 'm-1',
        rowVersion: 1,
      ),
    );
    expect(expired, isFalse);
    expect(authController.refreshCallCount, 1);
  });

  test('TenantAdminController applies load failures', () async {
    final repository = _FakeTenantAdminRepository()
      ..fetchTenantsResult = const Result<PageResult<TenantEntity>>.failure(
        UnexpectedFailure('tenant list failed'),
      );
    final container = ProviderContainer(
      overrides: <Override>[
        tenantAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(tenantAdminControllerProvider.notifier);

    await notifier.loadTenants();
    expect(
      container.read(tenantAdminControllerProvider).errorMessage,
      'tenant list failed',
    );

    repository.fetchTenantsResult = Result<PageResult<TenantEntity>>.success(
      repository.tenantPage,
    );
    await notifier.loadTenants();
    repository.fetchDomainsResult =
        const Result<List<TenantDomainEntity>>.failure(
          UnexpectedFailure('domains failed'),
        );
    await notifier.loadSelectedTenantDetails();
    expect(
      container.read(tenantAdminControllerProvider).errorMessage,
      'domains failed',
    );
  });

  test(
    'TenantAdminController clears detail state when no tenants are returned',
    () async {
      final repository = _FakeTenantAdminRepository()
        ..useConfiguredTenantResult = true
        ..fetchTenantsResult = const Result<PageResult<TenantEntity>>.success(
          PageResult<TenantEntity>(
            items: <TenantEntity>[],
            total: 0,
            page: 1,
            pageSize: 15,
          ),
        );
      final container = ProviderContainer(
        overrides: <Override>[
          tenantAdminRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => _TestAuthController()),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(tenantAdminControllerProvider.notifier)
          .loadTenants();
      final state = container.read(tenantAdminControllerProvider);
      expect(state.selectedTenantId, isNull);
      expect(state.domains, isEmpty);
      expect(state.invitations, isEmpty);
      expect(state.memberships, isEmpty);
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

class _FakeTenantAdminRepository implements TenantAdminRepository {
  _FakeTenantAdminRepository()
    : tenantPage = PageResult<TenantEntity>(
        items: <TenantEntity>[
          TenantEntity(
            id: 't-1',
            name: 'Tenant One',
            slug: 'tenant-one',
            status: 'Active',
            rowVersion: 1,
            dateCreated: DateTime.utc(2024, 1, 1),
            dateLastModified: DateTime.utc(2024, 1, 1),
            deleted: false,
            seedData: false,
          ),
          TenantEntity(
            id: 't-2',
            name: 'Tenant Two',
            slug: 'tenant-two',
            status: 'Inactive',
            rowVersion: 2,
            dateCreated: DateTime.utc(2024, 1, 2),
            dateLastModified: DateTime.utc(2024, 1, 2),
            deleted: false,
            seedData: false,
          ),
        ],
        total: 2,
        page: 1,
        pageSize: 15,
      ),
      _domains = <TenantDomainEntity>[
        TenantDomainEntity(
          id: 'd-1',
          tenantId: 't-1',
          domain: 'tenant.example.com',
          isPrimary: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _invitations = <TenantInvitationEntity>[
        TenantInvitationEntity(
          id: 'i-1',
          tenantId: 't-1',
          email: 'user@example.com',
          roleInTenant: 'member',
          status: 'Pending',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          expiresAt: DateTime.utc(2024, 1, 2),
          deleted: false,
          seedData: false,
        ),
      ],
      _memberships = <TenantMembershipEntity>[
        TenantMembershipEntity(
          id: 'm-1',
          tenantId: 't-1',
          userId: 'u-1',
          roleInTenant: 'owner',
          status: 'Active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ];

  final PageResult<TenantEntity> tenantPage;
  final List<TenantDomainEntity> _domains;
  final List<TenantInvitationEntity> _invitations;
  final List<TenantMembershipEntity> _memberships;

  Result<PageResult<TenantEntity>> fetchTenantsResult =
      const Result<PageResult<TenantEntity>>.success(
        PageResult<TenantEntity>(
          items: <TenantEntity>[],
          total: 0,
          page: 1,
          pageSize: 15,
        ),
      );
  Result<void> mutationResult = const Result<void>.success(null);

  int fetchTenantsCallCount = 0;
  int fetchDomainsCallCount = 0;
  int fetchInvitationsCallCount = 0;
  int fetchMembershipsCallCount = 0;
  int createTenantCallCount = 0;
  bool useConfiguredTenantResult = false;
  TenantListQuery? lastTenantQuery;

  Result<List<TenantDomainEntity>>? fetchDomainsResult;

  @override
  Future<Result<void>> createTenant(CreateTenantInput input) async {
    createTenantCallCount += 1;
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantDomain(CreateTenantDomainInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantInvitation(
    CreateTenantInvitationInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> createTenantMembership(
    CreateTenantMembershipInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deactivateTenant(TenantLifecycleInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> deleteTenantDomain(DeleteTenantDomainInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<List<TenantDomainEntity>>> fetchTenantDomains({
    required String tenantId,
    int top = 100,
  }) async {
    fetchDomainsCallCount += 1;
    return fetchDomainsResult ??
        Result<List<TenantDomainEntity>>.success(_domains);
  }

  @override
  Future<Result<List<TenantInvitationEntity>>> fetchTenantInvitations({
    required String tenantId,
    int top = 100,
  }) async {
    fetchInvitationsCallCount += 1;
    return Result<List<TenantInvitationEntity>>.success(_invitations);
  }

  @override
  Future<Result<List<TenantMembershipEntity>>> fetchTenantMemberships({
    required String tenantId,
    int top = 100,
  }) async {
    fetchMembershipsCallCount += 1;
    return Result<List<TenantMembershipEntity>>.success(_memberships);
  }

  @override
  Future<Result<PageResult<TenantEntity>>> fetchTenants(
    TenantListQuery query,
  ) async {
    fetchTenantsCallCount += 1;
    lastTenantQuery = query;
    if (useConfiguredTenantResult) {
      return fetchTenantsResult;
    }

    if (fetchTenantsResult.isSuccess &&
        fetchTenantsResult.data!.items.isEmpty) {
      return Result<PageResult<TenantEntity>>.success(
        PageResult<TenantEntity>(
          items: tenantPage.items,
          total: tenantPage.total,
          page: query.pageRequest.page,
          pageSize: query.pageRequest.pageSize,
        ),
      );
    }

    return fetchTenantsResult;
  }

  @override
  Future<Result<void>> reactivateTenant(TenantLifecycleInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> removeTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> resendTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> revokeTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> suspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> unsuspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateTenant(UpdateTenantInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateTenantDomain(UpdateTenantDomainInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> updateTenantMembership(
    UpdateTenantMembershipInput input,
  ) async {
    return mutationResult;
  }
}
