import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

class LoginUserUseCase {
  const LoginUserUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<AuthSession>> call({
    required String username,
    required String password,
  }) {
    return _repository.login(username: username, password: password);
  }
}
