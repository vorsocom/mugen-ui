import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/domain/usecases/fetch_users_usecase.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test('FetchUsersUseCase returns repository response', () async {
    final repository = _FakeUserAdminRepository();
    final useCase = FetchUsersUseCase(repository);

    final result = await useCase(
      const UserListQuery(pageRequest: PageRequest(page: 1, pageSize: 5)),
    );

    expect(result.isSuccess, isTrue);
    expect(result.data?.items.length, 1);
    expect(result.data?.items.first.userName, 'alice');
  });
}

class _FakeUserAdminRepository implements UserAdminRepository {
  @override
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> editUserRoles(EditUserRolesInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<List<UserRoleEntity>>> fetchRoles() async {
    return const Result<List<UserRoleEntity>>.success(<UserRoleEntity>[]);
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    return Result<PageResult<UserEntity>>.success(
      PageResult<UserEntity>(
        items: <UserEntity>[
          UserEntity(
            id: 'u1',
            userName: 'alice',
            email: 'alice@example.com',
            personRef: 'p1',
            dateCreated: DateTime.utc(2024, 1, 1),
            dateLastModified: DateTime.utc(2024, 1, 1),
            deleted: false,
            isLocked: false,
            rowVersion: 1,
            seedData: false,
            person: PersonEntity(
              id: 'p1',
              firstName: 'Alice',
              lastName: 'One',
              fullName: 'Alice One',
              dateCreated: DateTime.utc(2024, 1, 1),
              dateLastModified: DateTime.utc(2024, 1, 1),
              deleted: false,
              seedData: false,
            ),
            roles: const <String>[],
          ),
        ],
        total: 1,
        page: 1,
        pageSize: 5,
      ),
    );
  }

  @override
  Future<Result<void>> registerUser(UserRegistrationInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    return const Result<void>.success(null);
  }
}
