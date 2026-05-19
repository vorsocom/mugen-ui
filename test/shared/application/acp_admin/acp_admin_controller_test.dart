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
    expect(repository.listCalls.single.entitySet, 'SystemFlags');
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
      expect(repository.listCalls.last.tenantId, isNull);
      expect(controller.usesTenantScope(descriptors.first), isFalse);

      await controller.selectTenant('tenant-1');
      expect(controller.state.selectedTenantId, 'tenant-1');
      expect(repository.listCalls, hasLength(1));

      await controller.setOptionalScopeSelection(
        AcpOptionalScopeSelection.tenant,
      );
      expect(controller.usesTenantScope(descriptors.first), isTrue);
      expect(repository.listCalls.last.tenantId, 'tenant-1');

      final refreshBaseline = repository.listCalls.length;
      await controller.refresh();
      expect(repository.listCalls.length, refreshBaseline + 1);

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
      expect(repository.listCalls, hasLength(1));

      await controller.selectResource('system-flags');
      expect(repository.listCalls.last.entitySet, 'SystemFlags');

      await controller.selectTenant('tenant-1');
      expect(repository.listCalls.last.entitySet, 'SystemFlags');

      await controller.setOptionalScopeSelection(
        AcpOptionalScopeSelection.global,
      );
      expect(repository.listCalls.last.entitySet, 'SystemFlags');

      await controller.selectResource('context-profiles');
      expect(repository.listCalls.last.entitySet, 'ContextProfiles');
      expect(repository.listCalls.last.tenantId, 'tenant-1');
      expect(controller.usesTenantScope(descriptors[2]), isTrue);

      final selectTenantReloads = repository.listCalls.length;
      await controller.selectTenant('global-id');
      expect(repository.listCalls.length, selectTenantReloads + 1);
      expect(repository.listCalls.last.tenantId, 'global-id');

      controller.setSearchTerm('profile');
      expect(controller.state.activeResourceState.searchTerm, 'profile');
      expect(controller.state.activeResourceState.page, 1);

      await controller.setPage(99);
      expect(controller.state.activeResourceState.page, 3);
      expect(repository.listCalls.last.searchTerm, 'profile');

      await controller.setPage(0);
      expect(controller.state.activeResourceState.page, 1);

      await controller.setRowsPerPage(25);
      expect(controller.state.activeResourceState.pageSize, 25);
      expect(controller.state.activeResourceState.page, 1);
    },
  );

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
      final baselineListCalls = repository.listCalls.length;

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

      expect(repository.listCalls.length, baselineListCalls + 6);
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
      final baselineListCalls = repository.listCalls.length;

      final updateResult = await controller.updateRow(
        rowId: 'row-1',
        values: const <String, dynamic>{'Title': 'Conflict'},
        rowVersion: 3,
      );
      expect(updateResult.isFailure, isTrue);
      expect(repository.listCalls.length, baselineListCalls + 1);
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
  });

  final String entitySet;
  final String? tenantId;
  final int page;
  final int pageSize;
  final String? searchTerm;
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

  int fetchTenantsCalls = 0;
  final List<_ListCall> listCalls = <_ListCall>[];
  final List<_CreateCall> createCalls = <_CreateCall>[];
  final List<_UpdateCall> updateCalls = <_UpdateCall>[];
  final List<_DeleteCall> deleteCalls = <_DeleteCall>[];
  final List<_RestoreCall> restoreCalls = <_RestoreCall>[];
  final List<_CollectionActionCall> collectionActionCalls =
      <_CollectionActionCall>[];
  final List<_EntityActionCall> entityActionCalls = <_EntityActionCall>[];

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
  }) async {
    listCalls.add(
      _ListCall(
        entitySet: descriptor.entitySet,
        tenantId: tenantId,
        page: pageRequest.page,
        pageSize: pageRequest.pageSize,
        searchTerm: searchTerm,
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
      ),
    );
  }

  @override
  Future<Result<AcpRow>> fetchRow({
    required AcpResourceDescriptor descriptor,
    required String rowId,
    String? tenantId,
  }) async {
    return Result<AcpRow>.success(<String, Object?>{
      'Id': rowId,
      'TenantId': tenantId,
      'RowVersion': 1,
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
