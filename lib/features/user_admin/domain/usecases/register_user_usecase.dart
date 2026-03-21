import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class RegisterUserUseCase {
  const RegisterUserUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(UserRegistrationInput input) {
    return _repository.registerUser(input);
  }
}
