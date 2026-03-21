import 'package:mugen_ui/features/user_admin/application/dto/delete_user_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class DeleteUserUseCase {
  const DeleteUserUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(DeleteUserInput input) {
    return _repository.deleteUser(input);
  }
}
