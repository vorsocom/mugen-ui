import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_assignable_user_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/repositories/rbac_admin_repository.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/providers/rbac_admin_providers.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/widgets/rbac_management_panel.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/presentation/feedback/snackbar_dispatcher.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

void main() {
  testWidgets('RbacManagementPanel supports tab switching', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    expect(find.text('New Permission Object'), findsOneWidget);
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-global-roles-info'),
      ),
      'Platform-wide roles that can be granted outside a tenant.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-permission-objects-info'),
      ),
      'Protected object types that permissions can be granted on.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-permission-types-info'),
      ),
      'Actions that can be allowed or denied for permission objects.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-global-grants-info'),
      ),
      'Global role permissions that apply without tenant scope.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-global-role-memberships-info'),
      ),
      'Users assigned to global roles outside tenant scope.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-tenant-roles-info'),
      ),
      'Roles available only within the selected tenant.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-role-memberships-info'),
      ),
      'Users assigned to tenant roles in the selected tenant.',
    );
    expect(
      _tabTooltipMessage(
        tester,
        const Key('rbac-management-tab-tenant-grants-info'),
      ),
      'Permissions assigned to tenant roles in the selected tenant.',
    );

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-types')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Permission Type'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rbac-management-tab-global-roles')));
    await tester.pumpAndSettle();
    expect(find.text('New Global Role'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Global Grant'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-role-memberships')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Global Role Membership'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();
    expect(find.text('New Tenant Role'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Tenant Grant'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-role-memberships')),
    );
    await tester.pumpAndSettle();
    expect(find.text('New Tenant Role Membership'), findsOneWidget);
  });

  testWidgets('RbacManagementPanel filters active table rows', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()..addSearchFixturesForTest();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rbac-management-tab-global-roles')));
    await tester.pumpAndSettle();
    expect(find.text('Administrator'), findsOneWidget);
    expect(find.text('Auditor'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rbac-global-roles-search-field')),
      'auditor',
    );
    await tester.pumpAndSettle();
    expect(find.text('Auditor'), findsOneWidget);
    expect(find.text('Administrator'), findsNothing);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-objects')),
    );
    await tester.pumpAndSettle();
    expect(find.text('acp:tenant'), findsOneWidget);
    expect(find.text('acp:user'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rbac-permission-objects-search-field')),
      'user',
    );
    await tester.pumpAndSettle();
    expect(find.text('acp:user'), findsOneWidget);
    expect(find.text('acp:tenant'), findsNothing);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const Key('rbac-global-grants-search-field')),
      'read',
    );
    await tester.pumpAndSettle();
    expect(find.text('Auditor'), findsOneWidget);
    expect(find.text('Administrator'), findsNothing);
    expect(find.text('acp:user  |  acp:read'), findsOneWidget);
    expect(find.text('acp:tenant  |  acp:manage'), findsNothing);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-role-memberships')),
    );
    await tester.pumpAndSettle();
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('bob@example.com'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('rbac-role-memberships-search-field')),
      'auditor',
    );
    await tester.pumpAndSettle();
    expect(find.text('bob@example.com'), findsOneWidget);
    expect(find.text('alice@example.com'), findsNothing);
  });

  testWidgets('RbacManagementPanel validates role dialogs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rbac-management-tab-global-roles')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rbac-global-role-create-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Role'));
    await tester.pumpAndSettle();
    expect(find.text('Field cannot be empty.'), findsNWidgets(2));

    await _fillDialogFields(
      tester,
      values: <String>['acp', 'auditor', 'Auditor'],
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Role'));
    await tester.pumpAndSettle();

    expect(repository.createGlobalRoleInputs, hasLength(1));
    expect(find.text('Create Global Role'), findsNothing);

    await tester.tap(find.byTooltip('Edit global role').first);
    await tester.pumpAndSettle();
    await _fillDialogFields(tester, values: <String>['Administrator Updated']);
    await tester.tap(find.widgetWithText(FilledButton, 'Save Changes'));
    await tester.pumpAndSettle();
    expect(repository.updateGlobalRoleInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel lifecycle confirmations call actions', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-objects')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Deprecate permission object').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionObjectInputs, isEmpty);

    await tester.tap(find.byTooltip('Deprecate permission object').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionObjectInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-permission-types')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Deprecate permission type').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecatePermissionTypeInputs, hasLength(1));

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Deprecate tenant role').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.deprecateTenantRoleInputs, hasLength(1));

    await tester.tap(find.byTooltip('Reactivate tenant role').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(repository.reactivateTenantRoleInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel toggles and deletes grants', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Set denied').first);
    await tester.pumpAndSettle();
    expect(repository.updateGlobalPermissionEntryInputs, hasLength(1));

    await tester.tap(find.byTooltip('Delete global grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalPermissionEntryInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete global grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalPermissionEntryInputs, hasLength(1));

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Set denied').first);
    await tester.pumpAndSettle();
    expect(repository.updateTenantPermissionEntryInputs, hasLength(1));

    await tester.tap(find.byTooltip('Delete tenant grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantPermissionEntryInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete tenant grant').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantPermissionEntryInputs, hasLength(1));
  });

  testWidgets('RbacManagementPanel creates grants with searchable fields', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()..addSearchFixturesForTest();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rbac-global-grant-create-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Grant'));
    await tester.pumpAndSettle();
    expect(find.text('Select a role.'), findsOneWidget);
    expect(find.text('Select a permission object.'), findsOneWidget);
    expect(find.text('Select a permission type.'), findsOneWidget);
    expect(repository.createGlobalPermissionEntryInputs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('rbac-global-grant-role-search-field')),
      'auditor',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-global-grant-role-option-gr-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rbac-global-grant-role-option-gr-1')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('rbac-global-grant-role-option-gr-2')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-global-grant-selected-role')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('rbac-global-grant-permission-object-search-field')),
      'user',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-global-grant-permission-object-option-po-2')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rbac-global-grant-permission-type-search-field')),
      'read',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-global-grant-permission-type-option-pt-2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Global Grant'));
    await tester.pumpAndSettle();
    expect(repository.createGlobalPermissionEntryInputs, hasLength(1));
    expect(
      repository.createGlobalPermissionEntryInputs.single.globalRoleId,
      'gr-2',
    );
    expect(
      repository.createGlobalPermissionEntryInputs.single.permissionObjectId,
      'po-2',
    );
    expect(
      repository.createGlobalPermissionEntryInputs.single.permissionTypeId,
      'pt-2',
    );
    expect(
      repository.createGlobalPermissionEntryInputs.single.permitted,
      isTrue,
    );
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rbac-tenant-grant-create-button')));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rbac-tenant-grant-role-search-field')),
      'member',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-tenant-grant-role-option-tr-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rbac-tenant-grant-permission-object-search-field')),
      'tenant',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-tenant-grant-permission-object-option-po-1')),
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('rbac-tenant-grant-permission-type-search-field')),
      'manage',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-tenant-grant-permission-type-option-pt-1')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Create Tenant Grant'));
    await tester.pumpAndSettle();
    expect(repository.createTenantPermissionEntryInputs, hasLength(1));
    expect(
      repository.createTenantPermissionEntryInputs.single.tenantId,
      'tenant-1',
    );
    expect(repository.createTenantPermissionEntryInputs.single.roleId, 'tr-1');
    expect(
      repository.createTenantPermissionEntryInputs.single.permissionObjectId,
      'po-1',
    );
    expect(
      repository.createTenantPermissionEntryInputs.single.permissionTypeId,
      'pt-1',
    );
    expect(
      repository.createTenantPermissionEntryInputs.single.permitted,
      isTrue,
    );
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('RbacManagementPanel keeps long grant labels within dialogs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()
      ..replacePermissionCatalogForTest(
        permissionObject: RbacPermissionObjectEntity(
          id: 'po-long',
          namespace: 'com.vorsocomputing.mugen.acp',
          name: 'dedup_record',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
        permissionType: RbacPermissionTypeEntity(
          id: 'pt-long',
          namespace: 'com.vorsocomputing.mugen.acp',
          name: 'create',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      );
    await _pumpPanel(tester, repository, surfaceSize: const Size(640, 640));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-grants')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rbac-global-grant-create-button')));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('RbacManagementPanel manages global role memberships', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-global-role-memberships')),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Global Role Membership'), findsOneWidget);
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('Administrator  |  acp:administrator'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-global-role-membership-create-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Global Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a user.'), findsOneWidget);
    expect(find.text('Select a global role.'), findsOneWidget);
    expect(repository.createGlobalRoleMembershipInputs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('rbac-global-role-membership-user-search-field')),
      'alice-login',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-global-role-membership-user-option-user-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-global-role-membership-selected-user')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('rbac-global-role-membership-role-search-field')),
      'admin',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-global-role-membership-role-option-gr-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-global-role-membership-selected-role')),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Global Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(find.text('This user already has this role.'), findsOneWidget);
    expect(repository.createGlobalRoleMembershipInputs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('rbac-global-role-membership-user-search-field')),
      'bob',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-global-role-membership-user-option-user-2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Global Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(repository.createGlobalRoleMembershipInputs, hasLength(1));
    expect(repository.createGlobalRoleMembershipInputs.single.roleId, 'gr-1');
    expect(repository.createGlobalRoleMembershipInputs.single.userId, 'user-2');
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('Delete global role membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalRoleMembershipInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete global role membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteGlobalRoleMembershipInputs, hasLength(1));
    expect(
      repository.deleteGlobalRoleMembershipInputs.single.membershipId,
      'grm-1',
    );
    expect(repository.deleteGlobalRoleMembershipInputs.single.rowVersion, 8);
  });

  testWidgets('RbacManagementPanel manages tenant role memberships', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository();
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-role-memberships')),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Tenant Role Membership'), findsOneWidget);
    expect(
      find.text(
        'Users may need to sign out and back in for route and session claims to refresh.',
      ),
      findsOneWidget,
    );
    expect(find.text('alice@example.com'), findsOneWidget);
    expect(find.text('Member  |  acp:member'), findsOneWidget);

    await tester.tap(
      find.byKey(const Key('rbac-role-membership-create-button')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Tenant Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Select a user.'), findsOneWidget);
    expect(find.text('Select a role.'), findsOneWidget);
    expect(repository.createTenantRoleMembershipInputs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('rbac-role-membership-user-search-field')),
      'alice-login',
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('rbac-role-membership-user-option-user-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-role-membership-selected-user')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const Key('rbac-role-membership-role-search-field')),
      'member',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-role-membership-role-option-tr-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rbac-role-membership-role-option-tr-2')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('rbac-role-membership-role-option-tr-1')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-role-membership-selected-role')),
      findsOneWidget,
    );

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Tenant Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(find.text('This user already has this role.'), findsOneWidget);
    expect(repository.createTenantRoleMembershipInputs, isEmpty);

    await tester.enterText(
      find.byKey(const Key('rbac-role-membership-user-search-field')),
      'bob',
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('rbac-role-membership-user-option-user-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('rbac-role-membership-user-option-user-3')),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const Key('rbac-role-membership-user-option-user-2')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.widgetWithText(FilledButton, 'Create Tenant Role Membership'),
    );
    await tester.pumpAndSettle();
    expect(repository.createTenantRoleMembershipInputs, hasLength(1));
    expect(
      repository.createTenantRoleMembershipInputs.single.tenantId,
      'tenant-1',
    );
    expect(repository.createTenantRoleMembershipInputs.single.roleId, 'tr-1');
    expect(repository.createTenantRoleMembershipInputs.single.userId, 'user-2');
    expect(find.byType(Dialog), findsNothing);

    await tester.tap(find.byTooltip('Delete tenant role membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantRoleMembershipInputs, isEmpty);

    await tester.tap(find.byTooltip('Delete tenant role membership').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.deleteTenantRoleMembershipInputs, hasLength(1));
    expect(
      repository.deleteTenantRoleMembershipInputs.single.membershipId,
      'rm-1',
    );
    expect(repository.deleteTenantRoleMembershipInputs.single.rowVersion, 7);
  });

  testWidgets('RbacManagementPanel enforces tenant-required tabs', (
    WidgetTester tester,
  ) async {
    final repository = _FakeRbacAdminRepository()..returnNoTenants = true;
    await _pumpPanel(tester, repository);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('rbac-management-tab-tenant-roles')));
    await tester.pumpAndSettle();
    expect(
      find.text('Select a tenant to manage tenant roles.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-role-memberships')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Select a tenant to manage tenant role memberships.'),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const Key('rbac-management-tab-tenant-grants')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Select a tenant to manage tenant grants.'),
      findsOneWidget,
    );
  });
}

String? _tabTooltipMessage(WidgetTester tester, Key tabKey) {
  final tooltip = tester.widget<Tooltip>(find.byKey(tabKey));
  return tooltip.message;
}

Future<void> _pumpPanel(
  WidgetTester tester,
  _FakeRbacAdminRepository repository, {
  Size surfaceSize = const Size(1800, 1300),
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() async {
    await tester.binding.setSurfaceSize(null);
  });

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        rbacAdminRepositoryProvider.overrideWithValue(repository),
        authControllerProvider.overrideWith(() => _TestAuthController()),
        appNavigatorProvider.overrideWith((ref) => _FakeAppNavigator()),
        snackBarDispatcherProvider.overrideWith((ref) => _RecordingSnackBars()),
      ],
      child: const MaterialApp(home: Scaffold(body: RbacManagementPanel())),
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

class _FakeRbacAdminRepository implements RbacAdminRepository {
  _FakeRbacAdminRepository()
    : _tenants = const <RbacTenantSummaryEntity>[
        RbacTenantSummaryEntity(
          id: 'tenant-1',
          name: 'Tenant One',
          slug: 'tenant-one',
          status: 'Active',
          rowVersion: 1,
        ),
      ],
      _globalRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'gr-1',
          namespace: 'acp',
          name: 'administrator',
          displayName: 'Administrator',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: null,
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantRoles = <RbacRoleEntity>[
        RbacRoleEntity(
          id: 'tr-1',
          namespace: 'acp',
          name: 'member',
          displayName: 'Member',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: 'tenant-1',
          deleted: false,
          seedData: false,
        ),
        RbacRoleEntity(
          id: 'tr-2',
          namespace: 'acp',
          name: 'legacy',
          displayName: 'Legacy',
          status: 'deprecated',
          rowVersion: 2,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          tenantId: 'tenant-1',
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionObjects = <RbacPermissionObjectEntity>[
        RbacPermissionObjectEntity(
          id: 'po-1',
          namespace: 'acp',
          name: 'tenant',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _permissionTypes = <RbacPermissionTypeEntity>[
        RbacPermissionTypeEntity(
          id: 'pt-1',
          namespace: 'acp',
          name: 'manage',
          status: 'active',
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'gpe-1',
          tenantId: null,
          roleId: 'gr-1',
          roleDisplayName: 'Administrator',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalRoleMemberships = <RbacRoleMembershipEntity>[
        RbacRoleMembershipEntity(
          id: 'grm-1',
          tenantId: null,
          roleId: 'gr-1',
          userId: 'user-1',
          roleDisplayName: 'Administrator',
          roleKey: 'acp:administrator',
          roleNamespace: 'acp',
          roleName: 'administrator',
          userDisplayName: 'alice@example.com',
          userEmail: 'alice@example.com',
          rowVersion: 8,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _globalUsers = const <RbacAssignableUserEntity>[
        RbacAssignableUserEntity(
          id: 'user-1',
          username: 'alice-login',
          displayName: 'alice@example.com',
          email: 'alice@example.com',
          deleted: false,
          seedData: false,
        ),
        RbacAssignableUserEntity(
          id: 'user-2',
          username: 'bob-login',
          displayName: 'bob@example.com',
          email: 'bob@example.com',
          deleted: false,
          seedData: false,
        ),
        RbacAssignableUserEntity(
          id: 'user-3',
          username: 'carol-login',
          displayName: 'carol@example.com',
          email: 'carol@example.com',
          deleted: true,
          seedData: false,
        ),
      ],
      _tenantEntries = <RbacPermissionEntryEntity>[
        RbacPermissionEntryEntity(
          id: 'tpe-1',
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          roleDisplayName: 'Member',
          permissionObjectId: 'po-1',
          permissionObjectDisplayName: 'acp:tenant',
          permissionTypeId: 'pt-1',
          permissionTypeDisplayName: 'acp:manage',
          permitted: true,
          rowVersion: 1,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantRoleMemberships = <RbacRoleMembershipEntity>[
        RbacRoleMembershipEntity(
          id: 'rm-1',
          tenantId: 'tenant-1',
          roleId: 'tr-1',
          userId: 'user-1',
          roleDisplayName: 'Member',
          roleKey: 'acp:member',
          roleNamespace: 'acp',
          roleName: 'member',
          userDisplayName: 'alice@example.com',
          userEmail: 'alice@example.com',
          rowVersion: 7,
          dateCreated: DateTime.utc(2024, 1, 1),
          dateLastModified: DateTime.utc(2024, 1, 1),
          deleted: false,
          seedData: false,
        ),
      ],
      _tenantMembers = <RbacTenantMemberEntity>[
        const RbacTenantMemberEntity(
          membershipId: 'tm-1',
          tenantId: 'tenant-1',
          userId: 'user-1',
          username: 'alice-login',
          displayName: 'alice@example.com',
          email: 'alice@example.com',
          status: 'active',
          deleted: false,
        ),
        const RbacTenantMemberEntity(
          membershipId: 'tm-2',
          tenantId: 'tenant-1',
          userId: 'user-2',
          username: 'bob-login',
          displayName: 'bob@example.com',
          email: 'bob@example.com',
          status: 'active',
          deleted: false,
        ),
        const RbacTenantMemberEntity(
          membershipId: 'tm-3',
          tenantId: 'tenant-1',
          userId: 'user-3',
          username: 'carol-login',
          displayName: 'carol@example.com',
          email: 'carol@example.com',
          status: 'suspended',
          deleted: false,
        ),
      ];

  final List<RbacTenantSummaryEntity> _tenants;
  final List<RbacRoleEntity> _globalRoles;
  final List<RbacRoleEntity> _tenantRoles;
  final List<RbacPermissionObjectEntity> _permissionObjects;
  final List<RbacPermissionTypeEntity> _permissionTypes;
  final List<RbacPermissionEntryEntity> _globalEntries;
  final List<RbacRoleMembershipEntity> _globalRoleMemberships;
  final List<RbacAssignableUserEntity> _globalUsers;
  final List<RbacPermissionEntryEntity> _tenantEntries;
  final List<RbacRoleMembershipEntity> _tenantRoleMemberships;
  final List<RbacTenantMemberEntity> _tenantMembers;

  bool returnNoTenants = false;
  bool mutationShouldSucceed = true;

  void replacePermissionCatalogForTest({
    required RbacPermissionObjectEntity permissionObject,
    required RbacPermissionTypeEntity permissionType,
  }) {
    _permissionObjects
      ..clear()
      ..add(permissionObject);
    _permissionTypes
      ..clear()
      ..add(permissionType);
  }

  void addSearchFixturesForTest() {
    _globalRoles.add(
      RbacRoleEntity(
        id: 'gr-2',
        namespace: 'acp',
        name: 'auditor',
        displayName: 'Auditor',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        tenantId: null,
        deleted: false,
        seedData: false,
      ),
    );
    _permissionObjects.add(
      RbacPermissionObjectEntity(
        id: 'po-2',
        namespace: 'acp',
        name: 'user',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
    );
    _permissionTypes.add(
      RbacPermissionTypeEntity(
        id: 'pt-2',
        namespace: 'acp',
        name: 'read',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
    );
    _globalEntries.add(
      RbacPermissionEntryEntity(
        id: 'gpe-2',
        tenantId: null,
        roleId: 'gr-2',
        roleDisplayName: 'Auditor',
        permissionObjectId: 'po-2',
        permissionObjectDisplayName: 'acp:user',
        permissionTypeId: 'pt-2',
        permissionTypeDisplayName: 'acp:read',
        permitted: true,
        rowVersion: 1,
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
    );
    _tenantRoleMemberships.add(
      RbacRoleMembershipEntity(
        id: 'rm-2',
        tenantId: 'tenant-1',
        roleId: 'tr-2',
        userId: 'user-2',
        roleDisplayName: 'Auditor',
        roleKey: 'acp:auditor',
        roleNamespace: 'acp',
        roleName: 'auditor',
        userDisplayName: 'bob@example.com',
        userEmail: 'bob@example.com',
        rowVersion: 1,
        dateCreated: DateTime.utc(2024, 1, 1),
        dateLastModified: DateTime.utc(2024, 1, 1),
        deleted: false,
        seedData: false,
      ),
    );
  }

  final List<RbacCreateGlobalRoleInput> createGlobalRoleInputs =
      <RbacCreateGlobalRoleInput>[];
  final List<RbacUpdateGlobalRoleInput> updateGlobalRoleInputs =
      <RbacUpdateGlobalRoleInput>[];
  final List<RbacTenantRoleLifecycleInput> deprecateTenantRoleInputs =
      <RbacTenantRoleLifecycleInput>[];
  final List<RbacTenantRoleLifecycleInput> reactivateTenantRoleInputs =
      <RbacTenantRoleLifecycleInput>[];
  final List<RbacPermissionObjectLifecycleInput>
  deprecatePermissionObjectInputs = <RbacPermissionObjectLifecycleInput>[];
  final List<RbacPermissionTypeLifecycleInput> deprecatePermissionTypeInputs =
      <RbacPermissionTypeLifecycleInput>[];
  final List<RbacCreateGlobalPermissionEntryInput>
  createGlobalPermissionEntryInputs = <RbacCreateGlobalPermissionEntryInput>[];
  final List<RbacCreateTenantPermissionEntryInput>
  createTenantPermissionEntryInputs = <RbacCreateTenantPermissionEntryInput>[];
  final List<RbacUpdateGlobalPermissionEntryInput>
  updateGlobalPermissionEntryInputs = <RbacUpdateGlobalPermissionEntryInput>[];
  final List<RbacDeleteGlobalPermissionEntryInput>
  deleteGlobalPermissionEntryInputs = <RbacDeleteGlobalPermissionEntryInput>[];
  final List<RbacUpdateTenantPermissionEntryInput>
  updateTenantPermissionEntryInputs = <RbacUpdateTenantPermissionEntryInput>[];
  final List<RbacDeleteTenantPermissionEntryInput>
  deleteTenantPermissionEntryInputs = <RbacDeleteTenantPermissionEntryInput>[];
  final List<RbacCreateGlobalRoleMembershipInput>
  createGlobalRoleMembershipInputs = <RbacCreateGlobalRoleMembershipInput>[];
  final List<RbacDeleteGlobalRoleMembershipInput>
  deleteGlobalRoleMembershipInputs = <RbacDeleteGlobalRoleMembershipInput>[];
  final List<RbacCreateRoleMembershipInput> createTenantRoleMembershipInputs =
      <RbacCreateRoleMembershipInput>[];
  final List<RbacDeleteRoleMembershipInput> deleteTenantRoleMembershipInputs =
      <RbacDeleteRoleMembershipInput>[];

  @override
  Future<Result<void>> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  ) async {
    createGlobalPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createGlobalRole(RbacCreateGlobalRoleInput input) async {
    createGlobalRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createGlobalRoleMembership(
    RbacCreateGlobalRoleMembershipInput input,
  ) async {
    createGlobalRoleMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createPermissionType(
    RbacCreatePermissionTypeInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  ) async {
    createTenantPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantRoleMembership(
    RbacCreateRoleMembershipInput input,
  ) async {
    createTenantRoleMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> createTenantRole(RbacCreateTenantRoleInput input) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  ) async {
    deleteGlobalPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteGlobalRoleMembership(
    RbacDeleteGlobalRoleMembershipInput input,
  ) async {
    deleteGlobalRoleMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  ) async {
    deleteTenantPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deleteTenantRoleMembership(
    RbacDeleteRoleMembershipInput input,
  ) async {
    deleteTenantRoleMembershipInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    deprecatePermissionObjectInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    deprecatePermissionTypeInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> deprecateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    deprecateTenantRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchGlobalPermissionEntries({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionEntryEntity>>.success(_globalEntries);
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchGlobalRoles({int top = 200}) async {
    return Result<List<RbacRoleEntity>>.success(_globalRoles);
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchGlobalRoleMemberships({
    int top = 200,
  }) async {
    return Result<List<RbacRoleMembershipEntity>>.success(
      _globalRoleMemberships,
    );
  }

  @override
  Future<Result<List<RbacAssignableUserEntity>>> fetchGlobalUsers({
    int top = 200,
  }) async {
    return Result<List<RbacAssignableUserEntity>>.success(_globalUsers);
  }

  @override
  Future<Result<List<RbacPermissionObjectEntity>>> fetchPermissionObjects({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionObjectEntity>>.success(_permissionObjects);
  }

  @override
  Future<Result<List<RbacPermissionTypeEntity>>> fetchPermissionTypes({
    int top = 200,
  }) async {
    return Result<List<RbacPermissionTypeEntity>>.success(_permissionTypes);
  }

  @override
  Future<Result<List<RbacTenantSummaryEntity>>> fetchTenants({
    int top = 200,
  }) async {
    if (returnNoTenants) {
      return const Result<List<RbacTenantSummaryEntity>>.success(
        <RbacTenantSummaryEntity>[],
      );
    }

    return Result<List<RbacTenantSummaryEntity>>.success(_tenants);
  }

  @override
  Future<Result<List<RbacPermissionEntryEntity>>> fetchTenantPermissionEntries({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacPermissionEntryEntity>>.success(_tenantEntries);
  }

  @override
  Future<Result<List<RbacRoleMembershipEntity>>> fetchTenantRoleMemberships({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacRoleMembershipEntity>>.success(
      _tenantRoleMemberships,
    );
  }

  @override
  Future<Result<List<RbacTenantMemberEntity>>> fetchTenantMembers({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacTenantMemberEntity>>.success(_tenantMembers);
  }

  @override
  Future<Result<List<RbacRoleEntity>>> fetchTenantRoles({
    required String tenantId,
    int top = 200,
  }) async {
    return Result<List<RbacRoleEntity>>.success(_tenantRoles);
  }

  @override
  Future<Result<void>> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  ) async {
    return _mutationResult();
  }

  @override
  Future<Result<void>> reactivateTenantRole(
    RbacTenantRoleLifecycleInput input,
  ) async {
    reactivateTenantRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  ) async {
    updateGlobalPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateGlobalRole(RbacUpdateGlobalRoleInput input) async {
    updateGlobalRoleInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  ) async {
    updateTenantPermissionEntryInputs.add(input);
    return _mutationResult();
  }

  @override
  Future<Result<void>> updateTenantRole(RbacUpdateTenantRoleInput input) async {
    return _mutationResult();
  }

  Result<void> _mutationResult() {
    if (!mutationShouldSucceed) {
      return const Result<void>.failure(UnexpectedFailure('mutation failed'));
    }

    return const Result<void>.success(null);
  }
}
