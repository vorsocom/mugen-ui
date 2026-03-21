import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('AuthControllerState copyWith supports clear flags and auth getter', () {
    const initial = AuthControllerState(
      isLoading: false,
      session: null,
      errorMessage: 'previous',
    );
    expect(initial.isAuthenticated, isFalse);

    const session = AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      userId: 'u1',
      roles: <String>['reader'],
    );
    final updated = initial.copyWith(
      isLoading: true,
      session: session,
      errorMessage: 'error',
    );
    expect(updated.isLoading, isTrue);
    expect(updated.session, session);
    expect(updated.errorMessage, 'error');
    expect(updated.isAuthenticated, isTrue);

    final fallback = updated.copyWith();
    expect(fallback.errorMessage, 'error');

    final cleared = updated.copyWith(clearSession: true, clearError: true);
    expect(cleared.session, isNull);
    expect(cleared.errorMessage, isNull);
  });

  test('AuthController login/logout/refresh/hasRoles behaviors', () async {
    final repository = _FakeAuthRepository();
    repository.currentSessionResult = const Result<AuthSession?>.success(
      AuthSession(
        accessToken: 'initial',
        refreshToken: 'refresh',
        userId: 'u0',
        roles: <String>['reader'],
      ),
    );
    repository.loginResult = const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'updated',
        refreshToken: 'refresh',
        userId: 'u1',
        roles: <String>['reader', 'writer'],
      ),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authControllerProvider.notifier);
    final initial = container.read(authControllerProvider);
    expect(initial.session?.userId, 'u0');

    final loginSuccess = await notifier.login(
      username: 'alice',
      password: 'pw',
    );
    expect(loginSuccess, isTrue);
    final afterLogin = container.read(authControllerProvider);
    expect(afterLogin.session?.userId, 'u1');
    expect(afterLogin.errorMessage, isNull);
    expect(repository.lastLoginUsername, 'alice');
    expect(repository.lastLoginPassword, 'pw');

    repository.currentSessionResult = const Result<AuthSession?>.success(null);
    notifier.refreshSession();
    final refreshed = container.read(authControllerProvider);
    expect(refreshed.session?.userId, 'u1');

    final hasRoles = notifier.hasRoles(const <String>['reader', 'writer']);
    expect(hasRoles, isTrue);
    expect(repository.lastHasRolesOperator, 'and');

    final hasRolesOr = notifier.hasRoles(const <String>[
      'reader',
      'missing',
    ], operator: 'or');
    expect(hasRolesOr, isTrue);
    expect(repository.lastHasRolesOperator, 'or');

    repository.logoutResult = const Result<void>.success(null);
    final logoutSuccess = await notifier.logout();
    expect(logoutSuccess, isTrue);
    final afterLogout = container.read(authControllerProvider);
    expect(afterLogout.session, isNull);

    repository.logoutResult = const Result<void>.failure(
      UnexpectedFailure('logout failed'),
    );
    final logoutFailure = await notifier.logout();
    expect(logoutFailure, isFalse);
    expect(
      container.read(authControllerProvider).errorMessage,
      'logout failed',
    );
  });

  test('AuthController surfaces login failures', () async {
    final repository = _FakeAuthRepository();
    repository.loginResult = const Result<AuthSession>.failure(
      UnexpectedFailure('bad credentials'),
    );

    final container = ProviderContainer(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(authControllerProvider.notifier);
    final success = await notifier.login(username: 'alice', password: 'wrong');
    expect(success, isFalse);
    expect(
      container.read(authControllerProvider).errorMessage,
      'bad credentials',
    );
  });
}

class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession?> currentSessionResult =
      const Result<AuthSession?>.success(null);
  Result<AuthSession> loginResult = const Result<AuthSession>.success(
    AuthSession(
      accessToken: 'a',
      refreshToken: 'r',
      userId: 'u1',
      roles: <String>[],
    ),
  );
  Result<void> logoutResult = const Result<void>.success(null);

  String? lastLoginUsername;
  String? lastLoginPassword;
  String? lastHasRolesOperator;

  @override
  Result<AuthSession?> currentSession() => currentSessionResult;

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    lastHasRolesOperator = operator;
    const available = <String>{'reader', 'writer'};
    if (operator == 'or') {
      return Result<bool>.success(roles.any(available.contains));
    }
    return Result<bool>.success(roles.every(available.contains));
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    lastLoginPassword = password;
    return loginResult;
  }

  @override
  Future<Result<void>> logout() async => logoutResult;

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<OwnProfileEntity>> fetchOwnProfile() async {
    return const Result<OwnProfileEntity>.success(
      OwnProfileEntity(
        userId: 'u1',
        personId: 'p1',
        personRowVersion: 1,
        firstName: 'Alice',
        lastName: 'Example',
      ),
    );
  }

  @override
  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input) async {
    return const Result<void>.success(null);
  }
}
