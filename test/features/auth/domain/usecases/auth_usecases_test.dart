import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_authenticated_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/logout_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/reset_own_password_usecase.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('CheckUserAuthenticatedUseCase maps session existence and failures', () {
    final repo = _FakeAuthRepository();
    final useCase = CheckUserAuthenticatedUseCase(repo);

    repo.currentSessionResult = const Result<AuthSession?>.success(null);
    final noSession = useCase();
    expect(noSession.isSuccess, isTrue);
    expect(noSession.data, isFalse);

    repo.currentSessionResult = const Result<AuthSession?>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>[],
      ),
    );
    final hasSession = useCase();
    expect(hasSession.isSuccess, isTrue);
    expect(hasSession.data, isTrue);

    repo.currentSessionResult = const Result<AuthSession?>.failure(
      UnexpectedFailure('session failed'),
    );
    final failure = useCase();
    expect(failure.isFailure, isTrue);
    expect(failure.failure?.message, 'session failed');
  });

  test('LogoutUserUseCase delegates to repository logout', () async {
    final repo = _FakeAuthRepository();
    final useCase = LogoutUserUseCase(repo);

    final response = await useCase();
    expect(response.isSuccess, isTrue);
    expect(repo.logoutCalls, 1);
  });

  test('ResetOwnPasswordUseCase delegates parameters to repository', () async {
    final repo = _FakeAuthRepository();
    final useCase = ResetOwnPasswordUseCase(repo);

    final response = await useCase(
      currentPassword: 'old-password',
      newPassword: 'new-password',
      confirmNewPassword: 'new-password',
    );

    expect(response.isSuccess, isTrue);
    expect(repo.lastCurrentPassword, 'old-password');
    expect(repo.lastNewPassword, 'new-password');
    expect(repo.lastConfirmNewPassword, 'new-password');
  });
}

class _FakeAuthRepository implements AuthRepository {
  Result<AuthSession?> currentSessionResult =
      const Result<AuthSession?>.success(null);
  int logoutCalls = 0;
  String? lastCurrentPassword;
  String? lastNewPassword;
  String? lastConfirmNewPassword;

  @override
  Result<AuthSession?> currentSession() => currentSessionResult;

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    return const Result<bool>.success(true);
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    return const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>[],
      ),
    );
  }

  @override
  Future<Result<void>> logout() async {
    logoutCalls += 1;
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    lastCurrentPassword = currentPassword;
    lastNewPassword = newPassword;
    lastConfirmNewPassword = confirmNewPassword;
    return const Result<void>.success(null);
  }
}
