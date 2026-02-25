import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_chain_verification_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_lifecycle_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_seal_backlog_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/repositories/audit_admin_repository.dart';
import 'package:mugen_ui/features/audit_admin/infrastructure/repositories/audit_admin_repository_impl.dart';
import 'package:mugen_ui/features/audit_admin/presentation/providers/audit_admin_providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test('auditAdminRepository provider builds default implementation', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final repository = container.read(auditAdminRepositoryProvider);
    expect(repository, isA<AuditAdminRepositoryImpl>());
  });

  test('AuditAdminController loads data and handles scope switches', () async {
    final repository = _FakeAuditAdminRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        auditAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(auditAdminControllerProvider.notifier);
    await notifier.loadInitialData();

    var state = container.read(auditAdminControllerProvider);
    expect(state.events, hasLength(2));
    expect(state.tenants, hasLength(2));
    expect(state.scopeMode, AuditAdminScopeMode.global);
    expect(state.selectedEventId, 'global-1');
    expect(repository.lastQuery?.scopeMode, AuditAdminScopeMode.global);

    notifier.setPage(3);
    await notifier.setScopeMode(AuditAdminScopeMode.tenant);

    state = container.read(auditAdminControllerProvider);
    expect(state.scopeMode, AuditAdminScopeMode.tenant);
    expect(state.page, 1);
    expect(repository.lastQuery?.scopeMode, AuditAdminScopeMode.tenant);
    expect(repository.lastQuery?.tenantId, 'tenant-1');

    await notifier.selectTenant('tenant-2');
    expect(repository.lastQuery?.tenantId, 'tenant-2');
    expect(
      container.read(auditAdminControllerProvider).selectedTenantId,
      'tenant-2',
    );
  });

  test(
    'AuditAdminController mutation branches refresh and set errors',
    () async {
      final repository = _FakeAuditAdminRepository();
      final authController = _TestAuthController();
      final container = ProviderContainer(
        overrides: <Override>[
          auditAdminRepositoryProvider.overrideWithValue(repository),
          authControllerProvider.overrideWith(() => authController),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(auditAdminControllerProvider.notifier);
      await notifier.loadInitialData();

      final fetchBefore = repository.fetchEventsCallCount;
      final placeHoldOk = await notifier.placeLegalHold(
        const AuditPlaceLegalHoldInput(
          eventId: 'global-1',
          rowVersion: 1,
          reason: 'hold',
          scopeMode: AuditAdminScopeMode.global,
        ),
      );
      expect(placeHoldOk, isTrue);
      expect(repository.fetchEventsCallCount, greaterThan(fetchBefore));

      repository.mutationResult = const Result<void>.failure(
        ApiFailure(409, 'conflict'),
      );
      final redactConflict = await notifier.redactEvent(
        const AuditRedactInput(
          eventId: 'global-1',
          rowVersion: 1,
          reason: 'redact',
          scopeMode: AuditAdminScopeMode.global,
        ),
      );
      expect(redactConflict, isFalse);
      expect(
        container.read(auditAdminControllerProvider).errorMessage,
        'Audit event changed on the server. Reloading events.',
      );

      repository.mutationResult = const Result<void>.failure(
        SessionExpiredFailure(),
      );
      final tombstoneExpired = await notifier.tombstoneEvent(
        const AuditTombstoneInput(
          eventId: 'global-1',
          rowVersion: 1,
          reason: 'expire',
          scopeMode: AuditAdminScopeMode.global,
        ),
      );
      expect(tombstoneExpired, isFalse);
      expect(authController.refreshCallCount, 1);
    },
  );

  test('AuditAdminController stores latest set-action summaries', () async {
    final repository = _FakeAuditAdminRepository();
    final container = ProviderContainer(
      overrides: <Override>[
        auditAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(auditAdminControllerProvider.notifier);
    await notifier.loadInitialData();

    final lifecycle = await notifier.runLifecycle(
      const AuditRunLifecycleInput(scopeMode: AuditAdminScopeMode.global),
    );
    expect(lifecycle, isTrue);
    expect(repository.lastRunLifecycleInput, isNotNull);
    expect(repository.lastRunLifecycleInput!.dryRun, isTrue);

    final verify = await notifier.verifyChain(
      const AuditVerifyChainInput(scopeMode: AuditAdminScopeMode.global),
    );
    expect(verify, isTrue);

    final seal = await notifier.sealBacklog(
      const AuditSealBacklogInput(scopeMode: AuditAdminScopeMode.global),
    );
    expect(seal, isTrue);

    final state = container.read(auditAdminControllerProvider);
    expect(state.latestLifecycleSummary, isNotNull);
    expect(state.latestChainSummary, isNotNull);
    expect(state.latestSealSummary, isNotNull);
  });
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

class _FakeAuditAdminRepository implements AuditAdminRepository {
  _FakeAuditAdminRepository()
    : _tenants = const <AuditTenantOptionEntity>[
        AuditTenantOptionEntity(
          id: 'tenant-1',
          name: 'Tenant One',
          slug: 'tenant-one',
          status: 'Active',
        ),
        AuditTenantOptionEntity(
          id: 'tenant-2',
          name: 'Tenant Two',
          slug: 'tenant-two',
          status: 'Active',
        ),
      ],
      _globalEvents = <AuditEventEntity>[
        _buildEvent('global-1', null),
        _buildEvent('global-2', null),
      ],
      _tenantOneEvents = <AuditEventEntity>[
        _buildEvent('tenant-1-e1', 'tenant-1'),
      ],
      _tenantTwoEvents = <AuditEventEntity>[
        _buildEvent('tenant-2-e1', 'tenant-2'),
      ];

  final List<AuditTenantOptionEntity> _tenants;
  final List<AuditEventEntity> _globalEvents;
  final List<AuditEventEntity> _tenantOneEvents;
  final List<AuditEventEntity> _tenantTwoEvents;

  AuditEventListQuery? lastQuery;
  int fetchEventsCallCount = 0;

  Result<void> mutationResult = const Result<void>.success(null);
  Result<AuditLifecycleSummaryEntity> runLifecycleResult =
      Result<AuditLifecycleSummaryEntity>.success(
        const AuditLifecycleSummaryEntity(
          dryRun: true,
          now: null,
          batchSize: 100,
          maxBatches: 10,
          phases: <String, AuditLifecyclePhaseSummaryEntity>{},
          totalProcessed: 0,
        ),
      );
  Result<AuditChainVerificationSummaryEntity> verifyChainResult =
      Result<AuditChainVerificationSummaryEntity>.success(
        const AuditChainVerificationSummaryEntity(
          isValid: true,
          checkedRows: 0,
          mismatchCount: 0,
          mismatches: <AuditChainMismatchEntity>[],
        ),
      );
  Result<AuditSealBacklogSummaryEntity> sealBacklogResult =
      Result<AuditSealBacklogSummaryEntity>.success(
        const AuditSealBacklogSummaryEntity(
          rowsSealed: 0,
          remainingCount: 0,
          batches: 0,
          batchSize: 100,
          maxBatches: 10,
        ),
      );

  AuditRunLifecycleInput? lastRunLifecycleInput;

  @override
  Future<Result<PageResult<AuditEventEntity>>> fetchAuditEvents(
    AuditEventListQuery query,
  ) async {
    lastQuery = query;
    fetchEventsCallCount += 1;

    final events = switch (query.scopeMode) {
      AuditAdminScopeMode.global => _globalEvents,
      AuditAdminScopeMode.tenant =>
        query.tenantId == 'tenant-2' ? _tenantTwoEvents : _tenantOneEvents,
    };

    return Result<PageResult<AuditEventEntity>>.success(
      PageResult<AuditEventEntity>(
        items: events,
        total: events.length,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<List<AuditTenantOptionEntity>>> fetchTenants({
    int top = 200,
  }) async {
    return Result<List<AuditTenantOptionEntity>>.success(_tenants);
  }

  @override
  Future<Result<void>> placeLegalHold(AuditPlaceLegalHoldInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> redactEvent(AuditRedactInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<void>> releaseLegalHold(
    AuditReleaseLegalHoldInput input,
  ) async {
    return mutationResult;
  }

  @override
  Future<Result<AuditLifecycleSummaryEntity>> runLifecycle(
    AuditRunLifecycleInput input,
  ) async {
    lastRunLifecycleInput = input;
    return runLifecycleResult;
  }

  @override
  Future<Result<AuditSealBacklogSummaryEntity>> sealBacklog(
    AuditSealBacklogInput input,
  ) async {
    return sealBacklogResult;
  }

  @override
  Future<Result<void>> tombstoneEvent(AuditTombstoneInput input) async {
    return mutationResult;
  }

  @override
  Future<Result<AuditChainVerificationSummaryEntity>> verifyChain(
    AuditVerifyChainInput input,
  ) async {
    return verifyChainResult;
  }
}

AuditEventEntity _buildEvent(String id, String? tenantId) {
  return AuditEventEntity(
    id: id,
    rowVersion: 1,
    tenantId: tenantId,
    actorId: null,
    entitySet: 'Users',
    entity: 'User',
    entityId: 'u-1',
    operation: 'action',
    actionName: 'update',
    occurredAt: DateTime.utc(2026, 1, 1),
    outcome: 'success',
    requestId: null,
    correlationId: null,
    sourcePlugin: 'acp',
    changedFields: const <String>['Name'],
    beforeSnapshot: const <String, dynamic>{'Name': 'Old'},
    afterSnapshot: const <String, dynamic>{'Name': 'New'},
    meta: const <String, dynamic>{'ip': '127.0.0.1'},
    scopeKey: 'scope-key',
    scopeSeq: 1,
    prevEntryHash: null,
    entryHash: 'hash',
    hashAlg: 'hmac-sha256',
    hashKeyId: null,
    beforeSnapshotHash: null,
    afterSnapshotHash: null,
    sealedAt: DateTime.utc(2026, 1, 1),
    retentionUntil: null,
    redactionDueAt: null,
    redactedAt: null,
    redactionReason: null,
    legalHoldAt: null,
    legalHoldUntil: null,
    legalHoldByUserId: null,
    legalHoldReason: null,
    legalHoldReleasedAt: null,
    legalHoldReleasedByUserId: null,
    legalHoldReleaseReason: null,
    tombstonedAt: null,
    tombstonedByUserId: null,
    tombstoneReason: null,
    purgeDueAt: null,
  );
}
