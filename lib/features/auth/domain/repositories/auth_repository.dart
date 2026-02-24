import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

abstract class AuthRepository {
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  });

  Future<Result<void>> logout();

  Result<AuthSession?> currentSession();

  Result<bool> hasRoles({required List<String> roles, String operator = 'and'});

  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  });

  Future<Result<OwnProfileEntity>> fetchOwnProfile();

  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input);
}
