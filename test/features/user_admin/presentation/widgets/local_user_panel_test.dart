import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  testWidgets('LocalUserPanel renders fetched users', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(
            _StaticAuthRepository(
              const AuthSession(
                accessToken: 'a',
                refreshToken: 'r',
                userId: 'u1',
                username: 'admin',
                roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
              ),
            ),
          ),
          userAdminRepositoryProvider.overrideWithValue(
            _FakeUserAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: LocalUserPanel())),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('alice'), findsOneWidget);
  });
}

class _StaticAuthRepository implements AuthRepository {
  _StaticAuthRepository(this.session);

  final AuthSession? session;

  @override
  Result<AuthSession?> currentSession() =>
      Result<AuthSession?>.success(session);

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    final userRoles = session?.roles ?? const <String>[];
    if (operator == 'or') {
      return Result<bool>.success(roles.any(userRoles.contains));
    }
    return Result<bool>.success(roles.every(userRoles.contains));
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void>> logout() async => const Result<void>.success(null);

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async => const Result<void>.success(null);
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
    return Result<List<UserRoleEntity>>.success(<UserRoleEntity>[
      UserRoleEntity(
        id: 'r1',
        name: 'com.vorsocomputing.mugen.acp:administrator',
        displayName: 'Administrator',
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
    ]);
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    return Result<PageResult<UserEntity>>.success(
      PageResult<UserEntity>(
        items: <UserEntity>[
          UserEntity(
            id: 'u2',
            userName: 'alice',
            email: 'alice@example.com',
            personRef: 'p2',
            dateCreated: DateTime.utc(2024, 1, 1),
            dateLastModified: DateTime.utc(2024, 1, 1),
            deleted: false,
            isLocked: false,
            rowVersion: 1,
            seedData: false,
            person: PersonEntity(
              id: 'p2',
              firstName: 'Alice',
              lastName: 'One',
              fullName: 'Alice One',
              dateCreated: DateTime.utc(2024, 1, 1),
              dateLastModified: DateTime.utc(2024, 1, 1),
              deleted: false,
              seedData: false,
            ),
            roles: const <String>['r1'],
          ),
        ],
        total: 1,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
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
