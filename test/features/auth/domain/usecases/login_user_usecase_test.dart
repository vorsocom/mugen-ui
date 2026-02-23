import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/domain/usecases/login_user_usecase.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test('LoginUserUseCase delegates to repository', () async {
    final repo = _FakeAuthRepository();
    final useCase = LoginUserUseCase(repo);

    final result = await useCase(username: 'alice', password: 'secret');

    expect(repo.lastUsername, 'alice');
    expect(repo.lastPassword, 'secret');
    expect(result.isSuccess, isTrue);
    expect(result.data?.userId, 'u1');
  });
}

class _FakeAuthRepository implements AuthRepository {
  String? lastUsername;
  String? lastPassword;

  @override
  Result<AuthSession?> currentSession() {
    return const Result<AuthSession?>.success(null);
  }

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
    lastUsername = username;
    lastPassword = password;

    return const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>['role:a'],
      ),
    );
  }

  @override
  Future<Result<void>> logout() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return const Result<void>.success(null);
  }
}
