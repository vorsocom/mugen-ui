import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class FetchRolesUseCase {
  const FetchRolesUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<List<UserRoleEntity>>> call() {
    return _repository.fetchRoles();
  }
}
