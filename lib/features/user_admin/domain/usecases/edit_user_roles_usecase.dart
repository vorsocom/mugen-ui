import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class EditUserRolesUseCase {
  const EditUserRolesUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(EditUserRolesInput input) {
    return _repository.editUserRoles(input);
  }
}
