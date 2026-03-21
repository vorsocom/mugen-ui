import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_chain_verification_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_lifecycle_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_seal_backlog_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/repositories/audit_admin_repository.dart';
import 'package:mugen_ui/features/audit_admin/presentation/providers/audit_admin_providers.dart';
import 'package:mugen_ui/features/audit_admin/presentation/widgets/audit_management_panel.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('AuditManagementPanel renders table and detail state', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuditAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('audit-management-scope-selector')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('audit-management-search-field')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('audit-management-run-lifecycle-button')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('audit-event-row-global-1')), findsOneWidget);
    expect(find.textContaining('Event global-1'), findsOneWidget);

    await tester.tap(find.byTooltip('Next page'));
    await tester.pumpAndSettle();
    expect(repository.lastQuery?.pageRequest.page, 2);

    await tester.enterText(
      find.byKey(const Key('audit-management-search-field')),
      'users',
    );
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(repository.lastQuery?.searchTerm, 'users');
  });

  testWidgets('run lifecycle requires explicit guardrail confirmations', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuditAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('audit-management-run-lifecycle-button')),
    );
    await tester.pumpAndSettle();

    final dryRunFinder = find.byKey(
      const Key('audit-run-lifecycle-dry-run-switch'),
    );
    expect(dryRunFinder, findsOneWidget);

    await tester.tap(dryRunFinder);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('audit-run-lifecycle-mutation-warning')),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Run'));
    await tester.pumpAndSettle();

    expect(find.text('Mutation Warning'), findsOneWidget);
    await tester.tap(
      find.byKey(const Key('audit-run-lifecycle-mutation-warning-confirm')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Confirmation Required'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(repository.runLifecycleInputs, hasLength(1));
    expect(repository.runLifecycleInputs.single.dryRun, isFalse);
  });

  testWidgets('row action sends reason and row version after confirmation', (
    WidgetTester tester,
  ) async {
    final repository = _FakeAuditAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    final placeHoldButton = find.byTooltip('Place legal hold').first;
    await tester.tap(placeHoldButton);
    await tester.pumpAndSettle();

    final formFields = find.descendant(
      of: find.byType(Dialog).last,
      matching: find.byType(TextFormField),
    );
    await tester.enterText(formFields.at(0), 'incident review');
    await tester.tap(find.widgetWithText(FilledButton, 'Place Hold'));
    await tester.pumpAndSettle();

    expect(find.text('Confirmation Required'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Continue'));
    await tester.pumpAndSettle();

    expect(repository.placeHoldInputs, hasLength(1));
    expect(repository.placeHoldInputs.single.reason, 'incident review');
    expect(repository.placeHoldInputs.single.rowVersion, 1);
  });
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeAuditAdminRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1800, 1300));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        auditAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
        appNavigatorProvider.overrideWith((ref) => _FakeAppNavigator()),
        snackBarDispatcherProvider.overrideWith((ref) => _RecordingSnackBars()),
      ],
      child: const MaterialApp(home: Scaffold(body: AuditManagementPanel())),
    ),
  );
}

class _TestAuthController extends AuthController {
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
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}

class _FakeAppNavigator extends AppNavigator {}

class _RecordingSnackBars extends SnackBarDispatcher {
  @override
  void show(AppNavigator navigator, String content) {}
}

class _FakeAuditAdminRepository implements AuditAdminRepository {
  _FakeAuditAdminRepository()
    : _events = List<AuditEventEntity>.generate(30, (index) {
        final id = index + 1;
        return _buildEvent(
          'global-$id',
          null,
          hasLegalHold: id.isEven,
          redacted: id % 3 == 0,
          tombstoned: id % 5 == 0,
        );
      }),
      _tenantEvents = <AuditEventEntity>[
        _buildEvent('tenant-1-e1', 'tenant-1'),
      ];

  final List<AuditEventEntity> _events;
  final List<AuditEventEntity> _tenantEvents;

  AuditEventListQuery? lastQuery;
  final List<AuditPlaceLegalHoldInput> placeHoldInputs =
      <AuditPlaceLegalHoldInput>[];
  final List<AuditRunLifecycleInput> runLifecycleInputs =
      <AuditRunLifecycleInput>[];

  @override
  Future<Result<PageResult<AuditEventEntity>>> fetchAuditEvents(
    AuditEventListQuery query,
  ) async {
    lastQuery = query;

    final source = query.scopeMode == AuditAdminScopeMode.global
        ? _events
        : _tenantEvents;

    final search = query.searchTerm?.toLowerCase().trim() ?? '';
    final filtered = search.isEmpty
        ? source
        : source
              .where(
                (event) =>
                    event.entitySet.toLowerCase().contains(search) ||
                    event.operation.toLowerCase().contains(search),
              )
              .toList(growable: false);

    final skip = query.pageRequest.skip;
    final end = math.min(skip + query.pageRequest.pageSize, filtered.length);
    final pageItems = skip >= filtered.length
        ? const <AuditEventEntity>[]
        : filtered.sublist(skip, end);

    return Result<PageResult<AuditEventEntity>>.success(
      PageResult<AuditEventEntity>(
        items: pageItems,
        total: filtered.length,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<List<AuditTenantOptionEntity>>> fetchTenants({
    int top = 200,
  }) async {
    return const Result<List<AuditTenantOptionEntity>>.success(
      <AuditTenantOptionEntity>[
        AuditTenantOptionEntity(
          id: 'tenant-1',
          name: 'Tenant One',
          slug: 'tenant-one',
          status: 'Active',
        ),
      ],
    );
  }

  @override
  Future<Result<void>> placeLegalHold(AuditPlaceLegalHoldInput input) async {
    placeHoldInputs.add(input);
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> releaseLegalHold(
    AuditReleaseLegalHoldInput input,
  ) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> redactEvent(AuditRedactInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> tombstoneEvent(AuditTombstoneInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<AuditLifecycleSummaryEntity>> runLifecycle(
    AuditRunLifecycleInput input,
  ) async {
    runLifecycleInputs.add(input);
    return const Result<AuditLifecycleSummaryEntity>.success(
      AuditLifecycleSummaryEntity(
        dryRun: false,
        now: null,
        batchSize: 100,
        maxBatches: 10,
        phases: <String, AuditLifecyclePhaseSummaryEntity>{
          'seal_backlog': AuditLifecyclePhaseSummaryEntity(
            rowsProcessed: 2,
            remainingCount: 0,
            batches: 1,
          ),
        },
        totalProcessed: 2,
      ),
    );
  }

  @override
  Future<Result<AuditChainVerificationSummaryEntity>> verifyChain(
    AuditVerifyChainInput input,
  ) async {
    return const Result<AuditChainVerificationSummaryEntity>.success(
      AuditChainVerificationSummaryEntity(
        isValid: true,
        checkedRows: 2,
        mismatchCount: 0,
        mismatches: <AuditChainMismatchEntity>[],
      ),
    );
  }

  @override
  Future<Result<AuditSealBacklogSummaryEntity>> sealBacklog(
    AuditSealBacklogInput input,
  ) async {
    return const Result<AuditSealBacklogSummaryEntity>.success(
      AuditSealBacklogSummaryEntity(
        rowsSealed: 2,
        remainingCount: 0,
        batches: 1,
        batchSize: 100,
        maxBatches: 10,
      ),
    );
  }
}

AuditEventEntity _buildEvent(
  String id,
  String? tenantId, {
  bool hasLegalHold = false,
  bool redacted = false,
  bool tombstoned = false,
}) {
  final now = DateTime.utc(2026, 2, 1);
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
    occurredAt: now,
    outcome: 'success',
    requestId: null,
    correlationId: null,
    sourcePlugin: 'acp',
    changedFields: const <String>['Name'],
    beforeSnapshot: const <String, dynamic>{'Name': 'Old'},
    afterSnapshot: const <String, dynamic>{'Name': 'New'},
    meta: const <String, dynamic>{'ip': '127.0.0.1'},
    scopeKey: tenantId == null ? 'global' : 'tenant:$tenantId',
    scopeSeq: 1,
    prevEntryHash: null,
    entryHash: 'hash',
    hashAlg: 'hmac-sha256',
    hashKeyId: null,
    beforeSnapshotHash: null,
    afterSnapshotHash: null,
    sealedAt: now,
    retentionUntil: null,
    redactionDueAt: null,
    redactedAt: redacted ? now : null,
    redactionReason: redacted ? 'policy' : null,
    legalHoldAt: hasLegalHold ? now : null,
    legalHoldUntil: hasLegalHold ? now.add(const Duration(days: 7)) : null,
    legalHoldByUserId: hasLegalHold ? 'admin-1' : null,
    legalHoldReason: hasLegalHold ? 'investigation' : null,
    legalHoldReleasedAt: null,
    legalHoldReleasedByUserId: null,
    legalHoldReleaseReason: null,
    tombstonedAt: tombstoned ? now : null,
    tombstonedByUserId: tombstoned ? 'admin-1' : null,
    tombstoneReason: tombstoned ? 'expired' : null,
    purgeDueAt: tombstoned ? now.add(const Duration(days: 30)) : null,
  );
}
