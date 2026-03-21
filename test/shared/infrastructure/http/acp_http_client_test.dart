import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test('AcpRequest.hasBody reflects whether a body is provided', () {
    final withoutBody = AcpRequest(method: HttpMethod.get, path: '/users');
    final withBody = AcpRequest(
      method: HttpMethod.post,
      path: '/users',
      body: <String, dynamic>{'name': 'alice'},
    );

    expect(withoutBody.hasBody, isFalse);
    expect(withBody.hasBody, isTrue);
  });

  test(
    'AcpHttpClient encodes body and applies default content-type header',
    () async {
      final transport = _RecordingTransport();
      final client = AcpHttpClient(
        baseUrl: 'https://api.example.com',
        transport: transport,
      );

      await client.send(
        AcpRequest(
          method: HttpMethod.post,
          path: 'core/acp/v1/auth/login',
          body: <String, dynamic>{'UserName': 'alice'},
        ),
      );

      final request = transport.requests.single;
      expect(
        request.uri.toString(),
        'https://api.example.com/core/acp/v1/auth/login',
      );
      expect(request.headers['Content-Type'], 'application/json');
      expect(request.body, jsonEncode(<String, dynamic>{'UserName': 'alice'}));
    },
  );

  test('AcpHttpClient normalizes base/path and query parameters', () async {
    final transport = _RecordingTransport();
    final client = AcpHttpClient(
      baseUrl: 'https://api.example.com/',
      transport: transport,
    );

    await client.send(
      AcpRequest(
        method: HttpMethod.get,
        path: '/core/acp/v1/Users',
        headers: const <String, String>{'content-type': 'application/custom'},
        queryParameters: <String, dynamic>{
          'roles': <String>['admin', 'user'],
          'page': 2,
          'skip': null,
        },
      ),
    );

    final request = transport.requests.single;
    expect(request.uri.path, '/core/acp/v1/Users');
    expect(request.uri.queryParameters['roles'], 'admin,user');
    expect(request.uri.queryParameters['page'], '2');
    expect(request.uri.queryParameters.containsKey('skip'), isFalse);
    expect(request.headers['content-type'], 'application/custom');
    expect(request.headers.containsKey('Content-Type'), isFalse);
  });
}

class _RecordingTransport implements HttpTransport {
  final List<HttpRequest> requests = <HttpRequest>[];

  @override
  Future<HttpResponse> execute(HttpRequest request) async {
    requests.add(request);
    return const HttpResponse(
      statusCode: 200,
      body: '{}',
      headers: <String, String>{},
    );
  }

  @override
  void close() {}
}
