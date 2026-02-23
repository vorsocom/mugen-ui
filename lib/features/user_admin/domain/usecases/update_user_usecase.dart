import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class UpdateUserUseCase {
  const UpdateUserUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(UpdateUserInput input) {
    return _repository.updateUser(input);
  }
}
