import 'package:mugen_ui/features/auth/application/dto/credentials.dart';
import 'package:mugen_ui/features/auth/application/dto/reset_password_input.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_authenticated_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/check_user_roles_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/fetch_own_profile_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/login_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/logout_user_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/reset_own_password_usecase.dart';
import 'package:mugen_ui/features/auth/domain/usecases/update_own_profile_usecase.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

class AuthApplicationService {
  const AuthApplicationService({
    required LoginUserUseCase loginUserUseCase,
    required LogoutUserUseCase logoutUserUseCase,
    required CheckUserAuthenticatedUseCase checkUserAuthenticatedUseCase,
    required CheckUserRolesUseCase checkUserRolesUseCase,
    required ResetOwnPasswordUseCase resetOwnPasswordUseCase,
    required FetchOwnProfileUseCase fetchOwnProfileUseCase,
    required UpdateOwnProfileUseCase updateOwnProfileUseCase,
  }) : _loginUserUseCase = loginUserUseCase,
       _logoutUserUseCase = logoutUserUseCase,
       _checkUserAuthenticatedUseCase = checkUserAuthenticatedUseCase,
       _checkUserRolesUseCase = checkUserRolesUseCase,
       _resetOwnPasswordUseCase = resetOwnPasswordUseCase,
       _fetchOwnProfileUseCase = fetchOwnProfileUseCase,
       _updateOwnProfileUseCase = updateOwnProfileUseCase;

  final LoginUserUseCase _loginUserUseCase;
  final LogoutUserUseCase _logoutUserUseCase;
  final CheckUserAuthenticatedUseCase _checkUserAuthenticatedUseCase;
  final CheckUserRolesUseCase _checkUserRolesUseCase;
  final ResetOwnPasswordUseCase _resetOwnPasswordUseCase;
  final FetchOwnProfileUseCase _fetchOwnProfileUseCase;
  final UpdateOwnProfileUseCase _updateOwnProfileUseCase;

  Future<Result<AuthSession>> login(Credentials credentials) {
    return _loginUserUseCase(
      username: credentials.username,
      password: credentials.password,
    );
  }

  Future<Result<void>> logout() {
    return _logoutUserUseCase();
  }

  Result<bool> isAuthenticated() {
    return _checkUserAuthenticatedUseCase();
  }

  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    return _checkUserRolesUseCase(roles: roles, operator: operator);
  }

  Future<Result<void>> resetOwnPassword(ResetPasswordInput input) {
    return _resetOwnPasswordUseCase(
      currentPassword: input.currentPassword,
      newPassword: input.newPassword,
      confirmNewPassword: input.confirmNewPassword,
    );
  }

  Future<Result<OwnProfileEntity>> fetchOwnProfile() {
    return _fetchOwnProfileUseCase();
  }

  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input) {
    return _updateOwnProfileUseCase(input);
  }
}
