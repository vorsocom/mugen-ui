import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/infrastructure/repositories/user_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/infrastructure/auth/cookie_store.dart';
import 'package:mugen_ui/shared/infrastructure/http/acp_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/authenticated_http_client.dart';
import 'package:mugen_ui/shared/infrastructure/http/http_transport.dart';

void main() {
  group('UserAdminRepositoryImpl.fetchUsers', () {
    test('builds expected query and maps users payload', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': '2',
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'u-2',
                  'Username': 'alice',
                  'LoginEmail': 'alice@example.com',
                  'PersonId': 'p-2',
                  'CreatedAt': '2026-01-02T03:04:05Z',
                  'UpdatedAt': '2026-01-03T04:05:06Z',
                  'DeletedAt': null,
                  'LockedAt': null,
                  'RowVersion': '7',
                  'SeedData': '1',
                  'Person': <String, dynamic>{
                    'Id': 'p-2',
                    'FirstName': 'Alice',
                    'LastName': 'Example',
                    'CreatedAt': 'invalid-date',
                    'UpdatedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                    'SeedData': 0,
                  },
                  'GlobalRoleMemberships': <Map<String, dynamic>>[
                    <String, dynamic>{'GlobalRoleId': 'role-1'},
                    <String, dynamic>{'GlobalRoleId': ''},
                    <String, dynamic>{},
                  ],
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(
          pageRequest: PageRequest(page: 2, pageSize: 5),
          searchTerm: 'al',
          excludeUserName: "bob'o",
        ),
      );

      expect(result.isSuccess, isTrue);
      final page = result.data!;
      expect(page.total, 2);
      expect(page.page, 2);
      expect(page.pageSize, 5);
      expect(page.items, hasLength(1));
      expect(page.items.first.userName, 'alice');
      expect(page.items.first.roles, <String>['role-1']);
      expect(page.items.first.person.fullName, 'Alice Example');
      expect(
        page.items.first.person.dateCreated,
        DateTime.utc(2026, 1, 2, 3, 4, 5),
      );
      expect(
        page.items.first.person.dateLastModified,
        DateTime.utc(2025, 1, 1),
      );
      expect(page.items.first.seedData, isTrue);

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/Users');
      expect(request.queryParameters[r'$skip'], 5);
      expect(request.queryParameters[r'$top'], 5);
      expect(
        request.queryParameters[r'$filter'],
        allOf(
          contains("Username ne 'bob''o'"),
          contains("contains(Username,'al')"),
        ),
      );
    });

    test('omits pagination skip/top when page size is zero', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              '@count': 0,
              'value': <dynamic>[],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 0)),
      );

      expect(result.isSuccess, isTrue);
      final query = fixture.client.requests.single.queryParameters;
      expect(query.containsKey(r'$skip'), isFalse);
      expect(query.containsKey(r'$top'), isFalse);
    });

    test('returns session-expired failure', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
    });

    test('returns API failure for non-success response', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 500);
    });

    test('returns unexpected failure for non-map payload', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<UnexpectedFailure>());
    });

    test('returns network failure on thrown exception', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );

      final result = await fixture.repository.fetchUsers(
        const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test(
      'maps fallback person and numeric row-version/date coercions',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{
                '@count': 1,
                'value': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'Id': 'u-fallback',
                    'Username': 'fallback',
                    'LoginEmail': 'fallback@example.com',
                    'PersonId': 'p-fallback',
                    'CreatedAt': null,
                    'UpdatedAt': 'not-a-date',
                    'DeletedAt': null,
                    'LockedAt': null,
                    'RowVersion': 7.5,
                    'SeedData': false,
                    'Person': null,
                    'GlobalRoleMemberships': const <dynamic>[],
                  },
                ],
              }),
            ),
          ],
        );

        final result = await fixture.repository.fetchUsers(
          const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
        );

        expect(result.isSuccess, isTrue);
        final user = result.data!.items.single;
        expect(user.person.id, 'p-fallback');
        expect(user.person.firstName, '');
        expect(user.person.lastName, '');
        expect(user.rowVersion, 7);
        expect(
          user.dateCreated,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
        expect(
          user.dateLastModified,
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
        );
      },
    );
  });

  group('UserAdminRepositoryImpl.fetchRoles', () {
    test('maps role payload and applies active-roles filter', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'r-1',
                  'Namespace': 'com.vorsocomputing.mugen.acp',
                  'Name': 'administrator',
                  'DisplayName': '',
                  'CreatedAt': 'Wed, 01 Jan 2025 00:00:00 GMT',
                  'UpdatedAt': '2026-01-01T00:00:00Z',
                  'DeletedAt': null,
                  'SeedData': true,
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchRoles();

      expect(result.isSuccess, isTrue);
      expect(result.data, hasLength(1));
      final role = result.data!.single;
      expect(role.id, 'r-1');
      expect(role.name, 'com.vorsocomputing.mugen.acp:administrator');
      expect(role.displayName, 'com.vorsocomputing.mugen.acp:administrator');
      expect(role.seedData, isTrue);
      expect(role.dateCreated, DateTime.utc(2025, 1, 1));
      expect(role.dateLastModified, DateTime.utc(2026, 1, 1));

      final request = fixture.client.requests.single;
      expect(request.path, 'core/acp/v1/GlobalRoles');
      expect(
        request.queryParameters[r'$filter'],
        "Name eq 'administrator' or Name eq 'authenticated'",
      );
    });

    test('returns session-expired failure', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.fetchRoles();
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
    });

    test('returns API failure for non-success response', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
      );

      final result = await fixture.repository.fetchRoles();
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 500);
    });

    test('returns unexpected failure for non-map payload', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 200, body: '[]')],
      );

      final result = await fixture.repository.fetchRoles();
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<UnexpectedFailure>());
    });

    test('returns network failure when client throws', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );

      final result = await fixture.repository.fetchRoles();
      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test('uses explicit role displayName when present', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{
                  'Id': 'r-2',
                  'Namespace': 'com.vorsocomputing.mugen.acp',
                  'Name': 'administrator',
                  'DisplayName': 'Administrators',
                  'CreatedAt': null,
                  'UpdatedAt': null,
                  'DeletedAt': null,
                  'SeedData': false,
                },
              ],
            }),
          ),
        ],
      );

      final result = await fixture.repository.fetchRoles();
      expect(result.isSuccess, isTrue);
      final role = result.data!.single;
      expect(role.displayName, 'Administrators');
      expect(
        role.dateCreated,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
      expect(
        role.dateLastModified,
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    });
  });

  group('UserAdminRepositoryImpl mutations', () {
    test('registerUser validates non-empty email', () async {
      final fixture = _UserAdminFixture();

      final result = await fixture.repository.registerUser(
        const UserRegistrationInput(
          firstName: 'A',
          lastName: 'B',
          userName: 'alice',
          email: '   ',
          password: 'secret',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ValidationFailure>());
      expect(fixture.client.requests, isEmpty);
    });

    test('registerUser trims email and returns success', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 201)],
      );

      final result = await fixture.repository.registerUser(
        const UserRegistrationInput(
          firstName: 'A',
          lastName: 'B',
          userName: 'alice',
          email: ' alice@example.com ',
          password: 'secret',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(fixture.client.requests.single.body, <String, dynamic>{
        'Username': 'alice',
        'Password': 'secret',
        'LoginEmail': 'alice@example.com',
        'FirstName': 'A',
        'LastName': 'B',
      });
    });

    test('registerUser maps sessionExpired and removes auth cookie', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(statusCode: 401, sessionExpired: true),
        ],
      );

      final result = await fixture.repository.registerUser(
        const UserRegistrationInput(
          firstName: 'A',
          lastName: 'B',
          userName: 'alice',
          email: 'alice@example.com',
          password: 'secret',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<SessionExpiredFailure>());
      expect(fixture.cookieStore.removed, contains('auth:/'));
    });

    test('registerUser maps API failure', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => _response(statusCode: 409)],
      );

      final result = await fixture.repository.registerUser(
        const UserRegistrationInput(
          firstName: 'A',
          lastName: 'B',
          userName: 'alice',
          email: 'alice@example.com',
          password: 'secret',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<ApiFailure>());
      expect((result.failure as ApiFailure).statusCode, 409);
    });

    test('registerUser maps network failure', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[(_) => throw Exception('boom')],
      );

      final result = await fixture.repository.registerUser(
        const UserRegistrationInput(
          firstName: 'A',
          lastName: 'B',
          userName: 'alice',
          email: 'alice@example.com',
          password: 'secret',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test('updateUser fetches row version and calls update action', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{
              'value': <Map<String, dynamic>>[
                <String, dynamic>{'RowVersion': '9'},
              ],
            }),
          ),
          (_) => _response(statusCode: 200),
        ],
      );

      final result = await fixture.repository.updateUser(
        const UpdateUserInput(
          userId: 'u-2',
          personId: 'p-2',
          firstName: 'Alice',
          lastName: 'Updated',
          email: 'alice@example.com',
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(fixture.client.requests.length, 2);
      expect(fixture.client.requests[0].path, 'core/acp/v1/Users/u-2');
      expect(
        fixture.client.requests[1].path,
        r'core/acp/v1/Users/u-2/$action/updateprofile',
      );
      expect(fixture.client.requests[1].body, <String, dynamic>{
        'RowVersion': 9,
        'FirstName': 'Alice',
        'LastName': 'Updated',
      });
    });

    test(
      'updateUser returns API failure when row version is missing',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{}),
            ),
          ],
        );

        final result = await fixture.repository.updateUser(
          const UpdateUserInput(
            userId: 'u-2',
            personId: 'p-2',
            firstName: 'Alice',
            lastName: 'Updated',
            email: 'alice@example.com',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<ApiFailure>());
        expect((result.failure as ApiFailure).statusCode, 500);
      },
    );

    test('updateUser maps network failure on action call', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{'RowVersion': 2}),
          ),
          (_) => throw Exception('boom'),
        ],
      );

      final result = await fixture.repository.updateUser(
        const UpdateUserInput(
          userId: 'u-2',
          personId: 'p-2',
          firstName: 'Alice',
          lastName: 'Updated',
          email: 'alice@example.com',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test(
      'disableUserAccount and enableUserAccount call toggle endpoints',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{'RowVersion': 4}),
            ),
            (_) => _response(statusCode: 204),
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{'RowVersion': 5}),
            ),
            (_) => _response(statusCode: 204),
          ],
        );

        final disable = await fixture.repository.disableUserAccount(
          const ToggleUserAccountInput(userId: 'u-2'),
        );
        final enable = await fixture.repository.enableUserAccount(
          const ToggleUserAccountInput(userId: 'u-2'),
        );

        expect(disable.isSuccess, isTrue);
        expect(enable.isSuccess, isTrue);
        expect(
          fixture.client.requests[1].path,
          r'core/acp/v1/Users/u-2/$action/lock',
        );
        expect(
          fixture.client.requests[3].path,
          r'core/acp/v1/Users/u-2/$action/unlock',
        );
      },
    );

    test(
      'toggleUser returns API failure when row version fetch fails',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => _response(statusCode: 500)],
        );

        final result = await fixture.repository.enableUserAccount(
          const ToggleUserAccountInput(userId: 'u-2'),
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<ApiFailure>());
        expect((result.failure as ApiFailure).statusCode, 500);
      },
    );

    test(
      'resetUserPasswordAdmin skips fetch when rowVersion is provided',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => _response(statusCode: 204)],
        );

        final result = await fixture.repository.resetUserPasswordAdmin(
          const UserResetPasswordAdminInput(
            userId: 'u-2',
            newPassword: 'new',
            confirmNewPassword: 'new',
            rowVersion: 11,
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(fixture.client.requests, hasLength(1));
        expect(
          fixture.client.requests.single.path,
          r'core/acp/v1/Users/u-2/$action/resetpasswordadmin',
        );
        expect(fixture.client.requests.single.body, <String, dynamic>{
          'RowVersion': 11,
          'NewPassword': 'new',
          'ConfirmNewPassword': 'new',
        });
      },
    );

    test(
      'resetUserPasswordAdmin fetches rowVersion when input has default',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[
            (_) => _response(
              statusCode: 200,
              body: jsonEncode(<String, dynamic>{'RowVersion': 6}),
            ),
            (_) => _response(statusCode: 200),
          ],
        );

        final result = await fixture.repository.resetUserPasswordAdmin(
          const UserResetPasswordAdminInput(
            userId: 'u-2',
            newPassword: 'new',
            confirmNewPassword: 'new',
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(fixture.client.requests, hasLength(2));
      },
    );

    test(
      'resetUserPasswordAdmin fails when fetched rowVersion is unavailable',
      () async {
        final fixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => _response(statusCode: 404)],
        );

        final result = await fixture.repository.resetUserPasswordAdmin(
          const UserResetPasswordAdminInput(
            userId: 'u-2',
            newPassword: 'new',
            confirmNewPassword: 'new',
          ),
        );

        expect(result.isFailure, isTrue);
        expect(result.failure, isA<ApiFailure>());
        expect((result.failure as ApiFailure).statusCode, 500);
      },
    );

    test('resetUserPasswordAdmin maps network failure', () async {
      final fixture = _UserAdminFixture(
        handlers: <_AuthHandler>[
          (_) => _response(
            statusCode: 200,
            body: jsonEncode(<String, dynamic>{'RowVersion': 6}),
          ),
          (_) => throw Exception('boom'),
        ],
      );

      final result = await fixture.repository.resetUserPasswordAdmin(
        const UserResetPasswordAdminInput(
          userId: 'u-2',
          newPassword: 'new',
          confirmNewPassword: 'new',
        ),
      );

      expect(result.isFailure, isTrue);
      expect(result.failure, isA<NetworkFailure>());
    });

    test(
      'editUserRoles maps success, API failure, and network failure',
      () async {
        final successFixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => _response(statusCode: 204)],
        );
        final success = await successFixture.repository.editUserRoles(
          const EditUserRolesInput(userId: 'u-2', roles: <String>['admin']),
        );
        expect(success.isSuccess, isTrue);
        expect(
          successFixture.client.requests.single.path,
          r'core/acp/v1/Users/u-2/$action/updateroles',
        );

        final apiFixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => _response(statusCode: 400)],
        );
        final api = await apiFixture.repository.editUserRoles(
          const EditUserRolesInput(userId: 'u-2', roles: <String>['admin']),
        );
        expect(api.isFailure, isTrue);
        expect(api.failure, isA<ApiFailure>());

        final networkFixture = _UserAdminFixture(
          handlers: <_AuthHandler>[(_) => throw Exception('boom')],
        );
        final network = await networkFixture.repository.editUserRoles(
          const EditUserRolesInput(userId: 'u-2', roles: <String>['admin']),
        );
        expect(network.isFailure, isTrue);
        expect(network.failure, isA<NetworkFailure>());
      },
    );
  });

  test('currentUserName reads username from auth cookie', () {
    final fixture = _UserAdminFixture(
      sessionCookie: jsonEncode(<String, dynamic>{
        'access_token': 'token-a',
        'refresh_token': 'token-r',
        'user_id': 'u-1',
        'username': 'alice',
      }),
    );

    expect(fixture.repository.currentUserName(), 'alice');
  });
}

class _UserAdminFixture {
  _UserAdminFixture({String? sessionCookie, List<_AuthHandler>? handlers})
    : cookieStore = _MemoryCookieStore(),
      client = _QueueAuthenticatedHttpClient(
        handlers ?? const <_AuthHandler>[],
      ) {
    if (sessionCookie != null) {
      cookieStore.setCookie('auth', sessionCookie, 3600, '/');
    }

    repository = UserAdminRepositoryImpl(
      appConfig: AppConfig.defaults(),
      cookieStore: cookieStore,
      authenticatedHttpClient: client,
    );
  }

  final _MemoryCookieStore cookieStore;
  final _QueueAuthenticatedHttpClient client;
  late final UserAdminRepositoryImpl repository;
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
