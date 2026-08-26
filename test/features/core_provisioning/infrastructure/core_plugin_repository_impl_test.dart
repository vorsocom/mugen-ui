import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/core_provisioning/infrastructure/repositories/core_plugin_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test('fetchStatus maps registered extension data and path', () async {
    final fixture = _Fixture(<_Handler>[
      (_) => _response(
        200,
        body: jsonEncode(<String, dynamic>{
          'token': 'core.fw.ops_sla',
          'available': '1',
          'status': 'registered',
          'reason': 'ready',
        }),
      ),
      (_) => _response(
        200,
        body: jsonEncode(<String, dynamic>{
          'available': true,
          'status': 'registered',
        }),
      ),
      (_) => _response(
        200,
        body: jsonEncode(<String, dynamic>{
          'available': 'false',
          'status': 'disabled',
        }),
      ),
    ]);

    final result = await fixture.repository.fetchStatus('core.fw.ops_sla');
    final fallback = await fixture.repository.fetchStatus('fallback-token');
    final disabled = await fixture.repository.fetchStatus('disabled-token');

    expect(result.isSuccess, isTrue);
    expect(result.data!.token, 'core.fw.ops_sla');
    expect(result.data!.available, isTrue);
    expect(result.data!.reason, 'ready');
    expect(fallback.data!.token, 'fallback-token');
    expect(disabled.data!.available, isFalse);
    expect(
      fixture.client.requests.first.path,
      'core/acp/v1/runtime/extensions/core.fw.ops_sla',
    );
  });

  test('fetchStatus maps malformed, auth, API, and network failures', () async {
    final fixture = _Fixture(<_Handler>[
      (_) => _response(200, body: '[]'),
      (_) => _response(200, body: '{bad json'),
      (_) => _response(200, sessionExpired: true),
      (_) => _response(401),
      (_) => _response(403, body: '{"message":"forbidden"}'),
      (_) => throw StateError('offline'),
    ]);

    final malformed = await fixture.repository.fetchStatus('one');
    final invalidJson = await fixture.repository.fetchStatus('two');
    final expired = await fixture.repository.fetchStatus('three');
    final unauthorized = await fixture.repository.fetchStatus('four');
    final forbidden = await fixture.repository.fetchStatus('five');
    final network = await fixture.repository.fetchStatus('six');

    expect(malformed.failure, isA<UnexpectedFailure>());
    expect(invalidJson.failure, isA<UnexpectedFailure>());
    expect(expired.failure, isA<SessionExpiredFailure>());
    expect(unauthorized.failure, isA<UnauthorizedFailure>());
    expect(
      forbidden.failure,
      isA<ApiFailure>()
          .having((failure) => failure.statusCode, 'status', 403)
          .having((failure) => failure.message, 'message', 'forbidden'),
    );
    expect(network.failure, isA<NetworkFailure>());
  });
}

class _Fixture {
  _Fixture(List<_Handler> handlers)
    : client = _QueueAuthenticatedHttpClient(handlers) {
    repository = CorePluginRepositoryImpl(
      appConfig: AppConfig.defaults(),
      authenticatedHttpClient: client,
    );
  }

  final _QueueAuthenticatedHttpClient client;
  late final CorePluginRepositoryImpl repository;
}

typedef _Handler = FutureOr<AuthenticatedResponse> Function(AcpRequest);

class _QueueAuthenticatedHttpClient extends AuthenticatedHttpClient {
  _QueueAuthenticatedHttpClient(List<_Handler> handlers)
    : _handlers = Queue<_Handler>.from(handlers),
      super(
        httpClient: AcpHttpClient(
          baseUrl: 'https://example.com/api',
          transport: _NoopHttpTransport(),
        ),
        cookieStore: _MemoryCookieStore(),
        refreshPath: 'core/acp/v1/auth/refresh',
      );

  final Queue<_Handler> _handlers;
  final List<AcpRequest> requests = <AcpRequest>[];

  @override
  Future<AuthenticatedResponse> send(AcpRequest request) async {
    requests.add(request);
    return await _handlers.removeFirst()(request);
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
  Future<HttpResponse> execute(HttpRequest request) {
    throw UnimplementedError();
  }
}

AuthenticatedResponse _response(
  int statusCode, {
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
