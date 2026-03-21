import 'package:mugen_ui/features/user_admin/application/dto/revoke_user_session_input.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class RevokeUserSessionUseCase {
  const RevokeUserSessionUseCase(this._repository);

  final UserAdminRepository _repository;

  Future<Result<void>> call(RevokeUserSessionInput input) {
    return _repository.revokeUserSession(input);
  }
}
