import 'dart:convert';

import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class AcpRequest {
  AcpRequest({
    required this.method,
    required this.path,
    this.body,
    Map<String, String>? headers,
    Map<String, dynamic>? queryParameters,
    this.requiresAuth = true,
    this.handleAuthErrors = true,
  }) : headers = Map<String, String>.from(headers ?? const <String, String>{}),
       queryParameters = Map<String, dynamic>.from(
         queryParameters ?? const <String, dynamic>{},
       );

  final HttpMethod method;
  final String path;
  final Object? body;
  final Map<String, String> headers;
  final Map<String, dynamic> queryParameters;
  final bool requiresAuth;
  final bool handleAuthErrors;

  bool get hasBody => body != null;
}

class AcpHttpClient {
  AcpHttpClient({required this.baseUrl, required HttpTransport transport})
    : _transport = transport;

  final String baseUrl;
  final HttpTransport _transport;

  Future<HttpResponse> send(
    AcpRequest request, {
    Map<String, String>? headers,
  }) {
    final requestUri = _buildUri(request.path, request.queryParameters);
    final mergedHeaders = <String, String>{...request.headers, ...?headers};

    final body = _encodeBody(request.body);
    if (body.isNotEmpty && !_hasHeader(mergedHeaders, 'Content-Type')) {
      mergedHeaders['Content-Type'] = 'application/json';
    }

    final httpRequest = HttpRequest(
      method: request.method,
      uri: requestUri,
      headers: mergedHeaders,
      body: body,
    );

    return _transport.execute(httpRequest);
  }

  Uri _buildUri(String path, Map<String, dynamic> queryParameters) {
    final sanitizedBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    var sanitizedPath = path;
    if (sanitizedPath.startsWith('/')) {
      sanitizedPath = sanitizedPath.substring(1);
    }

    var uri = Uri.parse('$sanitizedBase/$sanitizedPath');
    final normalizedQuery = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value == null) {
        return;
      }

      if (value is Iterable) {
        normalizedQuery[key] = value.join(',');
      } else {
        normalizedQuery[key] = value.toString();
      }
    });

    if (normalizedQuery.isNotEmpty) {
      uri = uri.replace(queryParameters: normalizedQuery);
    }

    return uri;
  }

  bool _hasHeader(Map<String, String> headers, String key) {
    return headers.keys.any((h) => h.toLowerCase() == key.toLowerCase());
  }

  String _encodeBody(Object? body) {
    if (body == null) {
      return '';
    }

    if (body is String) {
      return body;
    }

    return jsonEncode(body);
  }
}
