import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class UserAdminRepository {
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query);
  Future<Result<List<UserRoleEntity>>> fetchRoles();

  Future<Result<void>> registerUser(UserRegistrationInput input);
  Future<Result<void>> updateUser(UpdateUserInput input);
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input);
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input);
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  );
  Future<Result<void>> editUserRoles(EditUserRolesInput input);
}
