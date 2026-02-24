import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/infrastructure/repositories/auth_repository_impl.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('AuthRepositoryImpl.login', () {
    test(
      'returns validation failure when username/password is empty',
      () async {
        final fixture = _AuthFixture();

        final result = await fixture.repository.login(
          username: ' ',
          password: '',
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<ValidationFailure>());
        expect(fixture.client.requests, isEmpty);
      },
    );

    test('returns API failure for non-success response', () async {
      final fixture = _AuthFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 401)],
      );

      final result = await fixture.repository.login(
        username: 'alice',
        password: 'secret',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 401);
    });

    test('stores cookie and returns parsed session on success', () async {
      final payload = jsonEncode(<String, dynamic>{
        'access_token': 'token-a',
        'refresh_token': 'token-r',
        'user_id': 'u-1',
        'username': 'alice',
        'roles': <String>['a', 'b'],
      });
      final fixture = _AuthFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 200, body: payload),
        ],
      );

      final result = await fixture.repository.login(
        username: 'alice',
        password: 'secret',
      );

      expect(result.isSuccess, isTrue);
      expect(result.data?.userId, 'u-1');
      expect(result.data?.username, 'alice');
      expect(result.data?.roles, <String>['a', 'b']);
      expect(fixture.cookieStore.getCookie('auth'), payload);
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test(
      'returns unexpected failure when response cookie payload is invalid',
      () async {
        final fixture = _AuthFixture(
          handlers: <_AuthHandler>[
            (_) => _response(statusCode: 200, body: 'not-json'),
          ],
        );

        final result = await fixture.repository.login(
          username: 'alice',
          password: 'secret',
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<UnexpectedFailure>());
      },
    );

    test('returns network failure when client throws', () async {
      final fixture = _AuthFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );

      final result = await fixture.repository.login(
        username: 'alice',
        password: 'secret',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.logout', () {
    test('clears cookie and succeeds when session is missing', () async {
      final fixture = _AuthFixture();

      final result = await fixture.repository.logout();

      expect(result.isSuccess, isTrue);
      expect(fixture.client.requests, isEmpty);
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('clears cookie and succeeds on API success status', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(refreshToken: 'refresh-1'),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200)],
      );

      final result = await fixture.repository.logout();

      expect(result.isSuccess, isTrue);
      expect(fixture.client.requests.single.path, 'core/acp/v1/auth/logout');
      expect(fixture.client.requests.single.body, <String, String>{
        'RefreshToken': 'refresh-1',
      });
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('treats API 401 as successful logout and clears cookie', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(refreshToken: 'refresh-1'),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 401)],
      );

      final result = await fixture.repository.logout();

      expect(result.isSuccess, isTrue);
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('returns API failure for non-success/non-401 status', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(refreshToken: 'refresh-1'),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
      );

      final result = await fixture.repository.logout();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 500);
    });

    test('returns network failure when client throws', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(refreshToken: 'refresh-1'),
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );

      final result = await fixture.repository.logout();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.currentSession and hasRoles', () {
    test('currentSession returns parsed cookie payload', () {
      final fixture = _AuthFixture(sessionCookie: _sessionCookie());

      final result = fixture.repository.currentSession();

      expect(result.isSuccess, isTrue);
      expect(result.data?.userId, 'u-1');
      expect(result.data?.username, 'alice');
    });

    test('hasRoles handles missing session, empty roles, and/or operators', () {
      final withoutSession = _AuthFixture();
      expect(
        withoutSession.repository.hasRoles(roles: <String>['admin']).data,
        isFalse,
      );

      final withSession = _AuthFixture(
        sessionCookie: _sessionCookie(roles: <String>['admin', 'auditor']),
      );

      expect(withSession.repository.hasRoles(roles: <String>[]).data, isTrue);
      expect(
        withSession.repository
            .hasRoles(roles: <String>['admin', 'auditor'])
            .data,
        isTrue,
      );
      expect(
        withSession.repository.hasRoles(roles: <String>['admin', 'ops']).data,
        isFalse,
      );
      expect(
        withSession.repository
            .hasRoles(roles: <String>['ops', 'auditor'], operator: 'or')
            .data,
        isTrue,
      );
    });
  });

  group('AuthRepositoryImpl.resetOwnPassword', () {
    test(
      'returns unauthorized failure when there is no auth session',
      () async {
        final fixture = _AuthFixture();

        final result = await fixture.repository.resetOwnPassword(
          currentPassword: 'old',
          newPassword: 'new',
          confirmNewPassword: 'new',
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<UnauthorizedFailure>());
        expect(fixture.client.requests, isEmpty);
      },
    );

    test('returns API failure when row version cannot be fetched', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 404)],
      );

      final result = await fixture.repository.resetOwnPassword(
        currentPassword: 'old',
        newPassword: 'new',
        confirmNewPassword: 'new',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 500);
    });

    test('clears cookie and returns session-expired failure', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{'RowVersion': 9}),
          ),
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.resetOwnPassword(
        currentPassword: 'old',
        newPassword: 'new',
        confirmNewPassword: 'new',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('returns API failure for non-success action response', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{'RowVersion': '12'},
              ],
            }),
          ),
          (_) => _response(statusCode: 409),
        ],
      );

      final result = await fixture.repository.resetOwnPassword(
        currentPassword: 'old',
        newPassword: 'new',
        confirmNewPassword: 'new',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 409);
    });

    test(
      'returns success and clears cookie after successful password reset',
      () async {
        final fixture = _AuthFixture(
          sessionCookie: _sessionCookie(),
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{'RowVersion': 7.9}),
            ),
            (_) => _response(statusCode: 204),
          ],
        );

        final result = await fixture.repository.resetOwnPassword(
          currentPassword: 'old',
          newPassword: 'new',
          confirmNewPassword: 'new',
        );

        expect(result.isSuccess, isTrue);
        expect(fixture.cookieStore.removed, contains('auth:/'));
        expect(fixture.client.requests.length, 2);
        expect(fixture.client.requests[0].path, 'core/acp/v1/Users/u-1');
        expect(
          fixture.client.requests[1].path,
          r'core/acp/v1/Users/u-1/$action/resetpassworduser',
        );
        expect(fixture.client.requests[1].body, <String, dynamic>{
          'CurrentPassword': 'old',
          'NewPassword': 'new',
          'ConfirmNewPassword': 'new',
          'RowVersion': 7,
        });
      },
    );

    test('returns network failure when action request throws', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{'RowVersion': 3}),
          ),
          (_) => throw Exception('boom'),
        ],
      );

      final result = await fixture.repository.resetOwnPassword(
        currentPassword: 'old',
        newPassword: 'new',
        confirmNewPassword: 'new',
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.fetchOwnProfile', () {
    test(
      'returns unauthorized failure when there is no auth session',
      () async {
        final fixture = _AuthFixture();

        final result = await fixture.repository.fetchOwnProfile();

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<UnauthorizedFailure>());
        expect(fixture.client.requests, isEmpty);
      },
    );

    test('parses profile payload from expanded Person', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(userId: 'u-42'),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'Id': 'u-42',
              'PersonId': 'p-42',
              'Person': <String, dynamic>{
                'Id': 'p-42',
                'RowVersion': '9',
                'FirstName': 'Alice',
                'LastName': 'Example',
              },
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchOwnProfile();

      expect(result.isSuccess, isTrue);
      expect(result.data?.userId, 'u-42');
      expect(result.data?.personId, 'p-42');
      expect(result.data?.personRowVersion, 9);
      expect(result.data?.firstName, 'Alice');
      expect(result.data?.lastName, 'Example');
      expect(fixture.client.requests.single.path, 'core/acp/v1/Users/u-42');
      expect(
        fixture.client.requests.single.queryParameters[r'$expand'],
        'Person',
      );
    });

    test('parses profile payload from collection response format', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(userId: 'u-50'),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'u-50',
                  'PersonId': 'p-50',
                  'Person': <Map<String, dynamic>>[
                    <String, dynamic>{
                      'Id': 'p-50',
                      'RowVersion': 4,
                      'FirstName': 'Bob',
                      'LastName': 'Example',
                    },
                  ],
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchOwnProfile();

      expect(result.isSuccess, isTrue);
      expect(result.data?.userId, 'u-50');
      expect(result.data?.personRowVersion, 4);
    });

    test(
      'falls back to session and PersonId when payload IDs are empty',
      () async {
        final fixture = _AuthFixture(
          sessionCookie: _sessionCookie(userId: 'u-session'),
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{
                'Id': '',
                'PersonId': 'p-fallback',
                'Person': <String, dynamic>{
                  'Id': '',
                  'RowVersion': 2,
                  'FirstName': 'Fallback',
                  'LastName': 'Profile',
                },
              }),
            ),
          ],
        );

        final result = await fixture.repository.fetchOwnProfile();

        expect(result.isSuccess, isTrue);
        expect(result.data?.userId, 'u-session');
        expect(result.data?.personId, 'p-fallback');
      },
    );

    test('maps session expired and clears cookie', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.fetchOwnProfile();

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('maps API, unexpected payload, and network failures', () async {
      final apiFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 400)],
      );
      final api = await apiFixture.repository.fetchOwnProfile();
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());

      final invalidMapFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '{}')],
      );
      final invalidMap = await invalidMapFixture.repository.fetchOwnProfile();
      expect(invalidMap.isFailure, isTrue);
      expect(invalidMap.failure, isA<UnexpectedFailure>());

      final invalidBodyFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );
      final invalidBody = await invalidBodyFixture.repository.fetchOwnProfile();
      expect(invalidBody.isFailure, isTrue);
      expect(invalidBody.failure, isA<UnexpectedFailure>());

      final missingRowVersionFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'Id': 'u-1',
              'Person': <String, dynamic>{
                'Id': 'p-1',
                'FirstName': 'No',
                'LastName': 'Version',
              },
            }),
          ),
        ],
      );
      final missingRowVersion = await missingRowVersionFixture.repository
          .fetchOwnProfile();
      expect(missingRowVersion.isFailure, isTrue);
      expect(missingRowVersion.failure, isA<UnexpectedFailure>());

      final networkFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.fetchOwnProfile();
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    });
  });

  group('AuthRepositoryImpl.updateOwnProfile', () {
    test(
      'returns unauthorized failure when there is no auth session',
      () async {
        final fixture = _AuthFixture();

        final result = await fixture.repository.updateOwnProfile(
          const UpdateOwnProfileInput(
            firstName: 'Alice',
            lastName: 'Example',
            personRowVersion: 1,
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<UnauthorizedFailure>());
        expect(fixture.client.requests, isEmpty);
      },
    );

    test('returns validation failure when row version is invalid', () async {
      final fixture = _AuthFixture(sessionCookie: _sessionCookie());

      final result = await fixture.repository.updateOwnProfile(
        const UpdateOwnProfileInput(
          firstName: 'Alice',
          lastName: 'Example',
          personRowVersion: 0,
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
      expect(fixture.client.requests, isEmpty);
    });

    test('sends expected action payload for profile update', () async {
      final fixture = _AuthFixture(
        sessionCookie: _sessionCookie(userId: 'u-9'),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 204)],
      );

      final result = await fixture.repository.updateOwnProfile(
        const UpdateOwnProfileInput(
          firstName: 'Alice',
          lastName: 'Updated',
          personRowVersion: 11,
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(
        fixture.client.requests.single.path,
        r'core/acp/v1/Users/u-9/$action/updateprofile',
      );
      expect(fixture.client.requests.single.body, <String, dynamic>{
        'RowVersion': 11,
        'FirstName': 'Alice',
        'LastName': 'Updated',
      });
    });

    test('maps session-expired, API, and network failures', () async {
      final expiredFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );
      final expired = await expiredFixture.repository.updateOwnProfile(
        const UpdateOwnProfileInput(
          firstName: 'A',
          lastName: 'B',
          personRowVersion: 2,
        ),
      );
      expect(expired.isFailure, isTrue);
      expect(expired.failure, isA<SessionExpiredFailure>());
      expect(expiredFixture.cookieStore.removed, contains('auth:/'));

      final apiFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => _response(statusCode: 400)],
      );
      final api = await apiFixture.repository.updateOwnProfile(
        const UpdateOwnProfileInput(
          firstName: 'A',
          lastName: 'B',
          personRowVersion: 2,
        ),
      );
      expect(api.isFailure, isTrue);
      expect(api.failure, isA<ApiFailure>());

      final networkFixture = _AuthFixture(
        sessionCookie: _sessionCookie(),
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );
      final network = await networkFixture.repository.updateOwnProfile(
        const UpdateOwnProfileInput(
          firstName: 'A',
          lastName: 'B',
          personRowVersion: 2,
        ),
      );
      expect(network.isFailure, isTrue);
      expect(network.failure, isA<NetworkFailure>());
    });
  });
}

class _AuthFixture {
  _AuthFixture({String? sessionCookie, List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    if (sessionCookie != null) {
      cookieStore.setCookie('auth', sessionCookie, 3600, '/');
    }

    repository = AuthRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final AuthRepositoryImpl repository;
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

String _sessionCookie({
  String accessToken = 'token-a',
  String refreshToken = 'token-r',
  String userId = 'u-1',
  String username = 'alice',
  List<String> roles = const <String>['admin'],
}) {
  return jsonEncode(<String, dynamic>{
    'access_token': accessToken,
    'refresh_token': refreshToken,
    'user_id': userId,
    'username': username,
    'roles': roles,
  });
}
