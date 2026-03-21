import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class CheckUserAuthenticatedUseCase {
  const CheckUserAuthenticatedUseCase(this._repository);

  final AuthRepository _repository;

  Result<bool> call() {
    final result = _repository.currentSession();
    if (result.isFailure) {
      return Result<bool>.failure(result.failure!);
    }

    final hasSession = result.data != null;
    return Result<bool>.success(hasSession);
  }
}
