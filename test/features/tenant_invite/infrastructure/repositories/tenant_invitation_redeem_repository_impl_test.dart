import 'dart:async';
import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/tenant_invite/domain/repositories/tenant_invitation_redeem_repository.dart';
import 'package:mugen_ui/features/tenant_invite/infrastructure/repositories/tenant_invitation_redeem_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test(
    'redeemAuthenticated sends expected path/body and maps 204 success',
    () async {
      final fixture = _InviteFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 204)],
      );

      final result = await fixture.repository.redeemAuthenticated(
        tenantId: 'tenant-1',
        invitationId: 'invite-2',
        token: ' token-abc ',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.outcome, InviteRedeemOutcome.success);
      expect(result.data?.statusCode, 204);
      expect(fixture.client.requests, hasLength(1));
      final request = fixture.client.requests.single;
      expect(
        request.path,
        'core/acp/v1/auth/tenants/tenant-1/invitations/invite-2/redeem',
      );
      expect(request.body, <String, dynamic>{'Token': 'token-abc'});
    },
  );

  test('redeemAuthenticated maps 403, 404, and 409 status codes', () async {
    final forbiddenFixture = _InviteFixture(
      handlers: <_AuthHandler>[(_) => _response(statusCode: 403)],
    );
    final forbidden = await forbiddenFixture.repository.redeemAuthenticated(
      tenantId: 'tenant',
      invitationId: 'invite',
      token: 'abc',
    );
    expect(forbidden.isSuccess, isTrue);
    expect(forbidden.data?.outcome, InviteRedeemOutcome.forbidden);

    final notFoundFixture = _InviteFixture(
      handlers: <_AuthHandler>[(_) => _response(statusCode: 404)],
    );
    final notFound = await notFoundFixture.repository.redeemAuthenticated(
      tenantId: 'tenant',
      invitationId: 'invite',
      token: 'abc',
    );
    expect(notFound.isSuccess, isTrue);
    expect(notFound.data?.outcome, InviteRedeemOutcome.notFound);

    final conflictFixture = _InviteFixture(
      handlers: <_AuthHandler>[(_) => _response(statusCode: 409)],
    );
    final conflict = await conflictFixture.repository.redeemAuthenticated(
      tenantId: 'tenant',
      invitationId: 'invite',
      token: 'abc',
    );
    expect(conflict.isSuccess, isTrue);
    expect(conflict.data?.outcome, InviteRedeemOutcome.conflict);
  });

  test(
    'redeemAuthenticated validates token and maps API/network/session errors',
    () async {
      final validationFixture = _InviteFixture();
      final validation = await validationFixture.repository.redeemAuthenticated(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: '   ',
      );
      expect(validation.isFailure, isTrue);
      expect(validation.failure, isA<ValidationFailure>());
      expect(validationFixture.client.requests, isEmpty);

      final apiFixture = _InviteFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
      );
      final api = await apiFixture.repository.redeemAuthenticated(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: 'abc',
      );
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());
      expect((api.failure as ApiFailure).statusCode, 500);

      final sessionFixture = _InviteFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final session = await sessionFixture.repository.redeemAuthenticated(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: 'abc',
      );
      expect(session.isFailure, isTrue);
      expect(session.failure, isA<SessionExpiredFailure>());
      expect(sessionFixture.cookieStore.removed, contains('auth:/'));

      final networkFixture = _InviteFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.redeemAuthenticated(
        tenantId: 'tenant',
        invitationId: 'invite',
        token: 'abc',
      );
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    },
  );
}

class _InviteFixture {
  _InviteFixture({List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    repository = TenantInvitationRedeemRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final TenantInvitationRedeemRepositoryImpl repository;
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
