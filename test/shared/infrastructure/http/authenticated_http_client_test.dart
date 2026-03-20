import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test(
    'AuthenticatedHttpClient returns 401 when auth is required and no session exists',
    () async {
      final transport = _QueueTransport(<HttpResponse>[]);
      final client = AuthenticatedHttpClient(
        httpClient: AcpHttpClient(
          baseUrl: 'https://api.example.com',
          transport: transport,
        ),
        cookieStore: createCookieStore(),
        refreshPath: 'core/acp/v1/auth/refresh',
      );

      final response = await client.send(
        AcpRequest(method: HttpMethod.get, path: 'core/acp/v1/Users'),
      );

      expect(response.response.statusCode, 401);
      expect(response.sessionExpired, isTrue);
      expect(transport.requests, isEmpty);
    },
  );

  test('AuthenticatedHttpClient attaches bearer token', () async {
    final transport = _QueueTransport(<HttpResponse>[
      const HttpResponse(
        statusCode: 200,
        body: '{}',
        headers: <String, String>{},
      ),
    ]);
    final cookieStore = createCookieStore();
    cookieStore.setCookie(
      'auth',
      jsonEncode(<String, dynamic>{
        'access_token': 'token-123',
        'refresh_token': 'refresh-123',
        'user_id': 'u1',
      }),
      60,
      '/',
    );

    final client = AuthenticatedHttpClient(
      httpClient: AcpHttpClient(
        baseUrl: 'https://api.example.com',
        transport: transport,
      ),
      cookieStore: cookieStore,
      refreshPath: 'core/acp/v1/auth/refresh',
    );

    final response = await client.send(
      AcpRequest(method: HttpMethod.get, path: 'core/acp/v1/Users'),
    );

    expect(response.response.statusCode, 200);
    expect(transport.requests.length, 1);
    expect(
      transport.requests.first.headers['Authorization'],
      'Bearer token-123',
    );
  });

  test(
    'AuthenticatedHttpClient refreshes token and retries once on 401',
    () async {
      final transport = _QueueTransport(<HttpResponse>[
        const HttpResponse(
          statusCode: 401,
          body: '',
          headers: <String, String>{},
        ),
        HttpResponse(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'access_token': 'new-token',
            'refresh_token': 'new-refresh',
            'user_id': 'u1',
          }),
          headers: const <String, String>{'content-type': 'application/json'},
        ),
        const HttpResponse(
          statusCode: 200,
          body: '{}',
          headers: <String, String>{},
        ),
      ]);
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'old-token',
          'refresh_token': 'old-refresh',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = AuthenticatedHttpClient(
        httpClient: AcpHttpClient(
          baseUrl: 'https://api.example.com',
          transport: transport,
        ),
        cookieStore: cookieStore,
        refreshPath: 'core/acp/v1/auth/refresh',
      );

      final response = await client.send(
        AcpRequest(method: HttpMethod.get, path: 'core/acp/v1/Users'),
      );

      expect(response.response.statusCode, 200);
      expect(response.sessionExpired, isFalse);
      expect(transport.requests.length, 3);
      expect(
        transport.requests[2].headers['Authorization'],
        'Bearer new-token',
      );
    },
  );

  test(
    'AuthenticatedHttpClient flags sessionExpired when refresh fails',
    () async {
      final transport = _QueueTransport(<HttpResponse>[
        const HttpResponse(
          statusCode: 401,
          body: '',
          headers: <String, String>{},
        ),
        const HttpResponse(
          statusCode: 401,
          body: '',
          headers: <String, String>{},
        ),
      ]);
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'old-token',
          'refresh_token': 'old-refresh',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = AuthenticatedHttpClient(
        httpClient: AcpHttpClient(
          baseUrl: 'https://api.example.com',
          transport: transport,
        ),
        cookieStore: cookieStore,
        refreshPath: 'core/acp/v1/auth/refresh',
      );

      final response = await client.send(
        AcpRequest(method: HttpMethod.get, path: 'core/acp/v1/Users'),
      );

      expect(response.response.statusCode, 401);
      expect(response.sessionExpired, isTrue);
      expect(cookieStore.getCookie('auth'), isNull);
    },
  );

  test(
    'AuthenticatedHttpClient flags sessionExpired when retry stays unauthorized',
    () async {
      final transport = _QueueTransport(<HttpResponse>[
        const HttpResponse(
          statusCode: 401,
          body: '',
          headers: <String, String>{},
        ),
        HttpResponse(
          statusCode: 200,
          body: jsonEncode(<String, dynamic>{
            'access_token': 'new-token',
            'refresh_token': 'new-refresh',
            'user_id': 'u1',
          }),
          headers: const <String, String>{'content-type': 'application/json'},
        ),
        const HttpResponse(
          statusCode: 401,
          body: '',
          headers: <String, String>{},
        ),
      ]);
      final cookieStore = createCookieStore();
      cookieStore.setCookie(
        'auth',
        jsonEncode(<String, dynamic>{
          'access_token': 'old-token',
          'refresh_token': 'old-refresh',
          'user_id': 'u1',
        }),
        60,
        '/',
      );

      final client = AuthenticatedHttpClient(
        httpClient: AcpHttpClient(
          baseUrl: 'https://api.example.com',
          transport: transport,
        ),
        cookieStore: cookieStore,
        refreshPath: 'core/acp/v1/auth/refresh',
      );

      final response = await client.send(
        AcpRequest(method: HttpMethod.get, path: 'core/acp/v1/Users'),
      );

      expect(response.response.statusCode, 401);
      expect(response.sessionExpired, isTrue);
      expect(transport.requests.length, 3);
      expect(
        transport.requests[2].headers['Authorization'],
        'Bearer new-token',
      );
      expect(cookieStore.getCookie('auth'), isNull);
    },
  );
}

class _QueueTransport implements HttpTransport {
  _QueueTransport(List<HttpResponse> values) : _responses = List.of(values);

  final List<HttpResponse> _responses;
  final List<HttpRequest> requests = <HttpRequest>[];

  @override
  Future<HttpResponse> execute(HttpRequest request) async {
    requests.add(request);
    return _responses.removeAt(0);
  }

  @override
  void close() {}
}
