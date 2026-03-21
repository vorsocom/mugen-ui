import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  test('HttpRequest.copyWith overrides provided fields', () {
    final original = HttpRequest(
      method: HttpMethod.get,
      uri: Uri.parse('https://example.com/original'),
      headers: const <String, String>{'x-test': '1'},
      body: 'original',
    );

    final updated = original.copyWith(
      method: HttpMethod.post,
      uri: Uri.parse('https://example.com/updated'),
      headers: const <String, String>{'x-updated': '2'},
      body: 'updated',
    );

    expect(updated.method, HttpMethod.post);
    expect(updated.uri.path, '/updated');
    expect(updated.headers, <String, String>{'x-updated': '2'});
    expect(updated.body, 'updated');

    final unchanged = original.copyWith();
    expect(unchanged.method, HttpMethod.get);
    expect(unchanged.uri.path, '/original');
    expect(unchanged.headers, <String, String>{'x-test': '1'});
    expect(unchanged.body, 'original');
  });

  test('HttpResponse.isSuccess is true only for 2xx status codes', () {
    expect(
      const HttpResponse(
        statusCode: 199,
        body: '',
        headers: <String, String>{},
      ).isSuccess,
      isFalse,
    );
    expect(
      const HttpResponse(
        statusCode: 200,
        body: '',
        headers: <String, String>{},
      ).isSuccess,
      isTrue,
    );
    expect(
      const HttpResponse(
        statusCode: 299,
        body: '',
        headers: <String, String>{},
      ).isSuccess,
      isTrue,
    );
    expect(
      const HttpResponse(
        statusCode: 300,
        body: '',
        headers: <String, String>{},
      ).isSuccess,
      isFalse,
    );
  });

  test('HttpClientTransport dispatches all supported methods', () async {
    final client = _RecordingClient(<String, http.Response>{
      'GET': http.Response(
        'get',
        200,
        headers: const <String, String>{'x': 'g'},
      ),
      'POST': http.Response(
        'post',
        201,
        headers: const <String, String>{'x': 'p'},
      ),
      'PATCH': http.Response(
        'patch',
        202,
        headers: const <String, String>{'x': 'pa'},
      ),
      'PUT': http.Response(
        'put',
        203,
        headers: const <String, String>{'x': 'pu'},
      ),
      'DELETE': http.Response(
        'delete',
        204,
        headers: const <String, String>{'x': 'd'},
      ),
    });
    final transport = HttpClientTransport(client: client);

    final requests = <HttpMethod, String>{
      HttpMethod.get: 'get',
      HttpMethod.post: 'post',
      HttpMethod.patch: 'patch',
      HttpMethod.put: 'put',
      HttpMethod.delete: 'delete',
    };

    for (final entry in requests.entries) {
      final response = await transport.execute(
        HttpRequest(
          method: entry.key,
          uri: Uri.parse('https://example.com/${entry.value}'),
          headers: const <String, String>{'authorization': 'Bearer token'},
          body: 'payload-${entry.value}',
        ),
      );

      expect(response.body, entry.value);
      expect(response.headers['x'], isNotNull);
    }

    expect(client.requestMethods, <String>[
      'GET',
      'POST',
      'PATCH',
      'PUT',
      'DELETE',
    ]);
    expect(client.requestBodies['POST'], 'payload-post');
    expect(client.requestBodies['PATCH'], 'payload-patch');
    expect(client.requestBodies['PUT'], 'payload-put');
    expect(client.requestBodies['DELETE'], 'payload-delete');

    transport.close();
    expect(client.closed, isTrue);
  });

  test('HttpClientTransport.execute applies request timeout', () async {
    final client = _DelayedClient(
      delay: const Duration(milliseconds: 30),
      response: http.Response('{}', 200),
    );
    final transport = HttpClientTransport(
      client: client,
      requestTimeout: const Duration(milliseconds: 1),
    );

    await expectLater(
      transport.execute(
        HttpRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://example.com/timeout'),
        ),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

class _RecordingClient extends http.BaseClient {
  _RecordingClient(this._responsesByMethod);

  final Map<String, http.Response> _responsesByMethod;
  final List<String> requestMethods = <String>[];
  final Map<String, String> requestBodies = <String, String>{};
  bool closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestMethods.add(request.method);
    if (request is http.Request) {
      requestBodies[request.method] = request.body;
    }

    final response =
        _responsesByMethod[request.method] ?? http.Response('', 500);
    return http.StreamedResponse(
      Stream<List<int>>.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }

  @override
  void close() {
    closed = true;
    super.close();
  }
}

class _DelayedClient extends http.BaseClient {
  _DelayedClient({required this.delay, required this.response});

  final Duration delay;
  final http.Response response;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    await Future<void>.delayed(delay);
    return http.StreamedResponse(
      Stream<List<int>>.value(Uint8List.fromList(response.bodyBytes)),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}
