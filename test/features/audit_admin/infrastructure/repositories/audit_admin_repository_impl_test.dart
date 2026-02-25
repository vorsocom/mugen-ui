import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/infrastructure/repositories/audit_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('AuditAdminRepositoryImpl fetches', () {
    test('global mode applies non-tenant filter and maps event rows', () async {
      final fixture = _AuditAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': '1',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'ae-1',
                  'RowVersion': '5',
                  'TenantId': null,
                  'ActorId': 'actor-1',
                  'EntitySet': 'Users',
                  'Entity': 'User',
                  'EntityId': 'u-1',
                  'Operation': 'action',
                  'ActionName': 'redact',
                  'OccurredAt': '2026-02-01T10:00:00Z',
                  'Outcome': 'success',
                  'RequestId': 'req-1',
                  'CorrelationId': 'corr-1',
                  'SourcePlugin': 'acp',
                  'ChangedFields': <String>['Name'],
                  'BeforeSnapshot': jsonEncode(<String, dynamic>{'Name': 'A'}),
                  'AfterSnapshot': <String, dynamic>{'Name': 'B'},
                  'Meta': <String, dynamic>{'ip': '127.0.0.1'},
                  'ScopeKey': 'global:users',
                  'ScopeSeq': 7,
                  'PrevEntryHash': 'prev',
                  'EntryHash': 'entry',
                  'HashAlg': 'hmac-sha256',
                  'HashKeyId': 'kid-1',
                  'BeforeSnapshotHash': 'before-hash',
                  'AfterSnapshotHash': 'after-hash',
                  'SealedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                  'RetentionUntil': null,
                  'RedactionDueAt': null,
                  'RedactedAt': null,
                  'RedactionReason': null,
                  'LegalHoldAt': null,
                  'LegalHoldUntil': null,
                  'LegalHoldByUserId': null,
                  'LegalHoldReason': null,
                  'LegalHoldReleasedAt': null,
                  'LegalHoldReleasedByUserId': null,
                  'LegalHoldReleaseReason': null,
                  'TombstonedAt': null,
                  'TombstonedByUserId': null,
                  'TombstoneReason': null,
                  'PurgeDueAt': null,
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchAuditEvents(
        const AuditEventListQuery(
          pageRequest: PageRequest(page: 2, pageSize: 10),
          scopeMode: AuditAdminScopeMode.global,
          searchTerm: "red'",
        ),
      );

      expect(result.isSuccess, isTrue);
      final page = result.data!;
      expect(page.total, 1);
      expect(page.items, hasLength(1));
      final event = page.items.single;
      expect(event.id, 'ae-1');
      expect(event.rowVersion, 5);
      expect(event.tenantId, isNull);
      expect(event.beforeSnapshot?['Name'], 'A');
      expect(event.afterSnapshot?['Name'], 'B');
      expect(event.meta?['ip'], '127.0.0.1');
      expect(event.sealedAt, DateTime.utc(2025, 1, 1));

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/AuditEvents');
      expect(request.queryParameters[r'$skip'], 10);
      expect(request.queryParameters[r'$top'], 10);
      expect(request.queryParameters[r'$orderby'], 'OccurredAt desc');
      final filter = request.queryParameters[r'$filter'] as String;
      expect(filter, contains('TenantId eq null'));
      expect(filter, contains("contains(EntitySet,'red''')"));
    });

    test('tenant mode uses tenant endpoint and tenant id', () async {
      final fixture = _AuditAdminFixture(
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

      final result = await fixture.repository.fetchAuditEvents(
        const AuditEventListQuery(
          pageRequest: PageRequest(page: 1, pageSize: 25),
          scopeMode: AuditAdminScopeMode.tenant,
          tenantId: 'tenant-9',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(
        fixture.client.requests.single.path,
        'core/acp/v1/tenants/tenant-9/AuditEvents',
      );
      expect(
        fixture.client.requests.single.queryParameters[r'$filter'],
        isNull,
      );
    });

    test('fetchTenants maps tenant options', () async {
      final fixture = _AuditAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'tenant-1',
                  'Name': 'Tenant One',
                  'Slug': 'tenant-one',
                  'Status': 'Active',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchTenants(top: 150);

      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(1));
      expect(result.data!.single.id, 'tenant-1');
      expect(result.data!.single.label, 'Tenant One (tenant-one)');

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/Tenants');
      expect(request.queryParameters[r'$top'], 150);
    });
  });

  group('AuditAdminRepositoryImpl action payloads', () {
    test('row actions include RowVersion, Reason, and optional fields', () async {
      final fixture = _AuditAdminFixture(
        handlers: List<_AuthHandler>.filled(
          4,
          (_) => _response(statusCode: 204),
        ),
      );

      await fixture.repository.placeLegalHold(
        AuditPlaceLegalHoldInput(
          eventId: 'ae-1',
          rowVersion: 11,
          reason: 'investigation',
          scopeMode: AuditAdminScopeMode.global,
          legalHoldUntil: DateTime.utc(2026, 3, 1),
        ),
      );
      await fixture.repository.releaseLegalHold(
        const AuditReleaseLegalHoldInput(
          eventId: 'ae-1',
          rowVersion: 12,
          reason: 'release approved',
          scopeMode: AuditAdminScopeMode.tenant,
          tenantId: 'tenant-2',
        ),
      );
      await fixture.repository.redactEvent(
        const AuditRedactInput(
          eventId: 'ae-1',
          rowVersion: 13,
          reason: 'privacy',
          scopeMode: AuditAdminScopeMode.global,
        ),
      );
      await fixture.repository.tombstoneEvent(
        const AuditTombstoneInput(
          eventId: 'ae-1',
          rowVersion: 14,
          reason: 'expired',
          purgeAfterDays: 30,
          scopeMode: AuditAdminScopeMode.tenant,
          tenantId: 'tenant-2',
        ),
      );

      expect(fixture.client.requests, hasLength(4));
      expect(
        fixture.client.requests[0].path,
        r'core/acp/v1/AuditEvents/ae-1/$action/place_legal_hold',
      );
      expect(fixture.client.requests[0].body, <String, dynamic>{
        'RowVersion': 11,
        'Reason': 'investigation',
        'LegalHoldUntil': '2026-03-01T00:00:00.000Z',
      });

      expect(
        fixture.client.requests[1].path,
        r'core/acp/v1/tenants/tenant-2/AuditEvents/ae-1/$action/release_legal_hold',
      );
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'RowVersion': 12,
        'Reason': 'release approved',
      });

      expect(
        fixture.client.requests[2].path,
        r'core/acp/v1/AuditEvents/ae-1/$action/redact',
      );
      expect(fixture.client.requests[2].body, <String, dynamic>{
        'RowVersion': 13,
        'Reason': 'privacy',
      });

      expect(
        fixture.client.requests[3].path,
        r'core/acp/v1/tenants/tenant-2/AuditEvents/ae-1/$action/tombstone',
      );
      expect(fixture.client.requests[3].body, <String, dynamic>{
        'RowVersion': 14,
        'Reason': 'expired',
        'PurgeAfterDays': 30,
      });
    });
  });

  group('AuditAdminRepositoryImpl set-action summaries', () {
    test('run_lifecycle defaults DryRun true and parses summary', () async {
      final fixture = _AuditAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'DryRun': true,
              'Now': '2026-03-01T00:00:00Z',
              'BatchSize': 100,
              'MaxBatches': 10,
              'Phases': <String, dynamic>{
                'seal_backlog': <String, dynamic>{
                  'RowsSealed': 5,
                  'RemainingCount': 11,
                  'Batches': 1,
                },
              },
              'TotalProcessed': 5,
            }),
          ),
        ],
      );

      final result = await fixture.repository.runLifecycle(
        const AuditRunLifecycleInput(scopeMode: AuditAdminScopeMode.global),
      );

      expect(result.isSuccess, isTrue);
      expect(result.data!.dryRun, isTrue);
      expect(result.data!.totalProcessed, 5);
      expect(result.data!.phases['seal_backlog']!.rowsProcessed, 5);

      final request = fixture.client.requests.single;
      expect(request.path, r'core/acp/v1/AuditEvents/$action/run_lifecycle');
      expect(request.body, <String, dynamic>{'DryRun': true});
    });

    test('verify_chain and seal_backlog parse typed payloads', () async {
      final fixture = _AuditAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'IsValid': false,
              'CheckedRows': 7,
              'MismatchCount': 1,
              'Mismatches': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'ae-99',
                  'ScopeKey': 'tenant:9',
                  'ScopeSeq': '42',
                  'Reasons': <String>['entry_hash_mismatch'],
                },
              ],
            }),
          ),
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'RowsSealed': 8,
              'RemainingCount': 2,
              'Batches': 3,
              'BatchSize': 25,
              'MaxBatches': 4,
            }),
          ),
        ],
      );

      final verify = await fixture.repository.verifyChain(
        const AuditVerifyChainInput(
          scopeMode: AuditAdminScopeMode.tenant,
          tenantId: 'tenant-9',
          maxRows: 77,
          requireClean: true,
        ),
      );
      final seal = await fixture.repository.sealBacklog(
        const AuditSealBacklogInput(
          scopeMode: AuditAdminScopeMode.tenant,
          tenantId: 'tenant-9',
          batchSize: 25,
          maxBatches: 4,
        ),
      );

      expect(verify.isSuccess, isTrue);
      expect(verify.data!.isValid, isFalse);
      expect(verify.data!.mismatchCount, 1);
      expect(verify.data!.mismatches.single.id, 'ae-99');
      expect(verify.data!.mismatches.single.scopeSeq, 42);

      expect(seal.isSuccess, isTrue);
      expect(seal.data!.rowsSealed, 8);
      expect(seal.data!.remainingCount, 2);
      expect(seal.data!.batchSize, 25);
      expect(seal.data!.maxBatches, 4);

      expect(
        fixture.client.requests[0].path,
        r'core/acp/v1/tenants/tenant-9/AuditEvents/$action/verify_chain',
      );
      expect(fixture.client.requests[0].body, <String, dynamic>{
        'RequireClean': true,
        'MaxRows': 77,
      });
      expect(
        fixture.client.requests[1].path,
        r'core/acp/v1/tenants/tenant-9/AuditEvents/$action/seal_backlog',
      );
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'BatchSize': 25,
        'MaxBatches': 4,
      });
    });
  });

  group('AuditAdminRepositoryImpl failures', () {
    test('session-expired clears auth cookie and returns failure', () async {
      final fixture = _AuditAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.fetchAuditEvents(
        const AuditEventListQuery(
          pageRequest: PageRequest(page: 1, pageSize: 10),
          scopeMode: AuditAdminScopeMode.global,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('tenant scope without tenant id fails validation', () async {
      final fixture = _AuditAdminFixture();
      final result = await fixture.repository.fetchAuditEvents(
        const AuditEventListQuery(
          pageRequest: PageRequest(page: 1, pageSize: 10),
          scopeMode: AuditAdminScopeMode.tenant,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
      expect(fixture.client.requests, isEmpty);
    });
  });
}

class _AuditAdminFixture {
  _AuditAdminFixture({List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    repository = AuditAdminRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final AuditAdminRepositoryImpl repository;
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
