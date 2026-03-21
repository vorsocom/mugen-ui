import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/delete_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/revoke_user_session_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  testWidgets(
    'LocalUserPanel renders fetched users and supports search + paging',
    (WidgetTester tester) async {
      final repository = _FakeUserAdminRepository();

      await _pumpPanel(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('alice'), findsOneWidget);
      expect(repository.fetchUsersQueries, isNotEmpty);

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.pageRequest.page, 2);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.pageRequest.page, 1);

      await tester.tap(find.byTooltip('Last page'));
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.pageRequest.page, 4);

      await tester.tap(find.byTooltip('First page'));
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.pageRequest.page, 1);

      await tester.enterText(find.byType(TextFormField).first, 'alice');
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.searchTerm, 'alice');
      expect(repository.fetchUsersQueries.last.pageRequest.page, 1);

      await tester.tap(find.byIcon(Icons.expand_more).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(repository.fetchUsersQueries.last.pageRequest.pageSize, 25);
    },
  );

  testWidgets('LocalUserPanel table scrolls when rows per page is 50', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository();

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.expand_more).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('50').last);
    await tester.pumpAndSettle();
    expect(repository.fetchUsersQueries.last.pageRequest.pageSize, 50);

    final tableFinder = find.byType(DataTable).first;
    final tableViewport = find
        .ancestor(of: tableFinder, matching: find.byType(ClipRRect))
        .first;
    final tableBottom = tester.getBottomLeft(tableViewport).dy;
    final targetRow = find.text('user50').first;
    final initialTargetY = tester.getTopLeft(targetRow).dy;
    expect(initialTargetY, greaterThan(tableBottom));

    await tester.drag(tableViewport, const Offset(0, -2200));
    await tester.pumpAndSettle();

    final scrolledTargetY = tester.getTopLeft(targetRow).dy;
    expect(scrolledTargetY, lessThan(tableBottom));
  });

  testWidgets('register dialog validates input and submits success/failure', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository();

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New User'));
    await tester.pumpAndSettle();
    expect(find.text('Add New User'), findsOneWidget);

    await tester.tap(find.text('Add User'));
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsWidgets);

    await _fillRegisterForm(
      tester,
      firstName: 'Casey',
      lastName: 'Admin',
      userName: 'casey',
      email: 'invalid-email',
      password: 'secret',
    );
    await tester.tap(find.text('Add User'));
    await tester.pumpAndSettle();
    expect(find.text('Email address must be valid'), findsOneWidget);

    await _fillRegisterForm(
      tester,
      firstName: 'Casey',
      lastName: 'Admin',
      userName: 'casey',
      email: 'casey@example.com',
      password: 'secret',
    );
    await tester.tap(find.text('Add User'));
    await tester.pumpAndSettle();
    expect(repository.registerInputs, hasLength(1));
    expect(repository.registerInputs.single.userName, 'casey');
    expect(find.text('Add New User'), findsNothing);

    repository.registerShouldSucceed = false;
    await tester.tap(find.text('New User'));
    await tester.pumpAndSettle();
    await _fillRegisterForm(
      tester,
      firstName: 'Fail',
      lastName: 'Case',
      userName: 'fails',
      email: 'fails@example.com',
      password: 'secret',
    );
    await tester.tap(find.text('Add User'));
    await tester.pumpAndSettle();
    expect(find.text('Add New User'), findsOneWidget);
    expect(repository.registerInputs, hasLength(2));
  });

  testWidgets(
    'edit details, reset password, and edit roles submit expected inputs',
    (WidgetTester tester) async {
      final repository = _FakeUserAdminRepository();

      await _pumpPanel(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Details').first);
      await tester.pumpAndSettle();
      expect(find.text('Edit User Details'), findsOneWidget);
      await _fillEditUserForm(
        tester,
        firstName: 'AliceUpdated',
        lastName: 'ExampleUpdated',
        email: 'alice.updated@example.com',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(repository.updateInputs, hasLength(1));
      expect(repository.updateInputs.single.firstName, 'AliceUpdated');

      await tester.tap(find.byTooltip('Reset Password').first);
      await tester.pumpAndSettle();
      await _fillResetPasswordForm(
        tester,
        newPassword: 'password-1',
        confirmPassword: 'password-2',
      );
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords must match.'), findsOneWidget);

      await _fillResetPasswordForm(
        tester,
        newPassword: 'password-1',
        confirmPassword: 'password-1',
      );
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(repository.resetPasswordInputs, hasLength(1));
      expect(repository.resetPasswordInputs.single.userId, 'u-1');

      await tester.tap(find.byTooltip('Edit Roles').first);
      await tester.pumpAndSettle();
      expect(find.textContaining('Edit User Roles - alice'), findsOneWidget);
      final checkboxes = find.byType(Checkbox);
      expect(checkboxes, findsWidgets);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Roles'));
      await tester.pumpAndSettle();
      expect(repository.editRolesInputs, hasLength(1));
      expect(repository.editRolesInputs.single.userId, 'u-1');
    },
  );

  testWidgets('enable/disable account actions honor confirmation flow', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository();

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Disable Account').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirmation Required'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.disableInputs, isEmpty);

    await tester.tap(find.byTooltip('Disable Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.disableInputs, hasLength(1));
    expect(repository.disableInputs.single.userId, 'u-1');

    await tester.tap(find.byTooltip('Enable Account').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.enableInputs, hasLength(1));
    expect(repository.enableInputs.single.userId, 'u-2');

    await tester.tap(find.byTooltip('Delete User').first);
    await tester.pumpAndSettle();
    expect(find.text('Confirmation Required'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete User').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete User'));
    await tester.pumpAndSettle();
    expect(repository.deleteInputs, hasLength(1));
    expect(repository.deleteInputs.single.userId, 'u-1');
  });

  testWidgets('sessions dialog loads, revokes, and refreshes sessions', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository();

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sessions').first);
    await tester.pumpAndSettle();

    expect(find.textContaining('Sessions - alice'), findsOneWidget);
    expect(repository.fetchSessionUserIds, contains('u-1'));
    expect(find.text('Revoke'), findsWidgets);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester.tap(find.text('Revoke').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Revoke Session'));
    await tester.pumpAndSettle();

    expect(repository.revokeSessionInputs, hasLength(1));
    expect(
      repository.revokeSessionInputs.single.refreshTokenId,
      'session-u-1-1',
    );
    expect(
      repository.fetchSessionUserIds.where((id) => id == 'u-1').length,
      greaterThanOrEqualTo(2),
    );

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sessions - alice'), findsNothing);
  });

  testWidgets('sessions dialog shows loading error when fetch fails', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository()
      ..fetchSessionsShouldSucceed = false;

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sessions').first);
    await tester.pumpAndSettle();

    expect(find.text('sessions failed'), findsOneWidget);
  });

  testWidgets('sessions dialog renders empty-state copy', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository()..emptySessions = true;

    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Sessions').first);
    await tester.pumpAndSettle();

    expect(
      find.text('No active sessions found for this user.'),
      findsOneWidget,
    );
  });

  testWidgets('loading state and cancel actions are rendered and wired', (
    WidgetTester tester,
  ) async {
    final repository = _FakeUserAdminRepository()
      ..fetchUsersDelay = const Duration(milliseconds: 600);

    await _pumpPanel(tester, repository);
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();

    await tester.tap(find.text('New User'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Add New User'), findsNothing);

    await tester.tap(find.byTooltip('Edit Details').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Edit User Details'), findsNothing);

    await tester.tap(find.byTooltip('Reset Password').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Reset User Password -'), findsNothing);
  });

  testWidgets(
    'failure branches show validation feedback and keep dialogs open',
    (WidgetTester tester) async {
      final repository = _FakeUserAdminRepository()
        ..updateShouldSucceed = false
        ..resetPasswordShouldSucceed = false
        ..editRolesShouldSucceed = false
        ..disableShouldSucceed = false
        ..enableShouldSucceed = false
        ..deleteShouldSucceed = false
        ..revokeSessionShouldSucceed = false;

      await _pumpPanel(tester, repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Details').at(1));
      await tester.pumpAndSettle();
      await _fillEditUserForm(
        tester,
        firstName: 'BobUpdated',
        lastName: 'TwoUpdated',
        email: 'bob.updated@example.com',
      );
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Edit User Details'), findsOneWidget);
      expect(repository.updateInputs.last.personId, 'p-2');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Reset Password').first);
      await tester.pumpAndSettle();
      await _fillResetPasswordForm(
        tester,
        newPassword: 'password-1',
        confirmPassword: 'password-1',
      );
      await tester.tap(find.text('Reset Password'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Reset User Password -'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Edit Roles').at(1));
      await tester.pumpAndSettle();
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save Roles'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Edit User Roles -'), findsOneWidget);
      expect(repository.editRolesInputs, hasLength(1));
      expect(
        repository.editRolesInputs.single.roles,
        contains('com.vorsocomputing.mugen.acp:administrator'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Disable Account').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(repository.disableInputs, hasLength(1));

      await tester.tap(find.byTooltip('Enable Account').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(repository.enableInputs, hasLength(1));

      await tester.tap(find.byTooltip('Delete User').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete User'));
      await tester.pumpAndSettle();
      expect(repository.deleteInputs, hasLength(1));

      await tester.tap(find.byTooltip('Sessions').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revoke Session'));
      await tester.pumpAndSettle();
      expect(repository.revokeSessionInputs, hasLength(1));
    },
  );
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeUserAdminRepository repository,
) async {
  await tester.binding.setSurfaceSize(const Size(1600, 1200));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        authRepositoryProvider.overrideWithValue(
          _StaticAuthRepository(
            const AuthSession(
              accessToken: 'a',
              refreshToken: 'r',
              userId: 'u-admin',
              username: 'admin',
              roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
            ),
          ),
        ),
        userAdminRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: Scaffold(body: LocalUserPanel())),
    ),
  );
}

Future<void> _fillRegisterForm(
  WidgetTester tester, {
  required String firstName,
  required String lastName,
  required String userName,
  required String email,
  required String password,
}) async {
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.at(0), firstName);
  await tester.enterText(fields.at(1), lastName);
  await tester.enterText(fields.at(2), userName);
  await tester.enterText(fields.at(3), email);
  await tester.enterText(fields.at(4), password);
}

Future<void> _fillEditUserForm(
  WidgetTester tester, {
  required String firstName,
  required String lastName,
  required String email,
}) async {
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.at(0), firstName);
  await tester.enterText(fields.at(1), lastName);
  await tester.enterText(fields.at(2), email);
}

Future<void> _fillResetPasswordForm(
  WidgetTester tester, {
  required String newPassword,
  required String confirmPassword,
}) async {
  final fields = find.descendant(
    of: find.byType(Dialog),
    matching: find.byType(TextFormField),
  );
  await tester.enterText(fields.at(0), newPassword);
  await tester.enterText(fields.at(1), confirmPassword);
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

  @override
  Future<Result<OwnProfileEntity>> fetchOwnProfile() async {
    return const Result<OwnProfileEntity>.failure(
      UnauthorizedFailure('Not implemented'),
    );
  }

  @override
  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input) async {
    return const Result<void>.success(null);
  }
}

class _FakeUserAdminRepository implements UserAdminRepository {
  _FakeUserAdminRepository()
    : _users = List<UserEntity>.generate(60, (index) {
        final id = index + 1;
        final locked = index == 1;
        return UserEntity(
          id: 'u-$id',
          userName: id == 1 ? 'alice' : (id == 2 ? 'bob' : 'user$id'),
          email: 'user$id@example.com',
          personRef: 'p-$id',
          dateCreated: DateTime.utc(2024, 1, id),
          dateLastModified: DateTime.utc(2024, 1, id),
          deleted: false,
          isLocked: locked,
          rowVersion: id,
          seedData: false,
          person: PersonEntity(
            id: id == 2 ? '' : 'p-$id',
            firstName: id == 1 ? 'Alice' : 'User$id',
            lastName: id == 1 ? 'One' : 'Example',
            fullName: id == 1 ? 'Alice One' : 'User$id Example',
            dateCreated: DateTime.utc(2024, 1, id),
            dateLastModified: DateTime.utc(2024, 1, id),
            deleted: false,
            seedData: false,
          ),
          roles: id == 1 ? const <String>['r1'] : const <String>['r2'],
        );
      }),
      _roles = <UserRoleEntity>[
        UserRoleEntity(
          id: 'r1',
          name: 'com.vorsocomputing.mugen.acp:administrator',
          displayName: 'Administrator',
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        UserRoleEntity(
          id: 'r2',
          name: 'com.vorsocomputing.mugen.acp:authenticated',
          displayName: 'Authenticated',
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ];

  final List<UserEntity> _users;
  final List<UserRoleEntity> _roles;

  bool registerShouldSucceed = true;
  bool updateShouldSucceed = true;
  bool resetPasswordShouldSucceed = true;
  bool editRolesShouldSucceed = true;
  bool disableShouldSucceed = true;
  bool enableShouldSucceed = true;
  bool deleteShouldSucceed = true;
  bool fetchSessionsShouldSucceed = true;
  bool emptySessions = false;
  bool revokeSessionShouldSucceed = true;
  Duration? fetchUsersDelay;

  final List<UserListQuery> fetchUsersQueries = <UserListQuery>[];
  final List<UserRegistrationInput> registerInputs = <UserRegistrationInput>[];
  final List<UpdateUserInput> updateInputs = <UpdateUserInput>[];
  final List<UserResetPasswordAdminInput> resetPasswordInputs =
      <UserResetPasswordAdminInput>[];
  final List<EditUserRolesInput> editRolesInputs = <EditUserRolesInput>[];
  final List<ToggleUserAccountInput> disableInputs = <ToggleUserAccountInput>[];
  final List<ToggleUserAccountInput> enableInputs = <ToggleUserAccountInput>[];
  final List<DeleteUserInput> deleteInputs = <DeleteUserInput>[];
  final List<String> fetchSessionUserIds = <String>[];
  final List<RevokeUserSessionInput> revokeSessionInputs =
      <RevokeUserSessionInput>[];

  @override
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) async {
    disableInputs.add(input);
    if (!disableShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('disable failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> editUserRoles(EditUserRolesInput input) async {
    editRolesInputs.add(input);
    if (!editRolesShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('roles failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) async {
    enableInputs.add(input);
    if (!enableShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('enable failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<List<UserRoleEntity>>> fetchRoles() async {
    return Result<List<UserRoleEntity>>.success(_roles);
  }

  @override
  Future<Result<List<UserSessionEntity>>> fetchUserSessions(
    String userId,
  ) async {
    fetchSessionUserIds.add(userId);
    if (!fetchSessionsShouldSucceed) {
      return const Result<List<UserSessionEntity>>.failure(
        UnexpectedFailure('sessions failed'),
      );
    }
    if (emptySessions) {
      return const Result<List<UserSessionEntity>>.success(
        <UserSessionEntity>[],
      );
    }
    return Result<List<UserSessionEntity>>.success(<UserSessionEntity>[
      UserSessionEntity(
        id: 'session-$userId-1',
        userId: userId,
        tokenJti: 'token-$userId-1',
        expiresAt: DateTime.utc(2030, 1, 2),
        dateCreated: DateTime.utc(2030, 1, 1),
        dateLastModified: DateTime.utc(2030, 1, 1),
      ),
      UserSessionEntity(
        id: 'session-$userId-2',
        userId: userId,
        tokenJti: 'token-$userId-2',
        expiresAt: DateTime.utc(2030, 1, 3),
        dateCreated: DateTime.utc(2030, 1, 2),
        dateLastModified: DateTime.utc(2030, 1, 2),
      ),
    ]);
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    if (fetchUsersDelay != null) {
      await Future<void>.delayed(fetchUsersDelay!);
    }
    fetchUsersQueries.add(query);

    final term = query.searchTerm?.toLowerCase().trim() ?? '';
    final filtered = _users
        .where((user) {
          if (query.excludeUserName != null &&
              user.userName == query.excludeUserName) {
            return false;
          }
          if (term.isEmpty) {
            return true;
          }
          return user.userName.toLowerCase().contains(term) ||
              user.email.toLowerCase().contains(term) ||
              user.person.firstName.toLowerCase().contains(term) ||
              user.person.lastName.toLowerCase().contains(term);
        })
        .toList(growable: false);

    final page = query.pageRequest.page;
    final pageSize = query.pageRequest.pageSize;
    List<UserEntity> paged = filtered;
    if (pageSize > 0) {
      final start = query.pageRequest.skip;
      final end = (start + pageSize).clamp(0, filtered.length);
      paged = start >= filtered.length
          ? const <UserEntity>[]
          : filtered.sublist(start, end);
    }

    return Result<PageResult<UserEntity>>.success(
      PageResult<UserEntity>(
        items: paged,
        total: filtered.length,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<Result<void>> registerUser(UserRegistrationInput input) async {
    registerInputs.add(input);
    if (!registerShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('register failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) async {
    resetPasswordInputs.add(input);
    if (!resetPasswordShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('reset failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    updateInputs.add(input);
    if (!updateShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('update failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteUser(DeleteUserInput input) async {
    deleteInputs.add(input);
    if (!deleteShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('delete failed'));
    }
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> revokeUserSession(RevokeUserSessionInput input) async {
    revokeSessionInputs.add(input);
    if (!revokeSessionShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('session failed'));
    }
    return const Result<void>.success(null);
  }
}
