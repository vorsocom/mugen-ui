import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/infrastructure/repositories/human_handoff_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test('fetchTenants maps tenant options', () async {
    final fixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'value': <Map<String, dynamic>>[
              <String, dynamic>{
                'Id': 'reserved-global',
                'Name': 'ACP Global Tenant',
                'Slug': 'reserved-global',
              },
              <String, dynamic>{
                'Id': 'global',
                'Name': 'Global',
                'Slug': 'global',
              },
              <String, dynamic>{
                'Id': 'tenant-1',
                'Name': 'Tenant One',
                'Slug': 'tenant-one',
              },
            ],
          }),
        ),
      ],
    );

    final result = await fixture.repository.fetchTenants(top: 50);

    expect(result.isSuccess, isTrue);
    expect(result.data!.single.label, 'Tenant One (tenant-one)');
    expect(fixture.client.requests.single.path, 'core/acp/v1/Tenants');
    expect(fixture.client.requests.single.queryParameters[r'$top'], 50);
  });

  test(
    'fetchSessions applies tenant path, filters, paging, and maps rows',
    () async {
      final fixture = _HumanHandoffFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': '1',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'session-1',
                  'TenantId': 'tenant-1',
                  'ScopeKey': 'web:room:user',
                  'Platform': 'web',
                  'ChannelId': 'web',
                  'RoomId': 'room-1',
                  'SenderId': 'sender-1',
                  'ConversationId': 'conversation-1',
                  'ClientProfileId': null,
                  'ServiceRouteKey': 'support',
                  'Status': 'active',
                  'OwnerUserId': 'agent-1',
                  'Reason': 'agent handoff',
                  'ActivatedAt': '2026-06-01T12:00:00Z',
                  'DeactivatedAt': null,
                  'LastHumanReplyAt': '2026-06-01T12:05:00Z',
                  'LastUserMessageAt': '2026-06-01T12:06:00Z',
                  'LastTranscriptSequenceNo': 7,
                  'LastDeliveryStatus': 'failed',
                  'LastDeliveryError': 'delivery failed',
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchSessions(
        const HumanHandoffSessionListQuery(
          tenantId: 'tenant-1',
          pageRequest: PageRequest(page: 2, pageSize: 15),
          status: 'active',
          platform: "we'b",
          serviceRouteKey: 'support',
          ownerUserId: 'agent-1',
        ),
      );

      expect(result.isSuccess, isTrue);
      final page = result.data!;
      expect(page.total, 1);
      expect(page.items.single.hasDeliveryFailure, isTrue);
      expect(page.items.single.hasNewUserActivity, isTrue);
      expect(page.items.single.lastTranscriptSequenceNo, 7);
      expect(page.items.single.activatedAt, DateTime.utc(2026, 6, 1, 12));

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/tenants/tenant-1/HumanHandoffSessions');
      expect(request.queryParameters[r'$skip'], 15);
      expect(request.queryParameters[r'$top'], 15);
      expect(
        request.queryParameters[r'$orderby'],
        'LastUserMessageAt desc, LastHumanReplyAt desc, ActivatedAt desc',
      );
      expect(
        request.queryParameters[r'$filter'],
        "Status eq 'active' and Platform eq 'we''b' and "
        "ServiceRouteKey eq 'support' and OwnerUserId eq 'agent-1'",
      );
    },
  );

  test('listTranscript posts action payload and sorts by sequence', () async {
    final fixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'Items': <Map<String, dynamic>>[
              <String, dynamic>{
                'SequenceNo': 2,
                'Role': 'assistant',
                'Content': <String, dynamic>{'text': 'structured'},
                'MessageId': 'm-2',
                'TraceId': 't-2',
                'Source': 'human_handoff',
                'OccurredAt': '2026-06-01T12:01:00Z',
              },
              <String, dynamic>{
                'SequenceNo': 1,
                'Role': 'user',
                'Content': 'hello',
                'MessageId': 'm-1',
                'TraceId': 't-1',
                'Source': 'human_handoff_user_turn',
                'OccurredAt': '2026-06-01T12:00:00Z',
              },
            ],
            'Count': 2,
            'LatestSequenceNo': 2,
            'HasMore': false,
          }),
        ),
      ],
    );

    final result = await fixture.repository.listTranscript(
      const HumanHandoffTranscriptQuery(
        tenantId: 'tenant-1',
        sessionId: 'session-1',
        limit: 80,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data!.items.first.sequenceNo, 1);
    expect(result.data!.items.last.isHumanReply, isTrue);
    expect(result.data!.items.last.content, isA<Map<String, dynamic>>());
    expect(result.data!.latestSequenceNo, 2);
    expect(result.data!.hasMore, isFalse);
    final request = fixture.client.requests.single;
    expect(
      request.path,
      r'core/acp/v1/tenants/tenant-1/HumanHandoffSessions/session-1/$action/list_transcript',
    );
    expect(request.body, <String, dynamic>{'Limit': 80});
  });

  test('listTranscript supports incremental transcript cursor', () async {
    final fixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'Items': <Map<String, dynamic>>[
              <String, dynamic>{
                'SequenceNo': 3,
                'Role': 'user',
                'Content': 'new turn',
                'Source': 'human_handoff_user_turn',
              },
            ],
            'Count': 1,
            'LatestSequenceNo': 3,
            'HasMore': false,
          }),
        ),
      ],
    );

    final result = await fixture.repository.listTranscript(
      const HumanHandoffTranscriptQuery(
        tenantId: 'tenant-1',
        sessionId: 'session-1',
        limit: 80,
        afterSequenceNo: 2,
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data!.items.single.sequenceNo, 3);
    expect(fixture.client.requests.single.body, <String, dynamic>{
      'Limit': 80,
      'AfterSequenceNo': 2,
    });
  });

  test(
    'streamEvents opens tenant SSE stream and maps handoff events',
    () async {
      final cookieStore = _MemoryCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'access-token',
          'refresh_token': 'refresh-token',
          'user_id': 'agent-1',
        }),
        60,
        '/',
      );
      final httpClient =
          _QueueHttpClient(<http.StreamedResponse Function(http.BaseRequest)>[
            (_) => _streamedResponse(
              statusCode: 200,
              body: '''
id: tenant-1:event-1
event: handoff.transcript_appended
data: {"tenant_id":"tenant-1","session_id":"session-1","event_type":"handoff.transcript_appended","sequence_no":3,"occurred_at":"2026-06-01T12:02:00Z"}

''',
            ),
          ]);
      final fixture = _HumanHandoffFixture(
        cookieStore: cookieStore,
        httpClient: httpClient,
      );

      final events = await fixture.repository
          .streamEvents(
            const HumanHandoffEventStreamQuery(
              tenantId: 'tenant-1',
              lastEventId: 'tenant-1:event-0',
              sessionId: 'session-1',
            ),
          )
          .toList();

      expect(events.single.isSuccess, isTrue);
      final event = events.single.data!;
      expect(event.eventId, 'tenant-1:event-1');
      expect(event.eventType, 'handoff.transcript_appended');
      expect(event.sessionId, 'session-1');
      expect(event.sequenceNo, 3);
      expect(event.occurredAt, DateTime.utc(2026, 6, 1, 12, 2));
      final request = httpClient.requests.single;
      expect(
        request.url.path,
        '/api/core/acp/v1/tenants/tenant-1/HumanHandoffEvents/stream',
      );
      expect(request.url.queryParameters['last_event_id'], 'tenant-1:event-0');
      expect(request.url.queryParameters['session_id'], 'session-1');
      expect(request.headers['Authorization'], 'Bearer access-token');
      expect(request.headers['Last-Event-ID'], 'tenant-1:event-0');
    },
  );

  test('sendReply sends PascalCase payload and maps delivery statuses', () async {
    final fixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'Decision': 'replied',
            'DeliveryStatus': 'sent',
            'DeliveryError': null,
          }),
        ),
        (_) => _response(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'Decision': 'replied',
            'DeliveryStatus': 'failed',
            'DeliveryError': 'RuntimeError: failed',
          }),
        ),
      ],
    );

    final sent = await fixture.repository.sendReply(
      const HumanHandoffReplyInput(
        tenantId: 'tenant-1',
        sessionId: 'session-1',
        content: ' hello ',
        messageId: 'ui-msg-1',
        traceId: 'trace-1',
        operatorDisplayName: 'Support',
      ),
    );
    final failed = await fixture.repository.sendReply(
      const HumanHandoffReplyInput(
        tenantId: 'tenant-1',
        sessionId: 'session-1',
        content: 'retry',
        messageId: 'ui-msg-1',
      ),
    );

    expect(sent.data!.isSent, isTrue);
    expect(failed.data!.isFailed, isTrue);
    expect(failed.data!.deliveryError, 'RuntimeError: failed');
    expect(
      fixture.client.requests.first.path,
      r'core/acp/v1/tenants/tenant-1/HumanHandoffSessions/session-1/$action/human_reply',
    );
    expect(fixture.client.requests.first.body, <String, dynamic>{
      'Content': 'hello',
      'MessageId': 'ui-msg-1',
      'TraceId': 'trace-1',
      'Metadata': <String, dynamic>{'operator_display_name': 'Support'},
    });
    expect(fixture.client.requests.last.body, <String, dynamic>{
      'Content': 'retry',
      'MessageId': 'ui-msg-1',
    });
  });

  test('deactivate posts optional release reason', () async {
    final fixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 200, body: '{"Decision":"inactive"}'),
      ],
    );

    final result = await fixture.repository.deactivate(
      const HumanHandoffDeactivateInput(
        tenantId: 'tenant-1',
        sessionId: 'session-1',
        reason: 'resolved',
      ),
    );

    expect(result.isSuccess, isTrue);
    expect(
      fixture.client.requests.single.path,
      r'core/acp/v1/tenants/tenant-1/HumanHandoffSessions/session-1/$action/deactivate_handoff',
    );
    expect(fixture.client.requests.single.body, <String, dynamic>{
      'Reason': 'resolved',
    });
  });

  test('validation and HTTP failures are mapped', () async {
    final validationFixture = _HumanHandoffFixture();
    final validation = await validationFixture.repository.fetchSessions(
      const HumanHandoffSessionListQuery(
        tenantId: '',
        pageRequest: PageRequest(page: 1, pageSize: 15),
      ),
    );
    expect(validation.failure, isA<ValidationFailure>());
    expect(validationFixture.client.requests, isEmpty);

    final sessionFixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(statusCode: 401, sessionExpired: true),
      ],
    );
    final sessionExpired = await sessionFixture.repository.fetchSessions(
      const HumanHandoffSessionListQuery(
        tenantId: 'tenant-1',
        pageRequest: PageRequest(page: 1, pageSize: 15),
      ),
    );
    expect(sessionExpired.failure, isA<SessionExpiredFailure>());

    final apiFixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 500,
          body: jsonEncode(<String, dynamic>{'message': 'boom'}),
        ),
      ],
    );
    final apiFailure = await apiFixture.repository.fetchSessions(
      const HumanHandoffSessionListQuery(
        tenantId: 'tenant-1',
        pageRequest: PageRequest(page: 1, pageSize: 15),
      ),
    );
    expect(apiFailure.failure, isA<ApiFailure>());
    expect(apiFailure.failure!.message, 'boom');

    final htmlFixture = _HumanHandoffFixture(
      handlers: <_AuthHandler>[
        (_) => _response(
          statusCode: 403,
          body: '''
<!doctype html>
<html lang=en>
<title>403 Forbidden</title>
<h1>Forbidden</h1>
<p>You don&#39;t have the permission to access the requested resource.</p>
''',
        ),
      ],
    );
    final htmlFailure = await htmlFixture.repository.fetchSessions(
      const HumanHandoffSessionListQuery(
        tenantId: 'tenant-1',
        pageRequest: PageRequest(page: 1, pageSize: 15),
      ),
    );
    expect(htmlFailure.failure, isA<ApiFailure>());
    expect(
      htmlFailure.failure!.message,
      "403 Forbidden: You don't have the permission to access "
      'the requested resource.',
    );
  });
}

class _HumanHandoffFixture {
  _HumanHandoffFixture({
    List<_AuthHandler>? handlers,
    CookieStore? cookieStore,
    http.Client? httpClient,
  }) : cookieStore = cookieStore ?? _MemoryCookieStore(),
       client = _QueueAuthenticatedHttpClient(
         handlers ?? const <_AuthHandler>[],
       ) {
    repository = HumanHandoffRepositoryImpl(
      appConfig: AppConfig.defaults(),
      authenticatedHttpClient: client,
      cookieStore: this.cookieStore,
      httpClient: httpClient,
    );
  }

  final CookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final HumanHandoffRepositoryImpl repository;
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

  @override
  String? getCookie(String key) => _cookies[key];

  @override
  void removeCookie(String key, String path) {
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

class _QueueHttpClient extends http.BaseClient {
  _QueueHttpClient(this.handlers);

  final List<http.StreamedResponse Function(http.BaseRequest)> handlers;
  final List<http.BaseRequest> requests = <http.BaseRequest>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requests.add(request);
    if (handlers.isEmpty) {
      throw StateError('No queued response for request: ${request.url}');
    }
    return handlers.removeAt(0)(request);
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

http.StreamedResponse _streamedResponse({
  required int statusCode,
  String body = '',
  Map<String, String> headers = const <String, String>{},
}) {
  return http.StreamedResponse(
    Stream<List<int>>.fromIterable(<List<int>>[utf8.encode(body)]),
    statusCode,
    headers: headers,
  );
}
