import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
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

      final sessionResult = await sessionFixture.repository.fetchTenants();
      final unauthorizedResult = await unauthorizedFixture.repository
          .fetchTenants();
      final apiResult = await apiFixture.repository.fetchTenants();
      final rawApiResult = await rawApiFixture.repository.fetchTenants();
      final networkResult = await networkFixture.repository.fetchTenants();

      expect(sessionResult.isFailure, isTrue);
      expect(sessionResult.failure, isA<SessionExpiredFailure>());
      expect(unauthorizedResult.isFailure, isTrue);
      expect(unauthorizedResult.failure, isA<UnauthorizedFailure>());
      expect(apiResult.isFailure, isTrue);
      expect(apiResult.failure, isA<ApiFailure>());
      expect(apiResult.failure?.message, 'server broke');
      expect(rawApiResult.failure?.message, 'plain failure');
      expect(networkResult.failure, isA<NetworkFailure>());
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
