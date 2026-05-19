import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/repositories/tenant_admin_repository.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/providers/tenant_admin_providers.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/widgets/tenant_management_panel.dart';
import 'package:mugen_ui/features/user_admin/application/dto/delete_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/revoke_user_session_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/person_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

void main() {
  testWidgets(
    'TenantManagementPanel renders tenants and supports search + paging',
    (WidgetTester tester) async {
      final repository = _FakeTenantAdminRepository();
      await _pumpPanel(tester, repository);
      await tester.pumpAndSettle();

      expect(find.text('Tenant 1'), findsOneWidget);
      expect(find.byTooltip('Deactivate tenant'), findsWidgets);
      expect(find.byTooltip('Reactivate tenant'), findsWidgets);
      final selectedTenantTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Tenant 1'),
          matching: find.byType(ListTile),
        ),
      );
      expect(selectedTenantTile.selected, isTrue);
      expect(selectedTenantTile.selectedTileColor, AppUiPalette.accentSoft);
      final selectedTenantTitle = tester.widget<Text>(find.text('Tenant 1'));
      expect(selectedTenantTitle.style?.fontWeight, FontWeight.w700);
      expect(
        _tabTooltipMessage(
          tester,
          const Key('tenant-management-tab-domains-info'),
        ),
        'Verified tenant domains used to identify tenant-owned traffic.',
      );
      expect(
        _tabTooltipMessage(
          tester,
          const Key('tenant-management-tab-invitations-info'),
        ),
        'Pending invitations for adding users to this tenant.',
      );
      expect(
        _tabTooltipMessage(
          tester,
          const Key('tenant-management-tab-memberships-info'),
        ),
        'Users assigned to this tenant and their tenant roles.',
      );

      await tester.tap(find.byTooltip('Next page'));
      await tester.pumpAndSettle();
      expect(repository.lastTenantQuery?.pageRequest.page, 2);

      await tester.tap(find.byTooltip('Previous page'));
      await tester.pumpAndSettle();
      expect(repository.lastTenantQuery?.pageRequest.page, 1);

      await tester.tap(find.byType(DropdownButton<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('25').last);
      await tester.pumpAndSettle();
      expect(repository.lastTenantQuery?.pageRequest.pageSize, 25);

      await tester.enterText(
        find.byKey(const Key('tenant-management-search-field')),
        'tenant 2',
      );
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();
      expect(repository.lastTenantQuery?.searchTerm, 'tenant 2');
    },
  );

  testWidgets('TenantManagementPanel create/edit/lifecycle actions', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTenantAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('tenant-management-new-tenant-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Tenant'));
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsNWidgets(2));
    await _fillDialogFields(
      tester,
      values: <String>['New Tenant', 'new-tenant'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Tenant'));
    await tester.pumpAndSettle();
    expect(repository.createTenantInputs, hasLength(1));
    expect(find.text('Create Tenant'), findsNothing);

    await tester.tap(find.byTooltip('Edit tenant').first);
    await tester.pumpAndSettle();
    await _fillDialogFields(
      tester,
      values: <String>['Tenant Updated', 'tenant-updated'],
    );
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(repository.updateTenantInputs, hasLength(1));

    await tester.tap(find.byTooltip('Deactivate tenant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deactivateInputs, hasLength(1));

    await tester.tap(find.byTooltip('Reactivate tenant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.reactivateInputs, hasLength(1));
  });

  testWidgets('TenantManagementPanel domain/invite/membership workflows', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTenantAdminRepository();
    final userRepository = _FakeUserAdminRepository();
    await _pumpPanel(tester, repository, userRepository: userRepository);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Add Domain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Domain').last);
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsOneWidget);
    await _fillDialogFields(tester, values: <String>['domain.example.com']);
    await tester.tap(find.text('Primary domain'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Domain').last);
    await tester.pumpAndSettle();
    expect(repository.createDomainInputs, hasLength(1));

    await tester.tap(find.byTooltip('Edit domain').first);
    await tester.pumpAndSettle();
    await _fillDialogFields(tester, values: <String>['edited.example.com']);
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(repository.updateDomainInputs, hasLength(1));

    await tester.tap(find.byTooltip('Delete domain').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteDomainInputs, isEmpty);
    await tester.tap(find.byTooltip('Delete domain').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteDomainInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('tenant-management-tab-invitations')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite Member'));
    await tester.pumpAndSettle();
    await _fillDialogFields(
      tester,
      values: <String>['member@example.com', 'member'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Invitation'));
    await tester.pumpAndSettle();
    expect(repository.createInvitationInputs, hasLength(1));

    final resendButtons = tester.widgetList<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.forward_to_inbox_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(resendButtons.any((button) => button.onPressed == null), isTrue);
    expect(resendButtons.any((button) => button.onPressed != null), isTrue);
    final revokeButtons = tester.widgetList<IconButton>(
      find.ancestor(
        of: find.byIcon(Icons.cancel_outlined),
        matching: find.byType(IconButton),
      ),
    );
    expect(revokeButtons.any((button) => button.onPressed == null), isTrue);
    expect(revokeButtons.any((button) => button.onPressed != null), isTrue);

    await tester.tap(find.byTooltip('Resend invitation').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Revoke invitation').first);
    await tester.pumpAndSettle();
    expect(repository.resendInvitationInputs, hasLength(1));
    expect(repository.revokeInvitationInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('tenant-management-tab-memberships')),
    );
    await tester.pumpAndSettle();
    expect(find.text('existing.member'), findsOneWidget);
    expect(find.textContaining('existing.member@example.com'), findsOneWidget);
    await tester.tap(find.text('Add Membership'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Membership').last);
    await tester.pumpAndSettle();
    expect(find.text('Select a user.'), findsOneWidget);

    await _searchMembershipUsers(tester, 'member');
    expect(userRepository.lastUserQuery?.pageRequest.page, 1);
    expect(userRepository.lastUserQuery?.pageRequest.pageSize, 20);
    expect(userRepository.lastUserQuery?.searchTerm, 'member');
    expect(find.text('Already a tenant member'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const Key('tenant-membership-user-option-u-1')),
      warnIfMissed: false,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Membership').last);
    await tester.pumpAndSettle();
    expect(repository.createMembershipInputs, isEmpty);
    expect(find.text('Select a user.'), findsOneWidget);

    await _searchAndSelectMembershipUser(tester, 'charlie', 'u-55');
    await tester.tap(find.text('Add Membership').last);
    await tester.pumpAndSettle();
    expect(repository.createMembershipInputs, hasLength(1));
    expect(repository.createMembershipInputs.single.userId, 'u-55');
    expect(repository.createMembershipInputs.single.roleInTenant, 'member');

    await tester.tap(find.text('Add Membership'));
    await tester.pumpAndSettle();
    await _searchAndSelectMembershipUser(tester, 'dana', 'u-99');
    await _selectMembershipRole(tester, 'Admin');
    await tester.tap(find.text('Add Membership').last);
    await tester.pumpAndSettle();
    expect(repository.createMembershipInputs, hasLength(2));
    expect(repository.createMembershipInputs.last.userId, 'u-99');
    expect(repository.createMembershipInputs.last.roleInTenant, 'admin');

    await tester.tap(find.byTooltip('Edit membership role').first);
    await tester.pumpAndSettle();
    expect(
      find.text('existing.member  |  existing.member@example.com'),
      findsWidgets,
    );
    await _selectMembershipRole(tester, 'Owner');
    await tester.tap(find.text('Save').last);
    await tester.pumpAndSettle();
    expect(repository.updateMembershipInputs, hasLength(1));
    expect(repository.updateMembershipInputs.single.roleInTenant, 'owner');

    await tester.tap(find.byTooltip('Suspend membership').first);
    await tester.pumpAndSettle();
    expect(repository.suspendMembershipInputs, hasLength(1));

    await tester.tap(find.byTooltip('Unsuspend membership').first);
    await tester.pumpAndSettle();
    expect(repository.unsuspendMembershipInputs, hasLength(1));

    await tester.tap(find.byTooltip('Remove membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.removeMembershipInputs, isEmpty);
    await tester.tap(find.byTooltip('Remove membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove'));
    await tester.pumpAndSettle();
    expect(repository.removeMembershipInputs, hasLength(1));
  });

  testWidgets('TenantManagementPanel keeps dialogs open on mutation failures', (
    WidgetTester tester,
  ) async {
    final repository = _FakeTenantAdminRepository()
      ..mutationShouldSucceed = false;
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('tenant-management-new-tenant-button')),
    );
    await tester.pumpAndSettle();
    await _fillDialogFields(
      tester,
      values: <String>['Failure Tenant', 'failure-tenant'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Tenant'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(repository.createTenantInputs, hasLength(1));
  });

  testWidgets(
    'TenantManagementPanel membership picker handles search edge cases',
    (WidgetTester tester) async {
      final repository = _FakeTenantAdminRepository();
      final userRepository = _FakeUserAdminRepository();
      await _pumpPanel(tester, repository, userRepository: userRepository);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('tenant-management-tab-memberships')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Membership'));
      await tester.pumpAndSettle();

      userRepository.searchShouldFail = true;
      await _searchMembershipUsers(tester, 'error');
      expect(find.text('user search failed'), findsOneWidget);

      userRepository.searchShouldFail = false;
      await _searchMembershipUsers(tester, 'z');
      expect(find.text('No users found.'), findsOneWidget);

      await _searchMembershipUsers(tester, '');
      expect(find.text('No users found.'), findsNothing);

      await _searchAndSelectMembershipUser(tester, 'blank', 'u-empty');
      expect(
        find.text('blank.user  |  blank.user@example.com'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      final legacyMembershipTile = find.ancestor(
        of: find.text('u-legacy'),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: legacyMembershipTile,
          matching: find.byTooltip('Edit membership role'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('billing'), findsOneWidget);
      await tester.tap(find.text('Save').last);
      await tester.pumpAndSettle();
      expect(repository.updateMembershipInputs.single.roleInTenant, 'billing');
    },
  );

  testWidgets(
    'TenantManagementPanel covers refresh, loading, and cancel paths',
    (WidgetTester tester) async {
      final repository = _FakeTenantAdminRepository()
        ..fetchTenantsDelay = const Duration(milliseconds: 500)
        ..fetchDetailsDelay = const Duration(milliseconds: 500)
        ..returnEmptyDetails = true;
      await _pumpPanel(tester, repository);
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(TextButton, 'Refresh'));
      await tester.pump();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tenant 2'));
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('tenant-management-tab-invitations')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('tenant-management-tab-domains')));
      await tester.pumpAndSettle();
      expect(find.text('No domains added.'), findsOneWidget);

      await tester.tap(
        find.byKey(const Key('tenant-management-new-tenant-button')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add Domain'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('tenant-management-tab-invitations')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invite Member'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('tenant-management-tab-memberships')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Add Membership'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
      await tester.pumpAndSettle();
    },
  );
}

String? _tabTooltipMessage(WidgetTester tester, Key tabKey) {
  final tooltip = tester.widget<Tooltip>(find.byKey(tabKey));
  return tooltip.message;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeTenantAdminRepository repository, {
  _FakeUserAdminRepository? userRepository,
}) async {
  final resolvedUserRepository = userRepository ?? _FakeUserAdminRepository();
  await tester.binding.setSurfaceSize(const Size(1800, 1300));
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        tenantAdminRepositoryProvider.overrideWithValue(repository),
        userAdminRepositoryProvider.overrideWithValue(resolvedUserRepository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
        appNavigatorProvider.overrideWith((ref) => _FakeAppNavigator()),
        snackBarDispatcherProvider.overrideWith((ref) => _RecordingSnackBars()),
      ],
      child: const MaterialApp(home: Scaffold(body: TenantManagementPanel())),
    ),
  );
}

Future<void> _fillDialogFields(
  WidgetTester tester, {
  required List<String> values,
}) async {
  final fields = find.descendant(
    of: find.byType(Dialog).last,
    matching: find.byType(TextFormField),
  );
  for (var i = 0; i < values.length; i++) {
    await tester.enterText(fields.at(i), values[i]);
  }
}

Future<void> _searchMembershipUsers(
  WidgetTester tester,
  String searchTerm,
) async {
  await tester.enterText(
    find.byKey(const Key('tenant-membership-user-search-field')),
    searchTerm,
  );
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pumpAndSettle();
}

Future<void> _searchAndSelectMembershipUser(
  WidgetTester tester,
  String searchTerm,
  String userId,
) async {
  await _searchMembershipUsers(tester, searchTerm);
  await tester.tap(find.byKey(Key('tenant-membership-user-option-$userId')));
  await tester.pumpAndSettle();
  expect(
    find.byKey(const Key('tenant-membership-selected-user')),
    findsOneWidget,
  );
}

Future<void> _selectMembershipRole(
  WidgetTester tester,
  String roleLabel,
) async {
  await tester.tap(find.byKey(const Key('tenant-membership-role-dropdown')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(roleLabel).last);
  await tester.pumpAndSettle();
}

class _TestAuthController extends AuthController {
  @override
  AuthControllerState build() {
    return const AuthControllerState(isLoading: false, session: null);
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

class _FakeAppNavigator extends AppNavigator {}

class _RecordingSnackBars extends SnackBarDispatcher {
  @override
  void show(AppNavigator navigator, String content) {}
}

class _FakeUserAdminRepository implements UserAdminRepository {
  _FakeUserAdminRepository()
    : _users = <UserEntity>[
        _user(
          id: 'u-1',
          userName: 'existing.member',
          email: 'existing.member@example.com',
          firstName: 'Existing',
          lastName: 'Member',
        ),
        _user(
          id: 'u-2',
          userName: 'suspended.member',
          email: 'suspended.member@example.com',
          firstName: 'Suspended',
          lastName: 'Member',
        ),
        _user(
          id: 'u-55',
          userName: 'charlie.picker',
          email: 'charlie.picker@example.com',
          firstName: 'Charlie',
          lastName: 'Picker',
        ),
        _user(
          id: 'u-99',
          userName: 'dana.admin',
          email: 'dana.admin@example.com',
          firstName: 'Dana',
          lastName: 'Admin',
        ),
        _user(
          id: 'u-empty',
          userName: 'blank.user',
          email: 'blank.user@example.com',
          firstName: '',
          lastName: '',
        ),
      ];

  final List<UserEntity> _users;
  UserListQuery? lastUserQuery;
  bool searchShouldFail = false;

  @override
  Future<Result<void>> deleteUser(DeleteUserInput input) async {
    return const Result<void>.success(null);
  }

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
  Future<Result<List<UserSessionEntity>>> fetchUserSessions(
    String userId,
  ) async {
    return const Result<List<UserSessionEntity>>.success(<UserSessionEntity>[]);
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    lastUserQuery = query;
    if (searchShouldFail) {
      return const Result<PageResult<UserEntity>>.failure(
        UnexpectedFailure('user search failed'),
      );
    }

    final term = query.searchTerm?.trim().toLowerCase() ?? '';
    final filtered = _users
        .where((user) {
          if (term.isEmpty) {
            return true;
          }

          final fullName = '${user.person.firstName} ${user.person.lastName}'
              .toLowerCase();
          return user.userName.toLowerCase().contains(term) ||
              user.email.toLowerCase().contains(term) ||
              fullName.contains(term);
        })
        .toList(growable: false);

    final pageSize = query.pageRequest.pageSize;
    final items = pageSize <= 0 || filtered.length <= pageSize
        ? filtered
        : filtered.take(pageSize).toList(growable: false);
    return Result<PageResult<UserEntity>>.success(
      PageResult<UserEntity>(
        items: items,
        total: filtered.length,
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
  Future<Result<void>> revokeUserSession(RevokeUserSessionInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    return const Result<void>.success(null);
  }

  static UserEntity _user({
    required String id,
    required String userName,
    required String email,
    required String firstName,
    required String lastName,
  }) {
    return UserEntity(
      id: id,
      userName: userName,
      email: email,
      personRef: 'person-$id',
      dateCreated: DateTime.utc(2024, 1, 1),
      dateLastModified: DateTime.utc(2024, 1, 1),
      deleted: false,
      isLocked: false,
      rowVersion: 1,
      seedData: false,
      person: PersonEntity(
        id: 'person-$id',
        firstName: firstName,
        lastName: lastName,
        fullName: '$firstName $lastName'.trim(),
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
      roles: const <String>[],
    );
  }
}

class _FakeTenantAdminRepository implements TenantAdminRepository {
  _FakeTenantAdminRepository()
    : _tenants = List<TenantEntity>.generate(40, (index) {
        final id = index + 1;
        final isEven = id.isEven;
        return TenantEntity(
          id: 't-$id',
          name: 'Tenant $id',
          slug: 'tenant-$id',
          status: isEven ? 'Inactive' : 'Active',
          rowVersion: id,
          dateCreated: DateTime.utc(2024, 1, id.clamp(1, 28)),
          dateLastModified: DateTime.utc(2024, 1, id.clamp(1, 28)),
          deleted: false,
          seedData: false,
        );
      }),
      _domains = <TenantDomainEntity>[
        TenantDomainEntity(
          id: 'd-1',
          tenantId: 't-1',
          domain: 'tenant1.example.com',
          isPrimary: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        TenantDomainEntity(
          id: 'd-2',
          tenantId: 't-1',
          domain: 'tenant1-secondary.example.com',
          isPrimary: false,
          rowVersion: 2,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _invitations = <TenantInvitationEntity>[
        TenantInvitationEntity(
          id: 'i-1',
          tenantId: 't-1',
          email: 'pending@example.com',
          roleInTenant: 'member',
          status: 'Pending',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          expiresAt: DateTime.utc(2024, 1, 2),
          deleted: false,
          seedData: false,
        ),
        TenantInvitationEntity(
          id: 'i-2',
          tenantId: 't-1',
          email: 'revoked@example.com',
          roleInTenant: 'member',
          status: 'Revoked',
          rowVersion: 2,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          expiresAt: DateTime.utc(2024, 1, 2),
          deleted: false,
          seedData: false,
        ),
      ],
      _memberships = <TenantMembershipEntity>[
        TenantMembershipEntity(
          id: 'm-1',
          tenantId: 't-1',
          userId: 'u-1',
          userName: 'existing.member',
          userEmail: 'existing.member@example.com',
          roleInTenant: 'member',
          status: 'Active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        TenantMembershipEntity(
          id: 'm-2',
          tenantId: 't-1',
          userId: 'u-2',
          userName: 'suspended.member',
          userEmail: 'suspended.member@example.com',
          roleInTenant: 'member',
          status: 'Suspended',
          rowVersion: 2,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        TenantMembershipEntity(
          id: 'm-3',
          tenantId: 't-1',
          userId: 'u-legacy',
          roleInTenant: 'billing',
          status: 'Active',
          rowVersion: 3,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ];

  final List<TenantEntity> _tenants;
  final List<TenantDomainEntity> _domains;
  final List<TenantInvitationEntity> _invitations;
  final List<TenantMembershipEntity> _memberships;

  bool mutationShouldSucceed = true;
  bool returnEmptyDetails = false;
  Duration? fetchTenantsDelay;
  Duration? fetchDetailsDelay;

  TenantListQuery? lastTenantQuery;
  final List<CreateTenantInput> createTenantInputs = <CreateTenantInput>[];
  final List<UpdateTenantInput> updateTenantInputs = <UpdateTenantInput>[];
  final List<TenantLifecycleInput> deactivateInputs = <TenantLifecycleInput>[];
  final List<TenantLifecycleInput> reactivateInputs = <TenantLifecycleInput>[];
  final List<CreateTenantDomainInput> createDomainInputs =
      <CreateTenantDomainInput>[];
  final List<UpdateTenantDomainInput> updateDomainInputs =
      <UpdateTenantDomainInput>[];
  final List<DeleteTenantDomainInput> deleteDomainInputs =
      <DeleteTenantDomainInput>[];
  final List<CreateTenantInvitationInput> createInvitationInputs =
      <CreateTenantInvitationInput>[];
  final List<TenantInvitationActionInput> resendInvitationInputs =
      <TenantInvitationActionInput>[];
  final List<TenantInvitationActionInput> revokeInvitationInputs =
      <TenantInvitationActionInput>[];
  final List<CreateTenantMembershipInput> createMembershipInputs =
      <CreateTenantMembershipInput>[];
  final List<UpdateTenantMembershipInput> updateMembershipInputs =
      <UpdateTenantMembershipInput>[];
  final List<TenantMembershipActionInput> suspendMembershipInputs =
      <TenantMembershipActionInput>[];
  final List<TenantMembershipActionInput> unsuspendMembershipInputs =
      <TenantMembershipActionInput>[];
  final List<TenantMembershipActionInput> removeMembershipInputs =
      <TenantMembershipActionInput>[];

  @override
  Future<Result<void>> createTenant(CreateTenantInput input) async {
    createTenantInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantDomain(CreateTenantDomainInput input) async {
    createDomainInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantInvitation(
    CreateTenantInvitationInput input,
  ) async {
    createInvitationInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantMembership(
    CreateTenantMembershipInput input,
  ) async {
    createMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deactivateTenant(TenantLifecycleInput input) async {
    deactivateInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteTenantDomain(DeleteTenantDomainInput input) async {
    deleteDomainInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<List<TenantDomainEntity>>> fetchTenantDomains({
    required String tenantId,
    int top = 100,
  }) async {
    if (fetchDetailsDelay != null) {
      await Future<void>.delayed(fetchDetailsDelay!);
    }
    if (returnEmptyDetails) {
      return const Result<List<TenantDomainEntity>>.success(
        <TenantDomainEntity>[],
      );
    }
    return Result<List<TenantDomainEntity>>.success(_domains);
  }

  @override
  Future<Result<List<TenantInvitationEntity>>> fetchTenantInvitations({
    required String tenantId,
    int top = 100,
  }) async {
    if (fetchDetailsDelay != null) {
      await Future<void>.delayed(fetchDetailsDelay!);
    }
    if (returnEmptyDetails) {
      return const Result<List<TenantInvitationEntity>>.success(
        <TenantInvitationEntity>[],
      );
    }
    return Result<List<TenantInvitationEntity>>.success(_invitations);
  }

  @override
  Future<Result<List<TenantMembershipEntity>>> fetchTenantMemberships({
    required String tenantId,
    int top = 100,
  }) async {
    if (fetchDetailsDelay != null) {
      await Future<void>.delayed(fetchDetailsDelay!);
    }
    if (returnEmptyDetails) {
      return const Result<List<TenantMembershipEntity>>.success(
        <TenantMembershipEntity>[],
      );
    }
    return Result<List<TenantMembershipEntity>>.success(_memberships);
  }

  @override
  Future<Result<PageResult<TenantEntity>>> fetchTenants(
    TenantListQuery query,
  ) async {
    if (fetchTenantsDelay != null) {
      await Future<void>.delayed(fetchTenantsDelay!);
    }
    lastTenantQuery = query;
    final term = query.searchTerm?.toLowerCase().trim() ?? '';
    final filtered = _tenants
        .where((tenant) {
          if (term.isEmpty) {
            return true;
          }

          return tenant.name.toLowerCase().contains(term) ||
              tenant.slug.toLowerCase().contains(term);
        })
        .toList(growable: false);

    final page = query.pageRequest.page;
    final pageSize = query.pageRequest.pageSize;
    final safePageSize = pageSize <= 0 ? filtered.length : pageSize;
    final start = (page - 1) * safePageSize;
    final end = math.min(start + safePageSize, filtered.length);
    final items = start >= filtered.length
        ? const <TenantEntity>[]
        : filtered.sublist(start, end);
    return Result<PageResult<TenantEntity>>.success(
      PageResult<TenantEntity>(
        items: items,
        total: filtered.length,
        page: page,
        pageSize: pageSize,
      ),
    );
  }

  @override
  Future<Result<void>> reactivateTenant(TenantLifecycleInput input) async {
    reactivateInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> removeTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    removeMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> resendTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    resendInvitationInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> revokeTenantInvitation(
    TenantInvitationActionInput input,
  ) async {
    revokeInvitationInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> suspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    suspendMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> unsuspendTenantMembership(
    TenantMembershipActionInput input,
  ) async {
    unsuspendMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenant(UpdateTenantInput input) async {
    updateTenantInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantDomain(UpdateTenantDomainInput input) async {
    updateDomainInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantMembership(
    UpdateTenantMembershipInput input,
  ) async {
    updateMembershipInputs.add(input);
    return _mutationResult();
  }

  Result<void> _mutationResult() {
    if (!mutationShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('mutation failed'));
    }

    return const Result<void>.success(null);
  }
}
