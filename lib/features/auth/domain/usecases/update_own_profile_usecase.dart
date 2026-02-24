import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class UpdateOwnProfileUseCase {
  const UpdateOwnProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<void>> call(UpdateOwnProfileInput input) {
    return _repository.updateOwnProfile(input);
  }
}
