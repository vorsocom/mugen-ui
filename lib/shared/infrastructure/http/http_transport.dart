import 'dart:async';

import 'package:http/http.dart' as http;

enum HttpMethod { get, post, patch, put, delete }

class HttpRequest {
  HttpRequest({
    required this.method,
    required this.uri,
    Map<String, String>? headers,
    this.body = '',
  }) : headers = Map<String, String>.from(headers ?? const <String, String>{});

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final String body;

  HttpRequest copyWith({
    HttpMethod? method,
    Uri? uri,
    Map<String, String>? headers,
    String? body,
  }) {
    return HttpRequest(
      method: method ?? this.method,
      uri: uri ?? this.uri,
      headers: headers ?? this.headers,
      body: body ?? this.body,
    );
  }
}

class HttpResponse {
  const HttpResponse({
    required this.statusCode,
    required this.body,
    required this.headers,
  });

  final int statusCode;
  final String body;
  final Map<String, String> headers;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract class HttpTransport {
  Future<HttpResponse> execute(HttpRequest request);
  void close();
}

class HttpClientTransport implements HttpTransport {
  HttpClientTransport({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final http.Client _client;
  final Duration requestTimeout;

  @override
  Future<HttpResponse> execute(HttpRequest request) async {
    final response = await _dispatch(request).timeout(requestTimeout);
    return HttpResponse(
      statusCode: response.statusCode,
      body: response.body,
      headers: response.headers,
    );
  }

  Future<http.Response> _dispatch(HttpRequest request) {
    switch (request.method) {
      case HttpMethod.get:
        return _client.get(request.uri, headers: request.headers);
      case HttpMethod.post:
        return _client.post(
          request.uri,
          headers: request.headers,
          body: request.body,
        );
      case HttpMethod.patch:
        return _client.patch(
          request.uri,
          headers: request.headers,
          body: request.body,
        );
      case HttpMethod.put:
        return _client.put(
          request.uri,
          headers: request.headers,
          body: request.body,
        );
      case HttpMethod.delete:
        return _client.delete(
          request.uri,
          headers: request.headers,
          body: request.body,
        );
    }
  }

  @override
  void close() {
    _client.close();
  }
}
