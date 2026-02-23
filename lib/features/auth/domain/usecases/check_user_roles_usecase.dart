import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class CheckUserRolesUseCase {
  const CheckUserRolesUseCase(this._repository);

  final AuthRepository _repository;

  Result<bool> call({required List<String> roles, String operator = 'and'}) {
    return _repository.hasRoles(roles: roles, operator: operator);
  }
}
