import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/infrastructure/repositories/tenant_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('TenantAdminRepositoryImpl.fetchTenants', () {
    test('builds expected query and maps tenant payload', () async {
      final fixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': '1',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 't-1',
                  'Name': 'Alpha Tenant',
                  'Slug': 'alpha',
                  'Status': 'Active',
                  'RowVersion': '7',
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                  'DeletedAt': null,
                  'SeedData': '1',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchTenants(
        const TenantListQuery(
          pageRequest: PageRequest(page: 2, pageSize: 10),
          searchTerm: "al'",
        ),
      );

      expect(result.isSuccess, isTrue);
      final page = result.data!;
      expect(page.total, 1);
      expect(page.items, hasLength(1));
      final tenant = page.items.single;
      expect(tenant.id, 't-1');
      expect(tenant.name, 'Alpha Tenant');
      expect(tenant.slug, 'alpha');
      expect(tenant.status, 'Active');
      expect(tenant.rowVersion, 7);
      expect(tenant.seedData, isTrue);
      expect(tenant.dateCreated, DateTime.utc(2026, 1, 1));
      expect(tenant.dateLastModified, DateTime.utc(2025, 1, 1));

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/Tenants');
      expect(request.queryParameters[r'$skip'], 10);
      expect(request.queryParameters[r'$top'], 10);
      expect(
        request.queryParameters[r'$filter'],
        "contains(Name,'al''') or contains(Slug,'al''')",
      );
    });

    test('handles paging edge-cases and failures', () async {
      final noPagingFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': 0,
              'value': <dynamic>[],
            }),
          ),
        ],
      );
      final noPaging = await noPagingFixture.repository.fetchTenants(
        const TenantListQuery(pageRequest: PageRequest(page: 1, pageSize: 0)),
      );
      expect(noPaging.isSuccess, isTrue);
      expect(
        noPagingFixture.client.requests.single.queryParameters.containsKey(
          r'$skip',
        ),
        isFalse,
      );
      expect(
        noPagingFixture.client.requests.single.queryParameters.containsKey(
          r'$filter',
        ),
        isFalse,
      );

      final unexpectedFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );
      final unexpected = await unexpectedFixture.repository.fetchTenants(
        const TenantListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );
      expect(unexpected.isFailure, isTrue);
      expect(unexpected.failure, isA<UnexpectedFailure>());

      final sessionFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final session = await sessionFixture.repository.fetchTenants(
        const TenantListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );
      expect(session.isFailure, isTrue);
      expect(session.failure, isA<SessionExpiredFailure>());
      expect(sessionFixture.cookieStore.removed, contains('auth:/'));

      final apiFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
      );
      final api = await apiFixture.repository.fetchTenants(
        const TenantListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());

      final networkFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.fetchTenants(
        const TenantListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    });
  });

  group('TenantAdminRepositoryImpl detail fetches', () {
    test('maps tenant domains, invitations, and memberships', () async {
      final fixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'd-1',
                  'TenantId': '',
                  'Domain': 'alpha.example.com',
                  'IsPrimary': '1',
                  'RowVersion': 3.2,
                  'CreatedAt': null,
                  'UpdatedAt': 'invalid-date',
                  'DeletedAt': null,
                  'SeedData': false,
                },
                <String, dynamic>{
                  'Id': 'd-2',
                  'TenantId': 'tenant-explicit',
                  'Domain': 'explicit.example.com',
                  'IsPrimary': 1,
                  'RowVersion': 4,
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-01T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': false,
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'i-1',
                  'TenantId': 'tenant-1',
                  'Email': 'user@example.com',
                  'RoleInTenant': 'member',
                  'Status': 'Pending',
                  'RowVersion': '9',
                  'CreatedAt': '2026-01-01T00:00:00Z',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'ExpiresAt': '2026-01-03T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': '0',
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'm-1',
                  'TenantId': 'tenant-1',
                  'UserId': 'u-1',
                  'RoleInTenant': 'owner',
                  'Status': 'Active',
                  'RowVersion': 5,
                  'CreatedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                  'UpdatedAt': '2026-01-02T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': true,
                },
              ],
            }),
          ),
        ],
      );

      final domains = await fixture.repository.fetchTenantDomains(
        tenantId: 'tenant-1',
      );
      final invitations = await fixture.repository.fetchTenantInvitations(
        tenantId: 'tenant-1',
      );
      final memberships = await fixture.repository.fetchTenantMemberships(
        tenantId: 'tenant-1',
      );

      expect(domains.isSuccess, isTrue);
      expect(domains.data!.first.tenantId, 'tenant-1');
      expect(domains.data!.first.domain, 'alpha.example.com');
      expect(domains.data!.first.isPrimary, isTrue);
      expect(domains.data!.last.tenantId, 'tenant-explicit');
      expect(domains.data!.last.isPrimary, isTrue);

      expect(invitations.isSuccess, isTrue);
      expect(invitations.data!.single.email, 'user@example.com');
      expect(invitations.data!.single.expiresAt, DateTime.utc(2026, 1, 3));

      expect(memberships.isSuccess, isTrue);
      expect(memberships.data!.single.userId, 'u-1');
      expect(memberships.data!.single.roleInTenant, 'owner');

      expect(
        fixture.client.requests[0].path,
        'core/acp/v1/Tenants/tenant-1/TenantDomains',
      );
      expect(fixture.client.requests[0].queryParameters[r'$top'], 100);
      expect(
        fixture.client.requests[1].path,
        'core/acp/v1/Tenants/tenant-1/TenantInvitations',
      );
      expect(
        fixture.client.requests[2].path,
        'core/acp/v1/Tenants/tenant-1/TenantMemberships',
      );
    });

    test('maps detail fetch failures', () async {
      final unexpectedFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );
      final unexpected = await unexpectedFixture.repository.fetchTenantDomains(
        tenantId: 'tenant-1',
      );
      expect(unexpected.isFailure, isTrue);
      expect(unexpected.failure, isA<UnexpectedFailure>());

      final apiFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 503)],
      );
      final api = await apiFixture.repository.fetchTenantInvitations(
        tenantId: 'tenant-1',
      );
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());

      final sessionFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final session = await sessionFixture.repository.fetchTenantMemberships(
        tenantId: 'tenant-1',
      );
      expect(session.isFailure, isTrue);
      expect(session.failure, isA<SessionExpiredFailure>());
      expect(sessionFixture.cookieStore.removed, contains('auth:/'));

      final networkFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.fetchTenantDomains(
        tenantId: 'tenant-1',
      );
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    });
  });

  group('TenantAdminRepositoryImpl mutations', () {
    test(
      'sends expected CRUD/action requests for all tenant resources',
      () async {
        final fixture = _TenantAdminFixture(
          handlers: List<_AuthHandler>.filled(
            16,
            (_) => _response(statusCode: 204),
          ),
        );

        await fixture.repository.createTenant(
          const CreateTenantInput(name: 'Tenant', slug: 'tenant'),
        );
        await fixture.repository.updateTenant(
          const UpdateTenantInput(
            tenantId: 'tenant-1',
            name: 'Tenant Updated',
            slug: 'tenant-updated',
            rowVersion: 2,
          ),
        );
        await fixture.repository.deactivateTenant(
          const TenantLifecycleInput(tenantId: 'tenant-1', rowVersion: 3),
        );
        await fixture.repository.reactivateTenant(
          const TenantLifecycleInput(tenantId: 'tenant-1', rowVersion: 4),
        );

        await fixture.repository.createTenantDomain(
          const CreateTenantDomainInput(
            tenantId: 'tenant-1',
            domain: 'alpha.example.com',
            isPrimary: true,
          ),
        );
        await fixture.repository.updateTenantDomain(
          const UpdateTenantDomainInput(
            tenantId: 'tenant-1',
            domainId: 'd-1',
            domain: 'beta.example.com',
            isPrimary: false,
            rowVersion: 5,
          ),
        );
        await fixture.repository.deleteTenantDomain(
          const DeleteTenantDomainInput(
            tenantId: 'tenant-1',
            domainId: 'd-1',
            rowVersion: 6,
          ),
        );

        await fixture.repository.createTenantInvitation(
          const CreateTenantInvitationInput(
            tenantId: 'tenant-1',
            email: 'user@example.com',
            roleInTenant: 'member',
          ),
        );
        await fixture.repository.resendTenantInvitation(
          const TenantInvitationActionInput(
            tenantId: 'tenant-1',
            invitationId: 'i-1',
            rowVersion: 7,
          ),
        );
        await fixture.repository.revokeTenantInvitation(
          const TenantInvitationActionInput(
            tenantId: 'tenant-1',
            invitationId: 'i-1',
            rowVersion: 8,
          ),
        );

        await fixture.repository.createTenantMembership(
          const CreateTenantMembershipInput(
            tenantId: 'tenant-1',
            userId: 'u-1',
            roleInTenant: 'member',
          ),
        );
        await fixture.repository.updateTenantMembership(
          const UpdateTenantMembershipInput(
            tenantId: 'tenant-1',
            membershipId: 'm-1',
            roleInTenant: 'owner',
            rowVersion: 9,
          ),
        );
        await fixture.repository.suspendTenantMembership(
          const TenantMembershipActionInput(
            tenantId: 'tenant-1',
            membershipId: 'm-1',
            rowVersion: 10,
          ),
        );
        await fixture.repository.unsuspendTenantMembership(
          const TenantMembershipActionInput(
            tenantId: 'tenant-1',
            membershipId: 'm-1',
            rowVersion: 11,
          ),
        );
        await fixture.repository.removeTenantMembership(
          const TenantMembershipActionInput(
            tenantId: 'tenant-1',
            membershipId: 'm-1',
            rowVersion: 12,
          ),
        );

        expect(fixture.client.requests, hasLength(15));
        expect(fixture.client.requests[0].method, HttpMethod.post);
        expect(fixture.client.requests[0].path, 'core/acp/v1/Tenants');
        expect(fixture.client.requests[0].body, <String, dynamic>{
          'Name': 'Tenant',
          'Slug': 'tenant',
        });
        expect(fixture.client.requests[1].method, HttpMethod.patch);
        expect(fixture.client.requests[1].path, 'core/acp/v1/Tenants/tenant-1');
        expect(fixture.client.requests[1].body, <String, dynamic>{
          'Name': 'Tenant Updated',
          'Slug': 'tenant-updated',
          'RowVersion': 2,
        });
        expect(
          fixture.client.requests[2].path,
          r'core/acp/v1/Tenants/tenant-1/$action/deactivate',
        );
        expect(
          fixture.client.requests[3].path,
          r'core/acp/v1/Tenants/tenant-1/$action/reactivate',
        );
        expect(
          fixture.client.requests[4].path,
          'core/acp/v1/Tenants/tenant-1/TenantDomains',
        );
        expect(
          fixture.client.requests[5].path,
          'core/acp/v1/Tenants/tenant-1/TenantDomains/d-1',
        );
        expect(fixture.client.requests[5].body, <String, dynamic>{
          'Domain': 'beta.example.com',
          'IsPrimary': false,
          'RowVersion': 5,
        });
        expect(fixture.client.requests[6].method, HttpMethod.delete);
        expect(fixture.client.requests[6].body, <String, dynamic>{
          'RowVersion': 6,
        });
        expect(
          fixture.client.requests[8].path,
          r'core/acp/v1/Tenants/tenant-1/TenantInvitations/i-1/$action/resend',
        );
        expect(
          fixture.client.requests[9].path,
          r'core/acp/v1/Tenants/tenant-1/TenantInvitations/i-1/$action/revoke',
        );
        expect(
          fixture.client.requests[12].path,
          r'core/acp/v1/Tenants/tenant-1/TenantMemberships/m-1/$action/suspend',
        );
        expect(
          fixture.client.requests[13].path,
          r'core/acp/v1/Tenants/tenant-1/TenantMemberships/m-1/$action/unsuspend',
        );
        expect(
          fixture.client.requests[14].path,
          r'core/acp/v1/Tenants/tenant-1/TenantMemberships/m-1/$action/remove',
        );
        expect(fixture.client.requests[11].body, <String, dynamic>{
          'RoleInTenant': 'owner',
          'RowVersion': 9,
        });
      },
    );

    test('maps mutation API, session, and network failures', () async {
      final apiFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 409)],
      );
      final api = await apiFixture.repository.createTenant(
        const CreateTenantInput(name: 'Tenant', slug: 'tenant'),
      );
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());
      expect((api.failure as ApiFailure).statusCode, 409);

      final sessionFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final session = await sessionFixture.repository.createTenant(
        const CreateTenantInput(name: 'Tenant', slug: 'tenant'),
      );
      expect(session.isFailure, isTrue);
      expect(session.failure, isA<SessionExpiredFailure>());
      expect(sessionFixture.cookieStore.removed, contains('auth:/'));

      final networkFixture = _TenantAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.createTenant(
        const CreateTenantInput(name: 'Tenant', slug: 'tenant'),
      );
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    });
  });
}

class _TenantAdminFixture {
  _TenantAdminFixture({List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    repository = TenantAdminRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final TenantAdminRepositoryImpl repository;
}

typedef _AuthHandler = FutureOr<AuthenticatedResponse> Function(AcpRequest);

class _QueueAuthenticatedHttpClient extends AuthenticatedHttpClient {
  _QueueAuthenticatedHttpClient(List<_AuthHandler> handlers)
    : _handlers = Queue<_AuthHandler>.from(handlers),
      super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.com/api',
          transport: _NoopHttpTransport(),
        ),
        cookieStore: _MemoryCookieStore(),
        refreshPath: 'core/acp/v1/auth/refresh',
      );

  final Queue<_AuthHandler> _handlers;
  final List<AcpRequest> requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    if (_handlers.isEmpty) {
      throw StateError('No queued response for request: ${request.path}');
    }

    return await _handlers.removeFirst().call(request);
  }
}

class _MemoryCookieStore implements CookieStore {
  final Map<String, String> _cookies = <String, String>{};
  final List<String> removed = <String>[];

  @override
  String? getCookie(String key) => _cookies[key];

  @override
  void removeCookie(String key, String path) {
    removed.add('$key:$path');
    _cookies.remove(key);
  }

  @override
  void setCookie(String key, String value, int maxAge, String path) {
    _cookies[key] = value;
  }
}

class _NoopHttpTransport implements HttpTransport {
  @override
  void close() {}

  @override
  Future<HttpResponse> execute(HttpRequest request) async {
    throw UnimplementedError('Noop transport should not be called in tests.');
  }
}

AuthenticatedResponse _response({
  required int statusCode,
  String body = '',
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
