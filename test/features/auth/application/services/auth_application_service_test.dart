import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/application/dto/credentials.dart';
import 'package:mugen_ui/features/auth/application/dto/reset_password_input.dart';
import 'package:mugen_ui/features/auth/application/services/auth_application_service.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_authenticated_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_roles_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/login_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/logout_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/reset_own_password_usecase.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test(
    'AuthApplicationService delegates all operations to use cases',
    () async {
      final repository = _RecordingAuthRepository();
      final service = AuthApplicationService(
        loginUserUseCase: LoginUserUseCase(repository),
        logoutUserUseCase: LogoutUserUseCase(repository),
        checkUserAuthenticatedUseCase: CheckUserAuthenticatedUseCase(
          repository,
        ),
        checkUserRolesUseCase: CheckUserRolesUseCase(repository),
        resetOwnPasswordUseCase: ResetOwnPasswordUseCase(repository),
      );

      final loginResponse = await service.login(
        const Credentials(username: 'alice', password: 'secret'),
      );
      expect(loginResponse.isSuccess, isTrue);
      expect(repository.lastLoginUsername, 'alice');
      expect(repository.lastLoginPassword, 'secret');

      final isAuthenticated = service.isAuthenticated();
      expect(isAuthenticated.isSuccess, isTrue);
      expect(isAuthenticated.data, isTrue);

      final hasRoles = service.hasRoles(roles: const <String>['reader']);
      expect(hasRoles.isSuccess, isTrue);
      expect(repository.lastHasRolesOperator, 'and');
      expect(hasRoles.data, isTrue);

      final hasRolesWithOr = service.hasRoles(
        roles: const <String>['reader', 'writer'],
        operator: 'or',
      );
      expect(hasRolesWithOr.data, isTrue);
      expect(repository.lastHasRolesOperator, 'or');

      final resetResponse = await service.resetOwnPassword(
        const ResetPasswordInput(
          currentPassword: 'old',
          newPassword: 'new',
          confirmNewPassword: 'new',
        ),
      );
      expect(resetResponse.isSuccess, isTrue);
      expect(repository.lastCurrentPassword, 'old');
      expect(repository.lastNewPassword, 'new');
      expect(repository.lastConfirmNewPassword, 'new');

      final logoutResponse = await service.logout();
      expect(logoutResponse.isSuccess, isTrue);
      expect(repository.logoutCalls, 1);
    },
  );
}

class _RecordingAuthRepository implements AuthRepository {
  String? lastLoginUsername;
  String? lastLoginPassword;
  String? lastHasRolesOperator;
  String? lastCurrentPassword;
  String? lastNewPassword;
  String? lastConfirmNewPassword;
  int logoutCalls = 0;

  @override
  Result<AuthSession?> currentSession() {
    return const Result<AuthSession?>.success(
      AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u1',
        roles: <String>['reader'],
      ),
    );
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    lastHasRolesOperator = operator;
    if (operator == 'or') {
      return Result<bool>.success(roles.contains('reader'));
    }

    return const Result<bool>.success(true);
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    lastLoginUsername = username;
    lastLoginPassword = password;
    return const Result<AuthSession>.success(
      AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'u1',
        roles: <String>['reader'],
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
