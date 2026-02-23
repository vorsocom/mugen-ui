import 'dart:convert';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/infrastructure/auth/auth_cookie_codec.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl({
    required this.appConfig,
    required this.cookieStore,
    required this.authenticatedHttpClient,
  });

  final AppConfig appConfig;
  final CookieStore cookieStore;
  final AuthenticatedHttpClient authenticatedHttpClient;

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.isEmpty) {
      return const Result<AuthSession>.failure(
        ValidationFailure('Username and password are required.'),
      );
    }

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: appConfig.api.endpoints.authLogin,
          requiresAuth: false,
          handleAuthErrors: false,
          body: <String, String>{'Username': username, 'Password': password},
        ),
      );

      if (!response.response.isSuccess) {
        return Result<AuthSession>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
      }

      cookieStore.removeCookie('auth', '/');
      cookieStore.setCookie(
        'auth',
        response.response.body,
        60 * 60 * 24 * 7,
        '/',
      );

      final session = parseAuthSession(cookieStore.getCookie('auth'));
      if (session == null) {
        return const Result<AuthSession>.failure(
          UnexpectedFailure('Login succeeded but auth cookie is invalid.'),
        );
      }

      return Result<AuthSession>.success(session);
    } catch (_) {
      return const Result<AuthSession>.failure(
        NetworkFailure('Network error.'),
      );
    }
  }

  @override
  Future<Result<void>> logout() async {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null || session.refreshToken.isEmpty) {
      cookieStore.removeCookie('auth', '/');
      return const Result<void>.success(null);
    }

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: appConfig.api.endpoints.authLogout,
          requiresAuth: true,
          handleAuthErrors: true,
          body: <String, String>{'RefreshToken': session.refreshToken},
        ),
      );

      final statusCode = response.response.statusCode;
      if ((statusCode >= 200 && statusCode < 300) || statusCode == 401) {
        cookieStore.removeCookie('auth', '/');
        return const Result<void>.success(null);
      }

      return Result<void>.failure(ApiFailure(statusCode, 'API error.'));
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  @override
  Result<AuthSession?> currentSession() {
    return Result<AuthSession?>.success(
      parseAuthSession(cookieStore.getCookie('auth')),
    );
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null) {
      return const Result<bool>.success(false);
    }

    if (roles.isEmpty) {
      return const Result<bool>.success(true);
    }

    if (operator.toLowerCase() == 'or') {
      final hasOne = roles.any((role) => session.roles.contains(role));
      return Result<bool>.success(hasOne);
    }

    final hasAll = roles.every((role) => session.roles.contains(role));
    return Result<bool>.success(hasAll);
  }

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    final session = parseAuthSession(cookieStore.getCookie('auth'));
    if (session == null) {
      return const Result<void>.failure(
        UnauthorizedFailure('User is not authenticated.'),
      );
    }

    final rowVersion = await _fetchUserRowVersion(session.userId);
    if (rowVersion == null) {
      return const Result<void>.failure(ApiFailure(500, 'API error.'));
    }

    final actionPath = appConfig.api.endpoints.authResetPassword.replaceAll(
      '{user_id}',
      session.userId,
    );

    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.post,
          path: actionPath,
          body: <String, dynamic>{
            'CurrentPassword': currentPassword,
            'NewPassword': newPassword,
            'ConfirmNewPassword': confirmNewPassword,
            'RowVersion': rowVersion,
          },
        ),
      );

      if (response.sessionExpired) {
        cookieStore.removeCookie('auth', '/');
        return const Result<void>.failure(SessionExpiredFailure());
      }

      if (!response.response.isSuccess) {
        return Result<void>.failure(
          ApiFailure(response.response.statusCode, 'API error.'),
        );
      }

      cookieStore.removeCookie('auth', '/');
      return const Result<void>.success(null);
    } catch (_) {
      return const Result<void>.failure(NetworkFailure('Network error.'));
    }
  }

  Future<int?> _fetchUserRowVersion(String userId) async {
    try {
      final response = await authenticatedHttpClient.send(
        AcpRequest(
          method: HttpMethod.get,
          path: '${appConfig.api.endpoints.user}/$userId',
        ),
      );

      if (!response.response.isSuccess) {
        return null;
      }

      final decoded = jsonDecode(response.response.body);
      if (decoded is Map<String, dynamic>) {
        final direct = _parseRowVersion(decoded['RowVersion']);
        if (direct != null) {
          return direct;
        }

        final values = decoded['value'];
        if (values is List && values.isNotEmpty && values.first is Map) {
          return _parseRowVersion((values.first as Map)['RowVersion']);
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  int? _parseRowVersion(Object? value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    if (value is String) {
      return int.tryParse(value);
    }

    return null;
  }
}
