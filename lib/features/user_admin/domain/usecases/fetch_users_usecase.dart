import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class FetchUsersUseCase {
  const FetchUsersUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<PageResult<UserEntity>>> call(UserListQuery query) {
    return _repository.fetchUsers(query);
  }
}
