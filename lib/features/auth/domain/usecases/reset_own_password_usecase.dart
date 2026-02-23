import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class ResetOwnPasswordUseCase {
  const ResetOwnPasswordUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) {
    return _repository.resetOwnPassword(
      currentPassword: currentPassword,
      newPassword: newPassword,
      confirmNewPassword: confirmNewPassword,
    );
  }
}
