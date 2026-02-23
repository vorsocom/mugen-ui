import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/disable_user_account_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/edit_user_roles_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/enable_user_account_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_roles_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_users_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/register_user_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/reset_user_password_admin_usecase.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/update_user_usecase.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class UserAdminService {
  const UserAdminService({
    required FetchUsersUseCase fetchUsersUseCase,
    required FetchRolesUseCase fetchRolesUseCase,
    required RegisterUserUseCase registerUserUseCase,
    required UpdateUserUseCase updateUserUseCase,
    required DisableUserAccountUseCase disableUserAccountUseCase,
    required EnableUserAccountUseCase enableUserAccountUseCase,
    required ResetUserPasswordAdminUseCase resetUserPasswordAdminUseCase,
    required EditUserRolesUseCase editUserRolesUseCase,
  }) : _fetchUsersUseCase = fetchUsersUseCase,
       _fetchRolesUseCase = fetchRolesUseCase,
       _registerUserUseCase = registerUserUseCase,
       _updateUserUseCase = updateUserUseCase,
       _disableUserAccountUseCase = disableUserAccountUseCase,
       _enableUserAccountUseCase = enableUserAccountUseCase,
       _resetUserPasswordAdminUseCase = resetUserPasswordAdminUseCase,
       _editUserRolesUseCase = editUserRolesUseCase;

  final FetchUsersUseCase _fetchUsersUseCase;
  final FetchRolesUseCase _fetchRolesUseCase;
  final RegisterUserUseCase _registerUserUseCase;
  final UpdateUserUseCase _updateUserUseCase;
  final DisableUserAccountUseCase _disableUserAccountUseCase;
  final EnableUserAccountUseCase _enableUserAccountUseCase;
  final ResetUserPasswordAdminUseCase _resetUserPasswordAdminUseCase;
  final EditUserRolesUseCase _editUserRolesUseCase;

  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) {
    return _fetchUsersUseCase(query);
  }

  Future<Result<List<UserRoleEntity>>> fetchRoles() {
    return _fetchRolesUseCase();
  }

  Future<Result<void>> registerUser(UserRegistrationInput input) {
    return _registerUserUseCase(input);
  }

  Future<Result<void>> updateUser(UpdateUserInput input) {
    return _updateUserUseCase(input);
  }

  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) {
    return _disableUserAccountUseCase(input);
  }

  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) {
    return _enableUserAccountUseCase(input);
  }

  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) {
    return _resetUserPasswordAdminUseCase(input);
  }

  Future<Result<void>> editUserRoles(EditUserRolesInput input) {
    return _editUserRolesUseCase(input);
  }
}
