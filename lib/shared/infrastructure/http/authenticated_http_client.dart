import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class AuthenticatedResponse {
  const AuthenticatedResponse({
    required this.response,
    required this.sessionExpired,
  });

  final HttpResponse response;
  final bool sessionExpired;
}

class AuthenticatedHttpClient {
  AuthenticatedHttpClient({
    required this.httpClient,
    required this.cookieStore,
    required this.refreshPath,
    this.onSessionRefreshed,
  });

  final AcpHttpClient httpClient;
  final CookieStore cookieStore;
  final String refreshPath;
  final void Function(AuthSession session)? onSessionRefreshed;

  Future<AuthenticatedResponse> send(AcpRequest request) async {
    final headers = Map<String, String>.from(request.headers);

    if (request.requiresAuth) {
      final session = parseAuthSession(cookieStore.getCookie('auth'));
      if (session == null) {
        return AuthenticatedResponse(
          response: const HttpResponse(
            statusCode: 401,
            body: '',
            headers: <String, String>{},
          ),
          sessionExpired: true,
        );
      }

      headers['Authorization'] = 'Bearer ${session.accessToken}';
    }

    var response = await httpClient.send(request, headers: headers);

    if (!_shouldRefresh(request, response)) {
      return AuthenticatedResponse(response: response, sessionExpired: false);
    }

    final refreshedSession = await _refreshSession();
    if (refreshedSession == null) {
      cookieStore.removeCookie('auth', '/');
      return AuthenticatedResponse(response: response, sessionExpired: true);
    }

    final retryHeaders = <String, String>{
      ...headers,
      'Authorization': 'Bearer ${refreshedSession.accessToken}',
    };

    response = await httpClient.send(request, headers: retryHeaders);

    final sessionExpired = _shouldRefresh(request, response);
    if (sessionExpired) {
      cookieStore.removeCookie('auth', '/');
    } else {
      _notifySessionRefreshed(refreshedSession);
    }

    return AuthenticatedResponse(
      response: response,
      sessionExpired: sessionExpired,
    );
  }

  bool _shouldRefresh(AcpRequest request, HttpResponse response) {
    if (!request.requiresAuth || !request.handleAuthErrors) {
      return false;
    }

    return response.statusCode == 401;
  }

  Future<AuthSession?> _refreshSession() async {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null || session.refreshToken.isEmpty) {
      return null;
    }

    final refreshRequest = AcpRequest(
      method: HttpMethod.post,
      path: refreshPath,
      requiresAuth: false,
      handleAuthErrors: false,
      headers: const <String, String>{'Content-Type': 'application/json'},
      body: <String, String>{'RefreshToken': session.refreshToken},
    );

    final refreshResponse = await httpClient.send(refreshRequest);
    if (!refreshResponse.isSuccess) {
      return null;
    }

    cookieStore.removeCookie('auth', '/');
    cookieStore.setCookie('auth', refreshResponse.body, 60 * 60 * 24 * 7, '/');

    return parseAuthSession(cookieStore.getCookie('auth'));
  }

  void _notifySessionRefreshed(AuthSession session) {
    try {
      onSessionRefreshed?.call(session);
    } catch (_) {
      // Authentication should not fail because a UI listener failed.
    }
  }
}
