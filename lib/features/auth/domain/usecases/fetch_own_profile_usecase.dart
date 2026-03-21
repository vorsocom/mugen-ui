import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class FetchOwnProfileUseCase {
  const FetchOwnProfileUseCase(this._repository);

  final AuthRepository _repository;

  Future<Result<OwnProfileEntity>> call() {
    return _repository.fetchOwnProfile();
  }
}
