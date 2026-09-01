import 'package:flutter_test/flutter_test.dart';

import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  const validateAction = AcpActionDescriptor(
    name: 'validate',
    label: 'Validate',
    target: AcpActionTarget.collection,
  );
  const routeAction = AcpActionDescriptor(
    name: 'route',
    label: 'Route',
    target: AcpActionTarget.entity,
    includeRowVersion: true,
  );
  const descriptors = <AcpResourceDescriptor>[
    AcpResourceDescriptor(
      key: 'schemas',
      title: 'Schemas',
      entitySet: 'Schemas',
      scopeMode: AcpScopeMode.optional,
      columns: <AcpColumnDescriptor>[],
      collectionActions: <AcpActionDescriptor>[validateAction],
      entityActions: <AcpActionDescriptor>[routeAction],
    ),
    AcpResourceDescriptor(
      key: 'system-flags',
      title: 'System Flags',
      entitySet: 'SystemFlags',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[],
    ),
    AcpResourceDescriptor(
      key: 'context-profiles',
      title: 'Context Profiles',
      entitySet: 'ContextProfiles',
      scopeMode: AcpScopeMode.required,
      columns: <AcpColumnDescriptor>[],
    ),
  ];

  test('non-tenant descriptors load without fetching tenants', () async {
    final repository = _FakeAcpAdminRepository();
    final controller = AcpAdminController(
      repository: repository,
      descriptors: <AcpResourceDescriptor>[descriptors[1]],
      onSessionExpired: () {},
    );

    expect(controller.hasTenantScopedResources, isFalse);

    await controller.loadInitialData();

    expect(repository.fetchTenantsCalls, 0);
    expect(repository.activeListCalls.single.entitySet, 'SystemFlags');
    expect(repository.activeListCalls.single.enrichReferences, isTrue);
    expect(repository.countListCalls.single.entitySet, 'SystemFlags');
    expect(repository.countListCalls.single.enrichReferences, isFalse);
    expect(controller.resourceStateFor('system-flags').tabCount, 40);
    expect(controller.activeDescriptor.entitySet, 'SystemFlags');
    expect(controller.usesTenantScope(controller.activeDescriptor), isFalse);
  });

  test(
    'loadInitialData prefers global tenant and preserves prior selection',
    () async {
      final repository = _FakeAcpAdminRepository();
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );

      expect(controller.state.selectedTenant, isNull);

      await controller.loadInitialData();

      expect(controller.state.selectedTenantId, 'global-id');
      expect(controller.state.selectedTenant?.id, 'global-id');
      expect(controller.resourceStateFor('schemas').rows, isNotEmpty);
      expect(controller.descriptorForKey('schemas').entitySet, 'Schemas');
      expect(repository.activeListCalls.last.tenantId, isNull);
      expect(controller.resourceStateFor('schemas').tabCount, 40);
      expect(controller.resourceStateFor('system-flags').tabCount, 40);
      expect(controller.resourceStateFor('context-profiles').tabCount, 40);
      expect(controller.usesTenantScope(descriptors.first), isFalse);

      await controller.selectTenant('tenant-1');
      expect(controller.state.selectedTenantId, 'tenant-1');
      expect(repository.activeListCalls, hasLength(1));

      await controller.setOptionalScopeSelection(
        AcpOptionalScopeSelection.tenant,
      );
      expect(controller.usesTenantScope(descriptors.first), isTrue);
      expect(repository.activeListCalls.last.tenantId, 'tenant-1');

      final refreshBaseline = repository.activeListCalls.length;
      await controller.refresh();
      expect(repository.activeListCalls.length, refreshBaseline + 1);

      await controller.loadInitialData();
      expect(controller.state.selectedTenantId, 'tenant-1');
    },
  );

  test(
    'refresh bootstraps tenant state and required resources enforce selection',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..fetchTenantsResult = const Result<List<AcpTenantOption>>.success(
          <AcpTenantOption>[],
        );
      final controller = AcpAdminController(
        repository: repository,
        descriptors: <AcpResourceDescriptor>[descriptors[2]],
        onSessionExpired: () {},
      );

      await controller.loadInitialData();

      expect(controller.state.selectedTenantId, isNull);
      expect(repository.listCalls, isEmpty);
      expect(
        controller.state.errorMessage,
        'Select a tenant to view context profiles.',
      );

      await controller.refresh();
      expect(repository.fetchTenantsCalls, 2);
    },
  );

  test(
    'search, resource selection, scope changes, and paging clamp correctly',
    () async {
      final repository = _FakeAcpAdminRepository();
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );

      await controller.loadInitialData();

      await controller.selectResource('schemas');
      expect(repository.activeListCalls, hasLength(1));

      await controller.selectResource('system-flags');
      expect(repository.activeListCalls.last.entitySet, 'SystemFlags');

      await controller.selectTenant('tenant-1');
      expect(repository.activeListCalls.last.entitySet, 'SystemFlags');

      await controller.setOptionalScopeSelection(
        AcpOptionalScopeSelection.global,
      );
      expect(repository.activeListCalls.last.entitySet, 'SystemFlags');

      await controller.selectResource('context-profiles');
      expect(repository.activeListCalls.last.entitySet, 'ContextProfiles');
      expect(repository.activeListCalls.last.tenantId, 'tenant-1');
      expect(controller.usesTenantScope(descriptors[2]), isTrue);

      final selectTenantReloads = repository.activeListCalls.length;
      await controller.selectTenant('global-id');
      expect(repository.activeListCalls.length, selectTenantReloads + 1);
      expect(repository.activeListCalls.last.tenantId, 'global-id');

      controller.setSearchTerm('profile');
      expect(controller.state.activeResourceState.searchTerm, 'profile');
      expect(controller.state.activeResourceState.page, 1);

      await controller.setPage(99);
      expect(controller.state.activeResourceState.page, 3);
      expect(repository.activeListCalls.last.searchTerm, 'profile');

      await controller.setPage(0);
      expect(controller.state.activeResourceState.page, 1);

      await controller.setRowsPerPage(25);
      expect(controller.state.activeResourceState.pageSize, 25);
      expect(controller.state.activeResourceState.page, 1);
    },
  );

  test('exact filters and optional API surfaces are guarded', () async {
    const filterable = AcpResourceDescriptor(
      key: 'filterable',
      title: 'Filterable',
      entitySet: 'FilterableRows',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[],
      filters: <AcpFilterDescriptor>[
        AcpFilterDescriptor(
          key: 'OwnerId',
          label: 'Owner',
          literalType: AcpFilterLiteralType.guid,
        ),
        AcpFilterDescriptor(key: 'Status', label: 'Status'),
      ],
    );
    const optional = AcpResourceDescriptor(
      key: 'optional',
      title: 'Optional',
      entitySet: 'OptionalRows',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[],
      optionalApiSurface: true,
    );
    final repository = _FakeAcpAdminRepository();
    final controller = AcpAdminController(
      repository: repository,
      descriptors: const <AcpResourceDescriptor>[filterable, optional],
      onSessionExpired: () {},
    );
    addTearDown(controller.dispose);
    expect(controller.resourceStateFor('optional').isAvailable, isFalse);

    await controller.loadInitialData();
    expect(controller.resourceStateFor('optional').isAvailable, isTrue);
    controller.setFilterValue('missing', 'ignored');
    controller.setFilterValue('OwnerId', ' owner-id ');
    controller.setFilterValue('Status', "reviewer's");
    await controller.loadActiveResource();
    expect(repository.activeListCalls.last.extraFilters, <String>[
      "OwnerId eq guid'owner-id'",
      "Status eq 'reviewer''s'",
    ]);
    controller.setFilterValue('Status', '');
    expect(controller.state.activeResourceState.filterValues, <String, String>{
      'OwnerId': 'owner-id',
    });
    await controller.refreshResource('missing');

    repository.listRowsResult = const Result<AcpRowPage>.failure(
      ApiFailure(404, 'missing'),
    );
    await controller.refreshResourceCounts();
    expect(controller.resourceStateFor('optional').isAvailable, isFalse);
    await controller.selectResource('optional');
    expect(controller.state.activeResourceKey, 'filterable');
  });

  test(
    'soft-delete views reload supported resources and reject others',
    () async {
      const lifecycleDescriptor = AcpResourceDescriptor(
        key: 'products',
        title: 'Products',
        entitySet: 'Products',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[],
        deletedViews: <AcpDeletedView>[
          AcpDeletedView.active,
          AcpDeletedView.all,
          AcpDeletedView.archived,
        ],
      );
      final repository = _FakeAcpAdminRepository();
      final controller = AcpAdminController(
        repository: repository,
        descriptors: const <AcpResourceDescriptor>[lifecycleDescriptor],
        onSessionExpired: () {},
      );
      addTearDown(controller.dispose);
      await controller.loadInitialData();

      await controller.setDeletedView(AcpDeletedView.archived);
      expect(
        controller.state.activeResourceState.deletedView,
        AcpDeletedView.archived,
      );
      expect(
        repository.activeListCalls.last.deletedView,
        AcpDeletedView.archived,
      );
      final baseline = repository.activeListCalls.length;
      await controller.setDeletedView(AcpDeletedView.archived);
      await controller.setDeletedView(AcpDeletedView.all);
      expect(repository.activeListCalls.length, baseline + 1);

      final unsupported = AcpAdminController(
        repository: repository,
        descriptors: <AcpResourceDescriptor>[descriptors[1]],
        onSessionExpired: () {},
      );
      addTearDown(unsupported.dispose);
      await unsupported.setDeletedView(AcpDeletedView.archived);
      expect(
        unsupported.state.activeResourceState.deletedView,
        AcpDeletedView.active,
      );
    },
  );

  test(
    'tenant switches clear tenant rows before the replacement load',
    () async {
      final repository = _FakeAcpAdminRepository();
      final controller = AcpAdminController(
        repository: repository,
        descriptors: <AcpResourceDescriptor>[descriptors[2]],
        onSessionExpired: () {},
      );
      addTearDown(controller.dispose);
      await controller.loadInitialData();
      expect(controller.state.activeResourceState.rows, isNotEmpty);

      final switching = controller.selectTenant('tenant-1');
      expect(controller.state.activeResourceState.rows, isEmpty);
      expect(controller.state.activeResourceState.total, 0);
      await switching;
      expect(
        controller.state.activeResourceState.rows.single['TenantId'],
        'tenant-1',
      );
    },
  );

  test('reference warnings load and clear across tenant switches', () async {
    final repository = _FakeAcpAdminRepository()
      ..listRowsResult = const Result<AcpRowPage>.success(
        AcpRowPage(
          items: <AcpRow>[],
          total: 1,
          page: 1,
          pageSize: 15,
          referenceWarning:
              'Some reference labels could not be resolved: Account.',
        ),
      );
    final controller = AcpAdminController(
      repository: repository,
      descriptors: <AcpResourceDescriptor>[descriptors[2]],
      onSessionExpired: () {},
    );
    addTearDown(controller.dispose);

    await controller.loadInitialData();
    expect(
      controller.state.activeResourceState.referenceWarning,
      contains('Account'),
    );

    repository.listRowsResult = const Result<AcpRowPage>.success(
      AcpRowPage(items: <AcpRow>[], total: 1, page: 1, pageSize: 15),
    );
    final switching = controller.selectTenant('tenant-1');
    expect(controller.state.activeResourceState.rows, isEmpty);
    expect(controller.state.activeResourceState.referenceWarning, isNull);
    await switching;
    expect(controller.state.activeResourceState.referenceWarning, isNull);
  });

  test('successful mutations refresh declared related resources', () async {
    const first = AcpResourceDescriptor(
      key: 'first',
      title: 'First',
      entitySet: 'FirstRows',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[],
      allowCreate: true,
      refreshResourceKeys: <String>['second', 'missing', 'first', 'second'],
    );
    const second = AcpResourceDescriptor(
      key: 'second',
      title: 'Second',
      entitySet: 'SecondRows',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[],
    );
    final repository = _FakeAcpAdminRepository();
    final controller = AcpAdminController(
      repository: repository,
      descriptors: const <AcpResourceDescriptor>[first, second],
      onSessionExpired: () {},
    );
    addTearDown(controller.dispose);
    await controller.loadInitialData();
    final secondBaseline = repository.activeListCalls
        .where((call) => call.entitySet == 'SecondRows')
        .length;

    await controller.createRow(const <String, Object?>{'Code': 'one'});

    expect(
      repository.activeListCalls
          .where((call) => call.entitySet == 'SecondRows')
          .length,
      secondBaseline + 1,
    );
  });

  test(
    'successful mutations refresh the active resource and pass row metadata',
    () async {
      final repository = _FakeAcpAdminRepository();
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );

      await controller.loadInitialData();
      await controller.setOptionalScopeSelection(
        AcpOptionalScopeSelection.tenant,
      );
      final baselineListCalls = repository.activeListCalls.length;

      final createResult = await controller.createRow(const <String, dynamic>{
        'Key': 'schema-a',
      });
      expect(createResult.isSuccess, isTrue);
      expect(repository.createCalls.single.tenantId, 'global-id');

      final updateResult = await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Title': 'Updated'},
        rowVersion: 7,
      );
      expect(updateResult.isSuccess, isTrue);
      expect(repository.updateCalls.single.rowId, 'row-1');
      expect(repository.updateCalls.single.rowVersion, 7);

      final deleteResult = await controller.deleteRow(
        rowId: 'row-1',
        rowVersion: 7,
      );
      expect(deleteResult.isSuccess, isTrue);
      expect(repository.deleteCalls.single.tenantId, 'global-id');

      final restoreResult = await controller.restoreRow(
        rowId: 'row-1',
        rowVersion: 7,
      );
      expect(restoreResult.isSuccess, isTrue);
      expect(repository.restoreCalls.single.rowVersion, 7);

      final collectionResult = await controller.runCollectionAction(
        action: validateAction,
        values: const <String, dynamic>{'Payload': <String, dynamic>{}},
      );
      expect(collectionResult.isSuccess, isTrue);
      expect(repository.collectionActionCalls.single.action.name, 'validate');

      final entityResult = await controller.runEntityAction(
        action: routeAction,
        rowId: 'row-1',
        values: const <String, dynamic>{'RouteKey': 'default'},
        rowVersion: 7,
      );
      expect(entityResult.isSuccess, isTrue);
      expect(repository.entityActionCalls.single.action.name, 'route');
      expect(repository.entityActionCalls.single.rowVersion, 7);

      expect(repository.activeListCalls.length, baselineListCalls + 4);
      expect(repository.fetchRowCalls, 2);
      expect(controller.state.isMutating, isFalse);
      expect(controller.state.errorMessage, isNull);
    },
  );

  test(
    'mutation failures reload conflicts, invoke session refresh, and use fallback errors',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..updateResult = const Result<Object?>.failure(
          ApiFailure(409, 'Conflict'),
        )
        ..collectionActionResult = const Result<Object?>.failure(
          SessionExpiredFailure(),
        )
        ..deleteResult = const Result<void>.failure(UnauthorizedFailure())
        ..createResult = const Result<Object?>.failure(UnexpectedFailure(''));
      var refreshCount = 0;
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {
          refreshCount += 1;
        },
      );

      await controller.loadInitialData();
      final baselineListCalls = repository.activeListCalls.length;

      final updateResult = await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Title': 'Conflict'},
        rowVersion: 3,
      );
      expect(updateResult.isFailure, isTrue);
      expect(repository.activeListCalls.length, baselineListCalls);
      expect(repository.fetchRowCalls, 1);
      expect(
        controller.state.errorMessage,
        'Schemas changed on the server. Reloading list.',
      );

      final actionResult = await controller.runCollectionAction(
        action: validateAction,
        values: const <String, dynamic>{},
      );
      expect(actionResult.isFailure, isTrue);
      expect(refreshCount, 1);
      expect(controller.state.errorMessage, 'Session expired.');

      final deleteResult = await controller.deleteRow(rowId: 'row-1');
      expect(deleteResult.isFailure, isTrue);
      expect(refreshCount, 2);
      expect(controller.state.errorMessage, 'Unauthorized request.');

      final createResult = await controller.createRow(
        const <String, dynamic>{},
      );
      expect(createResult.isFailure, isTrue);
      expect(controller.state.errorMessage, 'Could not create schemas.');
    },
  );

  test(
    'create refreshes returned rows and falls back when no ID is returned',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..createResult = const Result<Object?>.success(<String, Object?>{
          'Id': 'created-id',
          'RowVersion': 4,
        });
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );
      await controller.loadInitialData();

      final result = await controller.createRow(const <String, dynamic>{
        'Key': 'workflow',
      });

      expect(result.isSuccess, isTrue);
      expect(repository.createCalls.single.values, <String, dynamic>{
        'Key': 'workflow',
      });
      expect(repository.updateCalls, isEmpty);
      expect(controller.rowById('created-id')?.rowVersion, 1);

      repository.createResult = const Result<Object?>.success(null);
      final missingId = await controller.createRow(const <String, dynamic>{
        'Key': 'second',
      });
      expect(missingId.isSuccess, isTrue);
    },
  );

  test(
    'deferred create preserves response metadata and explicitly refreshes rows',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..createResult = const Result<Object?>.success(<String, Object?>{
          'Id': 'created-id',
          'RowVersion': 4,
        })
        ..fetchRowValue = const <String, Object?>{'RowVersion': 8};
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );
      await controller.loadInitialData();

      final createResult = await controller.createRow(const <String, dynamic>{
        'Key': 'workflow',
      }, deferRefresh: true);

      expect(createResult.data, <String, Object?>{
        'Id': 'created-id',
        'RowVersion': 4,
      });
      expect(repository.fetchRowCalls, 0);
      expect(controller.rowById('created-id'), isNull);
      expect(controller.state.isMutating, isFalse);

      final refreshResult = await controller.fetchRowForMutation('created-id');
      expect(refreshResult.isSuccess, isTrue);
      expect(controller.rowById('created-id')?.rowVersion, 8);

      repository.fetchRowValue = const <String, Object?>{'Id': null};
      final unidentifiedRefresh = await controller.fetchRowForMutation(
        'unidentified-id',
      );
      expect(unidentifiedRefresh.isSuccess, isTrue);
      expect(controller.rowById('unidentified-id'), isNull);

      repository.fetchRowFailure = const ApiFailure(
        503,
        'Created row unavailable.',
      );
      final failedRefresh = await controller.fetchRowForMutation('other-id');
      expect(failedRefresh.isFailure, isTrue);
      expect(controller.errorMessage, 'Created row unavailable.');
    },
  );

  test(
    'reference labels remain hydrated after create, edit, and actions',
    () async {
      const referenceDescriptor = AcpResourceDescriptor(
        key: 'subscriptions',
        title: 'Subscriptions',
        entitySet: 'Subscriptions',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[
          AcpColumnDescriptor(
            key: 'AccountId',
            label: 'Account',
            reference: AcpColumnReferenceDescriptor(
              navigationPath: 'Account',
              titleFields: <AcpReferenceFieldDescriptor>[
                AcpReferenceFieldDescriptor('DisplayName'),
              ],
            ),
          ),
        ],
        entityActions: <AcpActionDescriptor>[routeAction],
      );
      final repository = _FakeAcpAdminRepository()
        ..createResult = const Result<Object?>.success(<String, Object?>{
          'Id': 'subscription-1',
        })
        ..fetchRowValue = const <String, Object?>{
          'AccountId': 'account-1',
          'Account': <String, Object?>{'DisplayName': 'Example Company'},
        };
      final controller = AcpAdminController(
        repository: repository,
        descriptors: const <AcpResourceDescriptor>[referenceDescriptor],
        onSessionExpired: () {},
      );
      addTearDown(controller.dispose);
      await controller.loadInitialData();

      await controller.createRow(const <String, dynamic>{
        'AccountId': 'account-1',
      });
      expect(
        controller.rowById('subscription-1')?['Account'],
        <String, Object?>{'DisplayName': 'Example Company'},
      );

      await controller.updateRow(
        rowId: 'subscription-1',
        values: const <String, dynamic>{'AccountId': 'account-1'},
        rowVersion: 1,
      );
      expect(
        controller.rowById('subscription-1')?['Account'],
        <String, Object?>{'DisplayName': 'Example Company'},
      );

      await controller.runEntityAction(
        action: routeAction,
        rowId: 'subscription-1',
        values: const <String, dynamic>{'RouteKey': 'default'},
        rowVersion: 1,
      );
      expect(
        controller.rowById('subscription-1')?['Account'],
        <String, Object?>{'DisplayName': 'Example Company'},
      );
      expect(repository.fetchRowCalls, 3);
      expect(repository.createCalls.single.values, <String, Object?>{
        'AccountId': 'account-1',
      });
      expect(repository.updateCalls.single.values, <String, Object?>{
        'AccountId': 'account-1',
      });
    },
  );

  test(
    'failed exact conflict refresh falls back to the resource list',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..updateResult = const Result<Object?>.failure(
          ConflictFailure(ConflictKind.staleRowVersion, 'Stale row version.'),
        )
        ..fetchRowFailure = const ApiFailure(500, 'Refresh failed.');
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );
      await controller.loadInitialData();
      final baselineListCalls = repository.activeListCalls.length;

      final result = await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Title': 'Stale'},
        rowVersion: 1,
      );

      expect(result.isFailure, isTrue);
      expect(repository.fetchRowCalls, 1);
      expect(repository.activeListCalls.length, baselineListCalls + 1);
    },
  );

  test(
    'conflicts distinguish stale row versions from lifecycle rules',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..updateResult = const Result<Object?>.failure(
          ConflictFailure(
            ConflictKind.staleRowVersion,
            'RowVersion conflict. Refresh and retry.',
          ),
        );
      final controller = AcpAdminController(
        repository: repository,
        descriptors: descriptors,
        onSessionExpired: () {},
      );
      await controller.loadInitialData();

      await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Name': 'retained'},
        rowVersion: 2,
      );
      expect(controller.errorMessage, startsWith('Stale RowVersion.'));
      expect(controller.rowById('row-1')?.rowVersion, 1);

      repository.updateResult = const Result<Object?>.failure(
        ConflictFailure(
          ConflictKind.lifecycle,
          'Invoice can only be issued from draft.',
        ),
      );
      await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Name': 'still retained'},
        rowVersion: 1,
      );
      expect(
        controller.errorMessage,
        'Conflict. Invoice can only be issued from draft.',
      );
    },
  );

  test(
    'tenant bootstrap failures still fall back to loading the active resource',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..fetchTenantsResult = const Result<List<AcpTenantOption>>.failure(
          UnexpectedFailure('tenants failed'),
        );
      final controller = AcpAdminController(
        repository: repository,
        descriptors: <AcpResourceDescriptor>[descriptors.first],
        onSessionExpired: () {},
      );

      await controller.loadInitialData();

      expect(repository.fetchTenantsCalls, 1);
      expect(repository.listCalls, hasLength(1));
      expect(repository.listCalls.single.entitySet, 'Schemas');
      expect(controller.state.selectedTenantId, isNull);
    },
  );

  test(
    'load failures surface an error and tenant selection falls back to first tenant',
    () async {
      final repository = _FakeAcpAdminRepository()
        ..fetchTenantsResult =
            const Result<List<AcpTenantOption>>.success(<AcpTenantOption>[
              AcpTenantOption(
                id: 'tenant-1',
                name: 'Tenant One',
                slug: 'tenant-one',
              ),
              AcpTenantOption(
                id: 'tenant-2',
                name: 'Tenant Two',
                slug: 'tenant-two',
              ),
            ])
        ..listRowsResult = const Result<AcpRowPage>.failure(
          UnexpectedFailure('load failed'),
        );
      final controller = AcpAdminController(
        repository: repository,
        descriptors: <AcpResourceDescriptor>[descriptors.first],
        onSessionExpired: () {},
      );

      await controller.loadInitialData();

      expect(controller.state.selectedTenantId, 'tenant-1');
      expect(controller.state.errorMessage, 'load failed');
      expect(controller.state.activeResourceState.isLoading, isFalse);
    },
  );
}

class _ListCall {
  const _ListCall({
    required this.entitySet,
    required this.tenantId,
    required this.page,
    required this.pageSize,
    required this.searchTerm,
    required this.deletedView,
    required this.enrichReferences,
    required this.extraFilters,
  });

  final String entitySet;
  final String? tenantId;
  final int page;
  final int pageSize;
  final String? searchTerm;
  final AcpDeletedView deletedView;
  final bool enrichReferences;
  final List<String> extraFilters;
}

class _CreateCall {
  const _CreateCall({required this.tenantId, required this.values});

  final String? tenantId;
  final Map<String, dynamic> values;
}

class _UpdateCall {
  const _UpdateCall({
    required this.rowId,
    required this.values,
    required this.tenantId,
    required this.rowVersion,
  });

  final String rowId;
  final Map<String, dynamic> values;
  final String? tenantId;
  final int? rowVersion;
}

class _DeleteCall {
  const _DeleteCall({
    required this.rowId,
    required this.tenantId,
    required this.rowVersion,
  });

  final String rowId;
  final String? tenantId;
  final int? rowVersion;
}

class _RestoreCall {
  const _RestoreCall({
    required this.rowId,
    required this.tenantId,
    required this.rowVersion,
  });

  final String rowId;
  final String? tenantId;
  final int? rowVersion;
}

class _CollectionActionCall {
  const _CollectionActionCall({
    required this.action,
    required this.values,
    required this.tenantId,
  });

  final AcpActionDescriptor action;
  final Map<String, dynamic> values;
  final String? tenantId;
}

class _EntityActionCall {
  const _EntityActionCall({
    required this.action,
    required this.rowId,
    required this.values,
    required this.tenantId,
    required this.rowVersion,
  });

  final AcpActionDescriptor action;
  final String rowId;
  final Map<String, dynamic> values;
  final String? tenantId;
  final int? rowVersion;
}

class _FakeAcpAdminRepository implements AcpAdminRepository {
  Result<List<AcpTenantOption>> fetchTenantsResult =
      const Result<List<AcpTenantOption>>.success(<AcpTenantOption>[
        AcpTenantOption(id: 'tenant-1', name: 'Tenant One', slug: 'tenant-one'),
        AcpTenantOption(id: 'global-id', name: 'Global', slug: 'global'),
      ]);

  Result<AcpRowPage> listRowsResult = Result<AcpRowPage>.success(
    const AcpRowPage(
      items: <AcpRow>[
        <String, Object?>{'Id': 'row-1', 'RowVersion': 1},
      ],
      total: 40,
      page: 1,
      pageSize: 15,
    ),
  );

  Result<Object?> createResult = const Result<Object?>.success(
    <String, Object?>{'status': 'created'},
  );
  Result<Object?> updateResult = const Result<Object?>.success(
    <String, Object?>{'status': 'updated'},
  );
  Result<void> deleteResult = const Result<void>.success(null);
  Result<void> restoreResult = const Result<void>.success(null);
  Result<Object?> collectionActionResult = const Result<Object?>.success(
    <String, Object?>{'status': 'ok'},
  );
  Result<Object?> entityActionResult = const Result<Object?>.success(
    <String, Object?>{'status': 'ok'},
  );
  Failure? fetchRowFailure;
  AcpRow? fetchRowValue;

  int fetchTenantsCalls = 0;
  int fetchRowCalls = 0;
  final List<_ListCall> listCalls = <_ListCall>[];
  final List<_CreateCall> createCalls = <_CreateCall>[];
  final List<_UpdateCall> updateCalls = <_UpdateCall>[];
  final List<_DeleteCall> deleteCalls = <_DeleteCall>[];
  final List<_RestoreCall> restoreCalls = <_RestoreCall>[];
  final List<_CollectionActionCall> collectionActionCalls =
      <_CollectionActionCall>[];
  final List<_EntityActionCall> entityActionCalls = <_EntityActionCall>[];

  List<_ListCall> get activeListCalls {
    return listCalls
        .where((call) => call.pageSize != 1 || call.searchTerm != null)
        .toList(growable: false);
  }

  List<_ListCall> get countListCalls {
    return listCalls
        .where((call) => call.pageSize == 1 && call.searchTerm == null)
        .toList(growable: false);
  }

  @override
  Future<Result<List<AcpTenantOption>>> fetchTenants({int top = 200}) async {
    fetchTenantsCalls += 1;
    return fetchTenantsResult;
  }

  @override
  Future<Result<AcpRowPage>> listRows({
    required AcpResourceDescriptor descriptor,
    required PageRequest pageRequest,
    String? tenantId,
    String? searchTerm,
    List<String> extraFilters = const <String>[],
    AcpDeletedView deletedView = AcpDeletedView.active,
    bool enrichReferences = true,
  }) async {
    listCalls.add(
      _ListCall(
        entitySet: descriptor.entitySet,
        tenantId: tenantId,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        searchTerm: searchTerm,
        deletedView: deletedView,
        enrichReferences: enrichReferences,
        extraFilters: extraFilters,
      ),
    );

    if (listRowsResult.isFailure) {
      return Result<AcpRowPage>.failure(listRowsResult.failure!);
    }

    return Result<AcpRowPage>.success(
      AcpRowPage(
        items: <AcpRow>[
          <String, Object?>{
            'Id': '${descriptor.entitySet}-${pageRequest.page}',
            'TenantId': tenantId,
            'RowVersion': 1,
          },
        ],
        total: listRowsResult.data!.total,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        referenceWarning: listRowsResult.data!.referenceWarning,
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    fetchRowCalls += 1;
    if (fetchRowFailure case final failure?) {
      return Result<AcpRow>.failure(failure);
    }
    return Result<AcpRow>.success(<String, Object?>{
      'Id': rowId,
      'TenantId': tenantId,
      'RowVersion': 1,
      ...?fetchRowValue,
    });
  }

  @override
  Future<Result<Object?>> createRow({
    required AcpResourceDescriptor descriptor,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    createCalls.add(_CreateCall(tenantId: tenantId, values: values));
    return createResult;
  }

  @override
  Future<Result<void>> deleteRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    deleteCalls.add(
      _DeleteCall(rowId: rowId, tenantId: tenantId, rowVersion: rowVersion),
    );
    return deleteResult;
  }

  @override
  Future<Result<void>> restoreRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
    int? rowVersion,
  }) async {
    restoreCalls.add(
      _RestoreCall(rowId: rowId, tenantId: tenantId, rowVersion: rowVersion),
    );
    return restoreResult;
  }

  @override
  Future<Result<Object?>> runCollectionAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantId,
  }) async {
    collectionActionCalls.add(
      _CollectionActionCall(action: action, values: values, tenantId: tenantId),
    );
    return collectionActionResult;
  }

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpResourceDescriptor descriptor,
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    entityActionCalls.add(
      _EntityActionCall(
        action: action,
        rowId: rowId,
        values: values,
        tenantId: tenantId,
        rowVersion: rowVersion,
      ),
    );
    return entityActionResult;
  }

  @override
  Future<Result<Object?>> updateRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantId,
    int? rowVersion,
  }) async {
    updateCalls.add(
      _UpdateCall(
        rowId: rowId,
        values: values,
        tenantId: tenantId,
        rowVersion: rowVersion,
      ),
    );
    return updateResult;
  }
}
