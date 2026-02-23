import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/settings_panel.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  testWidgets(
    'ShellSettingsPanel hides admin-only panels for non-admin users',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            authRepositoryProvider.overrideWithValue(
              _FakeAuthRepository(
                const AuthSession(
                  accessToken: 'a',
                  refreshToken: 'r',
                  userId: 'u1',
                  roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ShellSettingsPanel())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Reset Password'), findsOneWidget);
      expect(find.text('Local Users'), findsNothing);
    },
  );

  testWidgets('ShellSettingsPanel opens account overlay on tap', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              const AuthSession(
                accessToken: 'a',
                refreshToken: 'r',
                userId: 'u1',
                roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
              ),
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShellSettingsPanel())),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('Current password'), findsNothing);

    await tester.tap(find.text('Reset Password'));
    await tester.pumpAndSettle();

    expect(find.text('Current password'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
  });

  testWidgets('ShellSettingsPanel opens local users overlay on tap', (
    WidgetTester tester,
  ) async {
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(
        settingsPanels: <SettingsPanelConfig>[
          SettingsPanelConfig(
            title: 'Reset Password',
            icon: Icons.security,
            roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
            type: SettingsPanelType.account,
          ),
          SettingsPanelConfig(
            title: 'Local Users',
            icon: Icons.groups_outlined,
            roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
            type: SettingsPanelType.users,
          ),
        ],
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => config),
          authRepositoryProvider.overrideWithValue(
            _FakeAuthRepository(
              const AuthSession(
                accessToken: 'a',
                refreshToken: 'r',
                userId: 'u1',
                roles: <String>[
                  'com.vorsocomputing.mugen.acp:administrator',
                  'com.vorsocomputing.mugen.acp:authenticated',
                ],
              ),
            ),
          ),
          userAdminRepositoryProvider.overrideWithValue(
            _FakeUserAdminRepository(),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ShellSettingsPanel())),
      ),
    );

    await tester.pumpAndSettle();
    expect(find.text('New User'), findsNothing);
    expect(find.byType(Divider), findsWidgets);

    await tester.tap(find.text('Local Users'));
    await tester.pumpAndSettle();

    expect(find.text('New User'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsNothing);
  });
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this.session);

  final AuthSession? session;

  @override
  Result<AuthSession?> currentSession() {
    return Result<AuthSession?>.success(session);
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    final userRoles = session?.roles ?? const <String>[];
    if (roles.isEmpty) {
      return const Result<bool>.success(true);
    }

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
  Future<Result<void>> logout() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return const Result<void>.success(null);
  }
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
        items: const <UserEntity>[],
        total: 0,
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
