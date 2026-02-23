import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/infrastructure/repositories/user_admin_repository_impl.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test(
    'userAdminRepository provider builds default repository implementation',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repository = container.read(userAdminRepositoryProvider);
      expect(repository, isA<UserAdminRepositoryImpl>());
    },
  );

  test(
    'UserAdminController load failures set descriptive error state',
    () async {
      final repository = _FakeUserAdminRepository()
        ..fetchUsersResult = const Result<PageResult<UserEntity>>.failure(
          UnexpectedFailure('users failed'),
        )
        ..fetchRolesResult = const Result<List<UserRoleEntity>>.failure(
          UnexpectedFailure('roles failed'),
        );
      final container = ProviderContainer(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => _TestAuthController()),
          userAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userAdminControllerProvider.notifier);
      await notifier.loadUsers();
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'users failed',
      );

      await notifier.loadRoles();
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'roles failed',
      );
    },
  );

  test(
    'UserAdminController mutation failures return false and set error',
    () async {
      final repository = _FakeUserAdminRepository()
        ..updateResult = const Result<void>.failure(
          UnexpectedFailure('update failed'),
        )
        ..enableResult = const Result<void>.failure(
          UnexpectedFailure('enable failed'),
        )
        ..disableResult = const Result<void>.failure(
          UnexpectedFailure('disable failed'),
        )
        ..resetResult = const Result<void>.failure(
          UnexpectedFailure('reset failed'),
        )
        ..editRolesResult = const Result<void>.failure(
          UnexpectedFailure('roles failed'),
        );
      final container = ProviderContainer(
        overrides: <Override>[
          authControllerProvider.overrideWith(() => _TestAuthController()),
          userAdminRepositoryProvider.overrideWithValue(repository),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(userAdminControllerProvider.notifier);

      final updateOk = await notifier.updateUser(
        const UpdateUserInput(
          userId: 'u1',
          personId: 'p1',
          firstName: 'Alice',
          lastName: 'Example',
          email: 'alice@example.com',
        ),
      );
      expect(updateOk, isFalse);
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'update failed',
      );

      final enableOk = await notifier.enableUser('u1');
      expect(enableOk, isFalse);
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'enable failed',
      );

      final disableOk = await notifier.disableUser('u1');
      expect(disableOk, isFalse);
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'disable failed',
      );

      final resetOk = await notifier.resetUserPasswordAdmin(
        const UserResetPasswordAdminInput(
          userId: 'u1',
          newPassword: 'secret',
          confirmNewPassword: 'secret',
        ),
      );
      expect(resetOk, isFalse);
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'reset failed',
      );

      final rolesOk = await notifier.editUserRoles(
        const EditUserRolesInput(userId: 'u1', roles: <String>['role:a']),
      );
      expect(rolesOk, isFalse);
      expect(
        container.read(userAdminControllerProvider).errorMessage,
        'roles failed',
      );
    },
  );
}

class _TestAuthController extends AuthController {
  @override
  AuthControllerState build() {
    return const AuthControllerState(
      isLoading: false,
      session: AuthSession(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u-admin',
        username: 'admin',
        roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
      ),
    );
  }

  @override
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    return true;
  }

  @override
  Future<bool> logout() async => true;

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;
}

class _FakeUserAdminRepository implements UserAdminRepository {
  Result<PageResult<UserEntity>> fetchUsersResult =
      const Result<PageResult<UserEntity>>.success(
        PageResult<UserEntity>(
          items: <UserEntity>[],
          total: 0,
          page: 1,
          pageSize: 5,
        ),
      );
  Result<List<UserRoleEntity>> fetchRolesResult =
      const Result<List<UserRoleEntity>>.success(<UserRoleEntity>[]);
  Result<void> registerResult = const Result<void>.success(null);
  Result<void> updateResult = const Result<void>.success(null);
  Result<void> disableResult = const Result<void>.success(null);
  Result<void> enableResult = const Result<void>.success(null);
  Result<void> resetResult = const Result<void>.success(null);
  Result<void> editRolesResult = const Result<void>.success(null);

  @override
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) async {
    return disableResult;
  }

  @override
  Future<Result<void>> editUserRoles(EditUserRolesInput input) async {
    return editRolesResult;
  }

  @override
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) async {
    return enableResult;
  }

  @override
  Future<Result<List<UserRoleEntity>>> fetchRoles() async {
    return fetchRolesResult;
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    return fetchUsersResult;
  }

  @override
  Future<Result<void>> registerUser(UserRegistrationInput input) async {
    return registerResult;
  }

  @override
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) async {
    return resetResult;
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    return updateResult;
  }
}
