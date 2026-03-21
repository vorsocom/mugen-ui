import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class FetchUserSessionsUseCase {
  const FetchUserSessionsUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<List<UserSessionEntity>>> call(String userId) {
    return _repository.fetchUserSessions(userId);
  }
}
