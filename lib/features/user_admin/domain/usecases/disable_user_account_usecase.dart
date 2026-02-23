import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class DisableUserAccountUseCase {
  const DisableUserAccountUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(ToggleUserAccountInput input) {
    return _repository.disableUserAccount(input);
  }
}
