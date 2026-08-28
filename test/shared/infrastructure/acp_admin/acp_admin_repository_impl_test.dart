import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/connector_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/reporting_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/sla_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/workflow_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_reference_display.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

void main() {
  const optionalDescriptor = AcpResourceDescriptor(
    key: 'schemas',
    title: 'Schemas',
    entitySet: 'Schemas',
    scopeMode: AcpScopeMode.optional,
    columns: <AcpColumnDescriptor>[],
    searchFields: <String>['Key', 'Title'],
  );
  const requiredDescriptor = AcpResourceDescriptor(
    key: 'context-profiles',
    title: 'Context Profiles',
    entitySet: 'ContextProfiles',
    scopeMode: AcpScopeMode.required,
    columns: <AcpColumnDescriptor>[],
  );
  const collectionAction = AcpActionDescriptor(
    name: 'validate',
    label: 'Validate',
    target: AcpActionTarget.collection,
  );
  const entityAction = AcpActionDescriptor(
    name: 'route',
    label: 'Route',
    target: AcpActionTarget.entity,
    includeRowVersion: true,
  );
  const enrichedDescriptor = AcpResourceDescriptor(
    key: 'orders',
    title: 'Orders',
    entitySet: 'Orders',
    scopeMode: AcpScopeMode.required,
    columns: <AcpColumnDescriptor>[
      AcpColumnDescriptor(
        key: 'AccountId',
        label: 'Account',
        reference: AcpColumnReferenceDescriptor(
          navigationPath: 'Account',
          titleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('Name'),
          ],
        ),
      ),
      AcpColumnDescriptor(
        key: 'FromStateId',
        label: 'From',
        reference: AcpColumnReferenceDescriptor(
          navigationPath: 'Wrapper.FromState',
          titleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('Name'),
          ],
          batchLookup: AcpBatchReferenceDescriptor(
            entitySet: 'States',
            scopeMode: AcpScopeMode.required,
            selectFields: <String>['Name', 'Key'],
            deletedView: AcpDeletedView.all,
          ),
        ),
      ),
      AcpColumnDescriptor(
        key: 'ToStateId',
        label: 'To',
        reference: AcpColumnReferenceDescriptor(
          navigationPath: 'Wrapper.ToState',
          titleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('Name'),
          ],
          batchLookup: AcpBatchReferenceDescriptor(
            entitySet: 'States',
            scopeMode: AcpScopeMode.required,
            selectFields: <String>['Name', 'Key'],
            deletedView: AcpDeletedView.all,
          ),
        ),
      ),
      AcpColumnDescriptor(
        key: 'NewStateId',
        label: 'New',
        reference: AcpColumnReferenceDescriptor(
          navigationPath: 'NewWrapper.State',
          titleFields: <AcpReferenceFieldDescriptor>[
            AcpReferenceFieldDescriptor('Name'),
          ],
          batchLookup: AcpBatchReferenceDescriptor(
            entitySet: 'States',
            scopeMode: AcpScopeMode.required,
            selectFields: <String>['Name'],
            deletedView: AcpDeletedView.all,
          ),
        ),
      ),
    ],
    expansions: <AcpExpandDescriptor>[
      AcpExpandDescriptor(
        navigation: 'Account',
        selectFields: <String>['Name'],
      ),
      AcpExpandDescriptor(navigation: ' '),
    ],
  );
  final registeredResources = <AcpResourceDescriptor>[
    ...billingCatalogResources,
    ...billingOperationsResources,
    ...connectorResources,
    ...reportingResources,
    ...slaResources,
    ...workflowResources,
    ...knowledgePackAdminResources,
    ...orchestrationAdminResources,
  ];

  test('fetchTenants maps tenant payload and request query', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': 'global-id',
                'Name': 'Global',
                'Slug': 'global',
              },
              <String, Object?>{'Id': 'bad', 'Name': ''},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.fetchTenants(top: 50);

    expect(result.isSuccess, isTrue);
    expect(result.data, hasLength(1));
    expect(result.data!.single.label, 'Global (global)');
    expect(
      fixture.client.requests.single.path,
      fixture.appConfig.api.endpoints.tenant,
    );
    expect(fixture.client.requests.single.queryParameters[r'$top'], 50);
    expect(
      fixture.client.requests.single.queryParameters[r'$orderby'],
      'Name asc',
    );
  });

  test('fetchTenants handles unexpected payloads and missing lists', () async {
    final unexpectedFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
    );
    final emptyFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{'value': 'not-a-list'}),
        ),
      ],
    );

    final unexpectedResult = await unexpectedFixture.repository.fetchTenants();
    final emptyResult = await emptyFixture.repository.fetchTenants();

    expect(unexpectedResult.isFailure, isTrue);
    expect(unexpectedResult.failure, isA<UnexpectedFailure>());
    expect(emptyResult.isSuccess, isTrue);
    expect(emptyResult.data, isEmpty);
  });

  test('listRows builds optional-scope queries and maps rows/counts', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            '@count': '2',
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'row-1', 'RowVersion': '7'},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.listRows(
      descriptor: optionalDescriptor,
      pageRequest: const PageRequest(page: 2, pageSize: 5),
      searchTerm: 'schema',
      extraFilters: const <String>['IsActive eq true'],
    );

    expect(result.isSuccess, isTrue);
    expect(result.data!.total, 2);
    expect(result.data!.items.single.rowVersion, 7);

    final request = fixture.client.requests.single;
    expect(request.path, 'core/acp/v1/Schemas');
    expect(request.queryParameters[r'$skip'], 5);
    expect(request.queryParameters[r'$top'], 5);
    expect(request.queryParameters[r'$orderby'], isNull);
    expect(
      request.queryParameters[r'$filter'],
      "IsActive eq true and (contains(Key,'schema') or contains(Title,'schema'))",
    );
  });

  test(
    'listRows handles required-tenant validation and unexpected bodies',
    () async {
      final validationFixture = _RepositoryFixture();
      final unexpectedFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );
      final emptyRowsFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              '@count': 4,
              'value': 'not-a-list',
            }),
          ),
        ],
      );

      final validationResult = await validationFixture.repository.listRows(
        descriptor: requiredDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 10),
      );
      final unexpectedResult = await unexpectedFixture.repository.listRows(
        descriptor: optionalDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 10),
      );
      final emptyRowsResult = await emptyRowsFixture.repository.listRows(
        descriptor: optionalDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 10),
      );

      expect(validationResult.isFailure, isTrue);
      expect(validationResult.failure?.message, 'A tenant must be selected.');
      expect(unexpectedResult.isFailure, isTrue);
      expect(unexpectedResult.failure, isA<UnexpectedFailure>());
      expect(emptyRowsResult.isSuccess, isTrue);
      expect(emptyRowsResult.data!.total, 4);
      expect(emptyRowsResult.data!.items, isEmpty);
    },
  );

  test('fetchRow builds entity path and maps row payload', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'Id': 'row-1',
            'RowVersion': '7',
            'Name': 'Profile A',
          }),
        ),
      ],
    );

    final result = await fixture.repository.fetchRow(
      descriptor: requiredDescriptor,
      rowId: 'row-1',
      tenantId: 'tenant-1',
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?['Name'], 'Profile A');
    expect(result.data?.rowVersion, 7);

    final request = fixture.client.requests.single;
    expect(request.method, HttpMethod.get);
    expect(request.path, 'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1');
    expect(request.queryParameters, isEmpty);
  });

  test(
    'fetchRow handles required-tenant validation and unexpected bodies',
    () async {
      final validationFixture = _RepositoryFixture();
      final unexpectedFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );
      final apiFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 500, body: 'lookup failed'),
        ],
      );

      final validationResult = await validationFixture.repository.fetchRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
      );
      final unexpectedResult = await unexpectedFixture.repository.fetchRow(
        descriptor: optionalDescriptor,
        rowId: 'row-1',
      );
      final apiResult = await apiFixture.repository.fetchRow(
        descriptor: optionalDescriptor,
        rowId: 'row-1',
      );

      expect(validationResult.isFailure, isTrue);
      expect(validationResult.failure?.message, 'A tenant must be selected.');
      expect(unexpectedResult.isFailure, isTrue);
      expect(unexpectedResult.failure, isA<UnexpectedFailure>());
      expect(apiResult.isFailure, isTrue);
      expect(apiResult.failure, isA<ApiFailure>());
    },
  );

  test(
    'create, update, delete, and restore build expected paths and bodies',
    () async {
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 200, body: ''),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{'ok': true}),
          ),
          (_) => _response(statusCode: 204, body: ''),
          (_) => _response(statusCode: 204, body: ''),
        ],
      );

      final createResult = await fixture.repository.createRow(
        descriptor: requiredDescriptor,
        tenantId: 'tenant-1',
        values: const <String, dynamic>{'Name': 'Profile A'},
      );
      final updateResult = await fixture.repository.updateRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
        tenantId: 'tenant-1',
        rowVersion: 7,
        values: const <String, dynamic>{'Name': 'Updated'},
      );
      final deleteResult = await fixture.repository.deleteRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
        tenantId: 'tenant-1',
        rowVersion: 7,
      );
      final restoreResult = await fixture.repository.restoreRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
        tenantId: 'tenant-1',
        rowVersion: 7,
      );

      expect(createResult.isSuccess, isTrue);
      expect(createResult.data, isNull);
      expect(updateResult.isSuccess, isTrue);
      expect(deleteResult.isSuccess, isTrue);
      expect(restoreResult.isSuccess, isTrue);

      expect(
        fixture.client.requests[0].path,
        'core/acp/v1/tenants/tenant-1/ContextProfiles',
      );
      expect(fixture.client.requests[0].method, HttpMethod.post);
      expect(fixture.client.requests[0].body, <String, dynamic>{
        'Name': 'Profile A',
      });

      expect(
        fixture.client.requests[1].path,
        'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1',
      );
      expect(fixture.client.requests[1].method, HttpMethod.patch);
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'Name': 'Updated',
        'RowVersion': 7,
      });

      expect(
        fixture.client.requests[2].path,
        'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1',
      );
      expect(fixture.client.requests[2].method, HttpMethod.delete);
      expect(fixture.client.requests[2].body, <String, dynamic>{
        'RowVersion': 7,
      });

      expect(
        fixture.client.requests[3].path,
        'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1/\$restore',
      );
      expect(fixture.client.requests[3].body, <String, dynamic>{
        'RowVersion': 7,
      });
    },
  );

  test('reference metadata does not alter mutation payloads', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 201, body: '{"Id":"order-1"}'),
        (_) => _response(statusCode: 200, body: '{"Id":"order-1"}'),
      ],
    );
    const values = <String, dynamic>{
      'AccountId': 'account-1',
      'FromStateId': 'state-1',
    };

    await fixture.repository.createRow(
      descriptor: enrichedDescriptor,
      tenantId: 'tenant-1',
      values: values,
    );
    await fixture.repository.updateRow(
      descriptor: enrichedDescriptor,
      rowId: 'order-1',
      tenantId: 'tenant-1',
      values: values,
    );

    expect(fixture.client.requests[0].body, values);
    expect(fixture.client.requests[1].body, values);
    expect(fixture.client.requests[0].body, isNot(contains('Account')));
    expect(fixture.client.requests[1].body, isNot(contains('Wrapper')));
  });

  test(
    'collection and entity actions build expected paths and validate row versions',
    () async {
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 200, body: '{"status":"ok"}'),
          (_) => _response(statusCode: 200, body: '{"status":"ok"}'),
        ],
      );

      final collectionResult = await fixture.repository.runCollectionAction(
        descriptor: optionalDescriptor,
        action: collectionAction,
        values: const <String, dynamic>{'Payload': <String, dynamic>{}},
      );
      final entityResult = await fixture.repository.runEntityAction(
        descriptor: requiredDescriptor,
        action: entityAction,
        rowId: 'row-1',
        tenantId: 'tenant-1',
        rowVersion: 3,
        values: const <String, dynamic>{'RouteKey': 'default'},
      );
      final validationResult = await fixture.repository.runEntityAction(
        descriptor: requiredDescriptor,
        action: entityAction,
        rowId: 'row-2',
        tenantId: 'tenant-1',
        values: const <String, dynamic>{},
      );

      expect(collectionResult.isSuccess, isTrue);
      expect(entityResult.isSuccess, isTrue);
      expect(validationResult.isFailure, isTrue);
      expect(validationResult.failure, isA<ValidationFailure>());
      expect(
        fixture.client.requests[0].path,
        'core/acp/v1/Schemas/\$action/validate',
      );
      expect(
        fixture.client.requests[1].path,
        'core/acp/v1/tenants/tenant-1/ContextProfiles/row-1/\$action/route',
      );
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'RouteKey': 'default',
        'RowVersion': 3,
      });
    },
  );

  test(
    'send maps session expiry, unauthorized, API, and network failures',
    () async {
      final sessionFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final unauthorizedFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 401)],
      );
      final apiFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 500,
            body: jsonEncode(<String, Object?>{'detail': 'server broke'}),
          ),
        ],
      );
      final rawApiFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 500, body: 'plain failure'),
        ],
      );
      final networkFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final staleConflictFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 409,
            body: '{"detail":"RowVersion conflict. Refresh and retry."}',
          ),
        ],
      );
      final lifecycleConflictFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 409,
            body:
                '{"detail":"Invoice can only be issued from draft. ${'x' * 700}"}',
          ),
        ],
      );

      final sessionResult = await sessionFixture.repository.fetchTenants();
      final unauthorizedResult = await unauthorizedFixture.repository
          .fetchTenants();
      final apiResult = await apiFixture.repository.fetchTenants();
      final rawApiResult = await rawApiFixture.repository.fetchTenants();
      final networkResult = await networkFixture.repository.fetchTenants();
      final staleConflict = await staleConflictFixture.repository
          .fetchTenants();
      final lifecycleConflict = await lifecycleConflictFixture.repository
          .fetchTenants();

      expect(sessionResult.isFailure, isTrue);
      expect(sessionResult.failure, isA<SessionExpiredFailure>());
      expect(unauthorizedResult.isFailure, isTrue);
      expect(unauthorizedResult.failure, isA<UnauthorizedFailure>());
      expect(apiResult.isFailure, isTrue);
      expect(apiResult.failure, isA<ApiFailure>());
      expect(apiResult.failure?.message, 'server broke');
      expect(rawApiResult.failure?.message, 'plain failure');
      expect(networkResult.failure, isA<NetworkFailure>());
      expect(
        staleConflict.failure,
        isA<ConflictFailure>().having(
          (failure) => failure.kind,
          'kind',
          ConflictKind.staleRowVersion,
        ),
      );
      expect(
        lifecycleConflict.failure,
        isA<ConflictFailure>()
            .having((failure) => failure.kind, 'kind', ConflictKind.lifecycle)
            .having(
              (failure) => failure.message.length,
              'complete message length',
              greaterThan(700),
            ),
      );
    },
  );

  test('listRows and mutation helpers surface send failures', () async {
    final listFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 401, sessionExpired: true),
      ],
    );
    final createFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 401, sessionExpired: true),
      ],
    );
    final deleteFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 500, body: 'delete failed'),
      ],
    );

    final listResult = await listFixture.repository.listRows(
      descriptor: optionalDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 5),
    );
    final createResult = await createFixture.repository.createRow(
      descriptor: optionalDescriptor,
      values: const <String, dynamic>{'Key': 'schema-a'},
    );
    final deleteResult = await deleteFixture.repository.deleteRow(
      descriptor: optionalDescriptor,
      rowId: 'row-1',
    );

    expect(listResult.isFailure, isTrue);
    expect(listResult.failure, isA<SessionExpiredFailure>());
    expect(createResult.isFailure, isTrue);
    expect(createResult.failure, isA<SessionExpiredFailure>());
    expect(deleteResult.isFailure, isTrue);
    expect(deleteResult.failure, isA<ApiFailure>());
  });

  test(
    'mutation methods validate tenant-scoped paths before sending requests',
    () async {
      final fixture = _RepositoryFixture();

      final createResult = await fixture.repository.createRow(
        descriptor: requiredDescriptor,
        values: const <String, dynamic>{'Name': 'Missing tenant'},
      );
      final updateResult = await fixture.repository.updateRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
        values: const <String, dynamic>{'Name': 'Missing tenant'},
      );
      final deleteResult = await fixture.repository.deleteRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
      );
      final restoreResult = await fixture.repository.restoreRow(
        descriptor: requiredDescriptor,
        rowId: 'row-1',
      );
      final collectionResult = await fixture.repository.runCollectionAction(
        descriptor: requiredDescriptor,
        action: collectionAction,
        values: const <String, dynamic>{},
      );
      final entityResult = await fixture.repository.runEntityAction(
        descriptor: requiredDescriptor,
        action: entityAction,
        rowId: 'row-1',
        values: const <String, dynamic>{},
        rowVersion: 1,
      );

      expect(createResult.failure?.message, 'A tenant must be selected.');
      expect(updateResult.failure?.message, 'A tenant must be selected.');
      expect(deleteResult.failure?.message, 'A tenant must be selected.');
      expect(restoreResult.failure?.message, 'A tenant must be selected.');
      expect(collectionResult.failure?.message, 'A tenant must be selected.');
      expect(entityResult.failure?.message, 'A tenant must be selected.');
    },
  );

  test('listRows enriches expanded and grouped batch references', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            '@count': 1,
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': 'order-1',
                'AccountId': 'account-1',
                'FromStateId': 'state-1',
                'ToStateId': 'state-2',
                'NewStateId': 'state-3',
                'Wrapper': <String, Object?>{'Existing': true},
              },
            ],
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': 'order-1',
                'Account': <String, Object?>{'Name': 'Example Company'},
              },
              <String, Object?>{
                'Account': <String, Object?>{'Name': 'Missing ID'},
              },
            ],
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': 'state-1',
                'Name': 'Draft',
                'Key': 'draft',
              },
              <String, Object?>{
                'Id': 'state-2',
                'Name': 'Active',
                'Key': 'active',
              },
              <String, Object?>{'Id': 'state-3', 'Name': 'Complete'},
              <String, Object?>{'Id': ''},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.listRows(
      descriptor: enrichedDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 15),
      tenantId: 'tenant-1',
    );

    expect(result.isSuccess, isTrue);
    final row = result.data!.items.single;
    expect(row['Account'], <String, dynamic>{'Name': 'Example Company'});
    expect(row['Wrapper'], <String, dynamic>{
      'Existing': true,
      'FromState': <String, dynamic>{
        'Id': 'state-1',
        'Name': 'Draft',
        'Key': 'draft',
      },
      'ToState': <String, dynamic>{
        'Id': 'state-2',
        'Name': 'Active',
        'Key': 'active',
      },
    });
    expect(row['NewWrapper'], <String, dynamic>{
      'State': <String, dynamic>{'Id': 'state-3', 'Name': 'Complete'},
    });
    expect(row['AccountId'], 'account-1');
    expect(fixture.client.requests, hasLength(3));
    expect(
      fixture.client.requests[1].queryParameters[r'$expand'],
      r'Account($select=Name)',
    );
    expect(
      fixture.client.requests[2].queryParameters[r'$filter'],
      "Id in ('state-1','state-2','state-3')",
    );
    expect(fixture.client.requests[2].queryParameters[r'$deleted'], 'all');
  });

  test('fetchRow applies the same reference enrichment', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'Id': 'order-1',
            'AccountId': 'account-1',
            'FromStateId': 'state-1',
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'Id': 'order-1',
            'Account': <String, Object?>{'Name': 'Example Company'},
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'state-1', 'Name': 'Draft'},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.fetchRow(
      descriptor: enrichedDescriptor,
      rowId: 'order-1',
      tenantId: 'tenant-1',
    );

    expect(result.data?['Account'], <String, dynamic>{
      'Name': 'Example Company',
    });
    expect(fixture.client.requests[1].queryParameters, <String, dynamic>{
      r'$select': 'Id',
      r'$expand': r'Account($select=Name)',
    });
    expect((result.data?['Wrapper'] as Map?)?['FromState'], <String, dynamic>{
      'Id': 'state-1',
      'Name': 'Draft',
    });
  });

  test('registered expansion re-fetches use typed GUID filters', () async {
    var index = 0;
    for (final source in registeredResources.where(
      (resource) => resource.expansions.isNotEmpty,
    )) {
      index += 1;
      final suffix = index.toString().padLeft(12, '0');
      final rowId = '10000000-0000-4000-8000-$suffix';
      final descriptor = AcpResourceDescriptor(
        key: source.key,
        title: source.title,
        entitySet: source.entitySet,
        scopeMode: source.scopeMode,
        keyLiteralType: source.keyLiteralType,
        columns: const <AcpColumnDescriptor>[],
        expansions: source.expansions,
      );
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{'Id': rowId},
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': rowId.toUpperCase(),
                  for (final expansion in source.expansions)
                    expansion.navigation: <String, Object?>{},
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );

      expect(result.isSuccess, isTrue, reason: source.entitySet);
      expect(fixture.client.requests, hasLength(2), reason: source.entitySet);
      expect(
        fixture.client.requests[1].queryParameters[r'$filter'],
        "Id in (guid'$rowId')",
        reason: source.entitySet,
      );
    }
  });

  test('administration batch references use typed GUID filters', () async {
    final cases =
        <
          ({
            List<AcpResourceDescriptor> resources,
            String sourceEntitySet,
            String columnKey,
            String targetEntitySet,
          })
        >[
          (
            resources: orchestrationAdminResources,
            sourceEntitySet: 'ChannelProfiles',
            columnKey: 'ClientProfileId',
            targetEntitySet: 'MessagingClientProfiles',
          ),
          (
            resources: connectorResources,
            sourceEntitySet: 'OpsConnectorInstances',
            columnKey: 'ConnectorTypeId',
            targetEntitySet: 'OpsConnectorTypes',
          ),
          (
            resources: connectorResources,
            sourceEntitySet: 'OpsConnectorCallLogs',
            columnKey: 'ConnectorInstanceId',
            targetEntitySet: 'OpsConnectorInstances',
          ),
          (
            resources: reportingResources,
            sourceEntitySet: 'OpsReportingMetricSeries',
            columnKey: 'MetricDefinitionId',
            targetEntitySet: 'OpsReportingMetricDefinitions',
          ),
          (
            resources: reportingResources,
            sourceEntitySet: 'OpsReportingReportSnapshots',
            columnKey: 'ReportDefinitionId',
            targetEntitySet: 'OpsReportingReportDefinitions',
          ),
          (
            resources: slaResources,
            sourceEntitySet: 'OpsSlaPolicies',
            columnKey: 'CalendarId',
            targetEntitySet: 'OpsSlaCalendars',
          ),
          (
            resources: slaResources,
            sourceEntitySet: 'OpsSlaTargets',
            columnKey: 'PolicyId',
            targetEntitySet: 'OpsSlaPolicies',
          ),
          (
            resources: workflowResources,
            sourceEntitySet: 'OpsWorkflowVersions',
            columnKey: 'WorkflowDefinitionId',
            targetEntitySet: 'OpsWorkflowDefinitions',
          ),
          (
            resources: workflowResources,
            sourceEntitySet: 'OpsWorkflowStates',
            columnKey: 'WorkflowVersionId',
            targetEntitySet: 'OpsWorkflowVersions',
          ),
          (
            resources: workflowResources,
            sourceEntitySet: 'OpsWorkflowTransitions',
            columnKey: 'FromStateId',
            targetEntitySet: 'OpsWorkflowStates',
          ),
          (
            resources: knowledgePackAdminResources,
            sourceEntitySet: 'KnowledgeApprovals',
            columnKey: 'ActorUserId',
            targetEntitySet: 'Users',
          ),
          (
            resources: orchestrationAdminResources,
            sourceEntitySet: 'WorkItems',
            columnKey: 'LinkedCaseId',
            targetEntitySet: 'OpsCases',
          ),
          (
            resources: orchestrationAdminResources,
            sourceEntitySet: 'WorkItems',
            columnKey: 'LinkedWorkflowInstanceId',
            targetEntitySet: 'OpsWorkflowInstances',
          ),
        ];

    for (var index = 0; index < cases.length; index += 1) {
      final batchCase = cases[index];
      final source = batchCase.resources.singleWhere(
        (resource) => resource.entitySet == batchCase.sourceEntitySet,
      );
      final column = source.columns.singleWhere(
        (candidate) => candidate.key == batchCase.columnKey,
      );
      final lookup = column.reference!.batchLookup!;
      final suffix = (index + 1).toString().padLeft(12, '0');
      final rowId = '30000000-0000-4000-8000-$suffix';
      final targetId = '40000000-0000-4000-8000-$suffix';
      final descriptor = AcpResourceDescriptor(
        key: source.key,
        title: source.title,
        entitySet: source.entitySet,
        scopeMode: source.scopeMode,
        keyLiteralType: source.keyLiteralType,
        columns: <AcpColumnDescriptor>[column],
      );
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{'Id': rowId, batchCase.columnKey: targetId},
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': targetId.toUpperCase(),
                  for (final field in lookup.selectFields) field: 'Reference',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );

      expect(result.isSuccess, isTrue, reason: batchCase.targetEntitySet);
      expect(fixture.client.requests, hasLength(2));
      expect(
        fixture.client.requests[1].path,
        endsWith('/${batchCase.targetEntitySet}'),
      );
      expect(
        fixture.client.requests[1].queryParameters[r'$filter'],
        "Id in (guid'$targetId')",
        reason:
            '${batchCase.sourceEntitySet}.${batchCase.columnKey} '
            '-> ${batchCase.targetEntitySet}',
      );
    }
  });

  test(
    'Price Entitlement expansion uses GUID keys and avoids batch fallback',
    () async {
      final descriptor = billingCatalogResources.singleWhere(
        (resource) => resource.entitySet == 'BillingPriceEntitlements',
      );
      const entitlementId = '10000000-0000-4000-8000-abcdefabcdef';
      const priceId = '20000000-0000-4000-8000-000000000001';
      const meterId = '30000000-0000-4000-8000-000000000001';
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              '@count': 1,
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': entitlementId,
                  'PriceId': priceId,
                  'MeterDefinitionId': meterId,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': entitlementId.toUpperCase(),
                  'Price': <String, Object?>{
                    'Code': 'customer-inbox-monthly',
                    'PriceType': 'recurring',
                    'Currency': 'USD',
                    'DeletedAt': '2026-08-27T00:00:00Z',
                  },
                  'MeterDefinition': <String, Object?>{
                    'Code': 'valet.customer-inbox.minutes',
                    'Unit': 'minute',
                  },
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.referenceWarning, isNull);
      expect(fixture.client.requests, hasLength(2));
      expect(
        fixture.client.requests[1].queryParameters[r'$filter'],
        "Id in (guid'$entitlementId')",
      );
      expect(
        acpReferenceDisplayValue(
          row: result.data!.items.single,
          column: descriptor.columns.singleWhere(
            (column) => column.key == 'PriceId',
          ),
        ),
        'customer-inbox-monthly · recurring · USD',
      );
      expect(
        acpReferenceDisplayValue(
          row: result.data!.items.single,
          column: descriptor.columns.singleWhere(
            (column) => column.key == 'MeterDefinitionId',
          ),
        ),
        'valet.customer-inbox.minutes · minute',
      );
    },
  );

  test(
    'existing navigation values skip all reference fallback requests',
    () async {
      final descriptor = billingCatalogResources.singleWhere(
        (resource) => resource.entitySet == 'BillingPriceEntitlements',
      );
      const entitlementId = '10000000-0000-4000-8000-000000000002';
      const priceId = '20000000-0000-4000-8000-000000000002';
      const meterId = '30000000-0000-4000-8000-000000000002';
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': entitlementId,
                  'PriceId': priceId,
                  'MeterDefinitionId': meterId,
                  'Price': <String, Object?>{
                    'Code': 'customer-inbox-monthly',
                    'PriceType': 'recurring',
                    'Currency': 'USD',
                  },
                  'MeterDefinition': <String, Object?>{
                    'Code': 'valet.customer-inbox.minutes',
                    'Unit': 'minute',
                  },
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );

      expect(result.data?.referenceWarning, isNull);
      expect(fixture.client.requests, hasLength(1));
    },
  );

  test(
    'Price Entitlement expansion failure resolves through GUID batch fallbacks',
    () async {
      final descriptor = billingCatalogResources.singleWhere(
        (resource) => resource.entitySet == 'BillingPriceEntitlements',
      );
      const entitlementId = '10000000-0000-4000-8000-000000000003';
      const priceId = '20000000-0000-4000-8000-000000000003';
      const meterId = '30000000-0000-4000-8000-000000000003';
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': entitlementId,
                  'PriceId': priceId,
                  'MeterDefinitionId': meterId,
                },
              ],
            }),
          ),
          (_) => _response(statusCode: 503, body: 'expansion unavailable'),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': priceId.toUpperCase(),
                  'Code': 'customer-inbox-monthly',
                  'PriceType': 'recurring',
                  'Currency': 'USD',
                  'DeletedAt': '2026-08-27T00:00:00Z',
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': meterId,
                  'Code': 'valet.customer-inbox.minutes',
                  'Unit': 'minute',
                  'Description': 'Included customer inbox minutes',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.referenceWarning, isNull);
      expect(fixture.client.requests, hasLength(4));
      expect(
        fixture.client.requests[2].queryParameters[r'$filter'],
        "Id in (guid'$priceId')",
      );
      expect(fixture.client.requests[2].queryParameters[r'$deleted'], 'all');
      expect(
        fixture.client.requests[3].queryParameters[r'$filter'],
        "Id in (guid'$meterId')",
      );
      final row = result.data!.items.single;
      expect((row['Price'] as Map?)?['Code'], 'customer-inbox-monthly');
      expect(
        (row['MeterDefinition'] as Map?)?['Code'],
        'valet.customer-inbox.minutes',
      );
    },
  );

  test(
    'Subscription batch fallbacks isolate tenant Accounts and global Prices',
    () async {
      final descriptor = billingOperationsResources.singleWhere(
        (resource) => resource.entitySet == 'BillingSubscriptions',
      );
      const tenantA = '40000000-0000-4000-8000-000000000001';
      const tenantB = '40000000-0000-4000-8000-000000000002';
      const subscriptionA = '50000000-0000-4000-8000-000000000001';
      const subscriptionB = '50000000-0000-4000-8000-000000000002';
      const accountA = '60000000-0000-4000-8000-000000000001';
      const accountB = '60000000-0000-4000-8000-000000000002';
      const priceA = '70000000-0000-4000-8000-000000000001';
      const priceB = '70000000-0000-4000-8000-000000000002';
      _AuthHandler page(String subscription, String account, String price) {
        return (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': subscription,
                'AccountId': account,
                'PriceId': price,
              },
            ],
          }),
        );
      }

      _AuthHandler account(String id, String name, String code) {
        return (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': id,
                'DisplayName': name,
                'Code': code,
                'Email': '$code@example.test',
              },
            ],
          }),
        );
      }

      _AuthHandler price(String id, String code) {
        return (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{
                'Id': id,
                'Code': code,
                'PriceType': 'recurring',
                'Currency': 'USD',
              },
            ],
          }),
        );
      }

      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          page(subscriptionA, accountA, priceA),
          (_) => _response(statusCode: 503, body: 'expand failed'),
          account(accountA, 'Example Customer A', 'example-a'),
          price(priceA, 'customer-inbox-a'),
          page(subscriptionB, accountB, priceB),
          (_) => _response(statusCode: 503, body: 'expand failed'),
          account(accountB, 'Example Customer B', 'example-b'),
          price(priceB, 'customer-inbox-b'),
        ],
      );

      final first = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: tenantA,
      );
      final second = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: tenantB,
      );

      expect(first.data?.referenceWarning, isNull);
      expect(second.data?.referenceWarning, isNull);
      expect(
        (first.data!.items.single['Account'] as Map?)?['Code'],
        'example-a',
      );
      expect(
        (second.data!.items.single['Account'] as Map?)?['Code'],
        'example-b',
      );
      expect(
        fixture.client.requests[2].path,
        'core/acp/v1/tenants/$tenantA/BillingAccounts',
      );
      expect(
        fixture.client.requests[6].path,
        'core/acp/v1/tenants/$tenantB/BillingAccounts',
      );
      expect(fixture.client.requests[3].path, 'core/acp/v1/BillingPrices');
      expect(fixture.client.requests[7].path, 'core/acp/v1/BillingPrices');
      expect(
        fixture.client.requests
            .where((request) => request.path.contains('BillingAccounts'))
            .map((request) => request.path),
        <String>[
          'core/acp/v1/tenants/$tenantA/BillingAccounts',
          'core/acp/v1/tenants/$tenantB/BillingAccounts',
        ],
      );
    },
  );

  test(
    'incomplete reference fallback exposes a non-blocking warning',
    () async {
      final descriptor = billingCatalogResources.singleWhere(
        (resource) => resource.entitySet == 'BillingPriceEntitlements',
      );
      const entitlementId = '10000000-0000-4000-8000-000000000004';
      const priceId = '20000000-0000-4000-8000-000000000004';
      const meterId = '30000000-0000-4000-8000-000000000004';
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              '@count': 1,
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': entitlementId,
                  'PriceId': priceId,
                  'MeterDefinitionId': meterId,
                },
              ],
            }),
          ),
          (_) => _response(statusCode: 500, body: 'expand failed'),
          (_) => _response(statusCode: 403, body: 'price lookup forbidden'),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': meterId,
                  'Code': 'valet.customer-inbox.minutes',
                  'Unit': 'minute',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.items, hasLength(1));
      expect(result.data?.referenceWarning, contains('Price'));
      expect(result.data?.referenceWarning, isNot(contains('Meter.')));
      expect(result.data?.referenceWarning, contains('price lookup forbidden'));
      expect(result.data?.items.single['PriceId'], priceId);
      expect(
        (result.data?.items.single['MeterDefinition'] as Map?)?['Code'],
        'valet.customer-inbox.minutes',
      );
    },
  );

  test(
    'reference failures never replace the primary collection result',
    () async {
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              '@count': 1,
              'value': <Map<String, Object?>>[
                <String, Object?>{
                  'Id': 'order-1',
                  'AccountId': 'account-1',
                  'FromStateId': 'state-1',
                },
              ],
            }),
          ),
          (_) => _response(statusCode: 500, body: 'expand failed'),
          (_) => _response(statusCode: 403, body: 'batch forbidden'),
        ],
      );

      final result = await fixture.repository.listRows(
        descriptor: enrichedDescriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
        tenantId: 'tenant-1',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.items.single['AccountId'], 'account-1');
      expect(result.data!.items.single.containsKey('Account'), isFalse);
    },
  );

  test('reference enrichment can be disabled for count queries', () async {
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            '@count': 1,
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'order-1'},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.listRows(
      descriptor: enrichedDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 1),
      tenantId: 'tenant-1',
      enrichReferences: false,
    );

    expect(result.isSuccess, isTrue);
    expect(fixture.client.requests, hasLength(1));
  });

  test(
    'reference enrichment skips rows and lookups without identifiers',
    () async {
      const descriptor = AcpResourceDescriptor(
        key: 'records',
        title: 'Records',
        entitySet: 'Records',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[
          AcpColumnDescriptor(
            key: 'TargetId',
            label: 'Target',
            reference: AcpColumnReferenceDescriptor(
              navigationPath: 'Target',
              titleFields: <AcpReferenceFieldDescriptor>[
                AcpReferenceFieldDescriptor('Name'),
              ],
              batchLookup: AcpBatchReferenceDescriptor(
                entitySet: 'Targets',
                scopeMode: AcpScopeMode.none,
                selectFields: <String>['Name'],
              ),
            ),
          ),
        ],
        expansions: <AcpExpandDescriptor>[
          AcpExpandDescriptor(navigation: 'Parent'),
        ],
      );
      final noIdFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{
              'value': <Map<String, Object?>>[<String, Object?>{}],
            }),
          ),
        ],
      );
      final emptyFixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, Object?>{'value': <Object?>[]}),
          ),
        ],
      );

      final noIdResult = await noIdFixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );
      final emptyResult = await emptyFixture.repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 15),
      );

      expect(noIdResult.isSuccess, isTrue);
      expect(emptyResult.isSuccess, isTrue);
      expect(noIdFixture.client.requests, hasLength(1));
      expect(emptyFixture.client.requests, hasLength(1));
    },
  );

  test('malformed GUID source keys skip expansion requests safely', () async {
    const descriptor = AcpResourceDescriptor(
      key: 'records',
      title: 'Records',
      entitySet: 'Records',
      scopeMode: AcpScopeMode.none,
      keyLiteralType: AcpFilterLiteralType.guid,
      columns: <AcpColumnDescriptor>[],
      expansions: <AcpExpandDescriptor>[
        AcpExpandDescriptor(navigation: 'Parent'),
      ],
    );
    final fixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'not-a-guid'},
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.listRows(
      descriptor: descriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 15),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.items.single['Id'], 'not-a-guid');
    expect(fixture.client.requests, hasLength(1));
  });

  test('unavailable batch paths and malformed responses are ignored', () async {
    const missingTenantDescriptor = AcpResourceDescriptor(
      key: 'records',
      title: 'Records',
      entitySet: 'Records',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[
        AcpColumnDescriptor(
          key: 'TargetId',
          label: 'Target',
          reference: AcpColumnReferenceDescriptor(
            navigationPath: 'Target',
            titleFields: <AcpReferenceFieldDescriptor>[
              AcpReferenceFieldDescriptor('Name'),
            ],
            batchLookup: AcpBatchReferenceDescriptor(
              entitySet: 'Targets',
              scopeMode: AcpScopeMode.required,
              selectFields: <String>['Name'],
            ),
          ),
        ),
      ],
    );
    const malformedDescriptor = AcpResourceDescriptor(
      key: 'records',
      title: 'Records',
      entitySet: 'Records',
      scopeMode: AcpScopeMode.none,
      columns: <AcpColumnDescriptor>[
        AcpColumnDescriptor(
          key: 'TargetId',
          label: 'Target',
          reference: AcpColumnReferenceDescriptor(
            navigationPath: '...',
            titleFields: <AcpReferenceFieldDescriptor>[
              AcpReferenceFieldDescriptor('Name'),
            ],
            batchLookup: AcpBatchReferenceDescriptor(
              entitySet: 'Targets',
              scopeMode: AcpScopeMode.none,
              selectFields: <String>['Name'],
            ),
          ),
        ),
      ],
    );
    final missingTenantFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'row-1', 'TargetId': 'target-1'},
            ],
          }),
        ),
      ],
    );
    final malformedFixture = _RepositoryFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'row-1', 'TargetId': 'target-1'},
            ],
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, Object?>{
            'value': <Map<String, Object?>>[
              <String, Object?>{'Id': 'target-1', 'Name': 'Target'},
            ],
          }),
        ),
      ],
    );

    final missingTenant = await missingTenantFixture.repository.listRows(
      descriptor: missingTenantDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 15),
    );
    final malformed = await malformedFixture.repository.listRows(
      descriptor: malformedDescriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 15),
    );

    expect(missingTenant.isSuccess, isTrue);
    expect(missingTenantFixture.client.requests, hasLength(1));
    expect(malformed.isSuccess, isTrue);
    expect(malformed.data!.items.single.containsKey('Target'), isFalse);
  });

  test(
    'entity expansion with an unavailable payload preserves the base row',
    () async {
      const descriptor = AcpResourceDescriptor(
        key: 'records',
        title: 'Records',
        entitySet: 'Records',
        scopeMode: AcpScopeMode.none,
        columns: <AcpColumnDescriptor>[],
        expansions: <AcpExpandDescriptor>[
          AcpExpandDescriptor(navigation: 'Parent'),
        ],
      );
      final fixture = _RepositoryFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 200, body: '{"Id":"row-1"}'),
          (_) => _response(statusCode: 200, body: '[]'),
        ],
      );

      final result = await fixture.repository.fetchRow(
        descriptor: descriptor,
        rowId: 'row-1',
      );

      expect(result.data, <String, dynamic>{'Id': 'row-1'});
    },
  );
}

typedef _AuthHandler =
    FutureOr<AuthenticatedResponse> Function(AcpRequest request);

class _RepositoryFixture {
  _RepositoryFixture._(this.appConfig, this.client)
    : repository = AcpAdminRepositoryImpl(
        appConfig: appConfig,
        authenticatedHttpClient: client,
      );

  factory _RepositoryFixture({List<_AuthHandler>? handlers}) {
    final appConfig = AppConfig.defaults();
    final client = _FakeAuthenticatedHttpClient(handlers: handlers);
    return _RepositoryFixture._(appConfig, client);
  }

  final AppConfig appConfig;
  final _FakeAuthenticatedHttpClient client;
  final AcpAdminRepositoryImpl repository;
}

class _FakeAuthenticatedHttpClient extends AuthenticatedHttpClient {
  _FakeAuthenticatedHttpClient({List<_AuthHandler>? handlers})
    : handlers = Queue<_AuthHandler>.from(handlers ?? const <_AuthHandler>[]),
      super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.com',
          transport: _NoopTransport(),
        ),
        cookieStore: _FakeCookieStore(),
        refreshPath: 'auth/refresh',
      );

  final Queue<_AuthHandler> handlers;
  final List<AcpRequest> requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    if (handlers.isEmpty) {
      throw StateError('No handler configured.');
    }

    return handlers.removeFirst()(request);
  }
}

class _FakeCookieStore implements CookieStore {
  @override
  String? getCookie(String key) => null;

  @override
  void removeCookie(String key, String path) {}

  @override
  void setCookie(String key, String value, int maxAge, String path) {}
}

class _NoopTransport implements HttpTransport {
  @override
  void close() {}

  @override
  Future<HttpResponse> execute(HttpRequest request) {
    throw UnimplementedError();
  }
}

AuthenticatedResponse _response({
  required int statusCode,
  String body = '{}',
  bool sessionExpired = false,
}) {
  return AuthenticatedResponse(
    response: HttpResponse(
      statusCode: statusCode,
      body: body,
      headers: const <String, String>{},
    ),
    sessionExpired: sessionExpired,
  );
}
