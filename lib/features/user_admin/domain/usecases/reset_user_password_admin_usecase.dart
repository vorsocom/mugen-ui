import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class ResetUserPasswordAdminUseCase {
  const ResetUserPasswordAdminUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(UserResetPasswordAdminInput input) {
    return _repository.resetUserPasswordAdmin(input);
  }
}
