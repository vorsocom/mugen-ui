// coverage:ignore-file
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_assignable_user_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/providers/rbac_admin_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _formDialogPanelWidth = 520;

class RbacManagementPanel extends ConsumerStatefulWidget {
  const RbacManagementPanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<RbacManagementPanel> createState() =>
      _RbacManagementPanelState();
}

class _RbacManagementPanelState extends ConsumerState<RbacManagementPanel> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(rbacAdminControllerProvider.notifier).loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(rbacAdminControllerProvider);
    final controller = ref.read(rbacAdminControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminPageHeader(
          title: 'Roles & Permissions',
          subtitle:
              'Manage RBAC roles, permission catalogs, grants, and memberships.',
        ),
        AdminToolbar(
          children: [
            SizedBox(
              width: 360,
              child: AppSearchableSelectField<RbacTenantSummaryEntity>(
                fieldKey: const Key('rbac-management-tenant-selector'),
                optionKeyPrefix: 'rbac-management-tenant-option',
                labelText: 'Tenant',
                hintText: 'Search tenants',
                options: state.tenants,
                selectedOptionKey: state.selectedTenantId,
                optionKey: (tenant) => tenant.id,
                optionTitle: (tenant) => '${tenant.name} (${tenant.slug})',
                optionSubtitle: (tenant) => '${tenant.status}  |  ${tenant.id}',
                optionSearchText: (tenant) =>
                    '${tenant.name} ${tenant.slug} ${tenant.status} ${tenant.id}',
                emptyMessage: 'No matching tenants found.',
                enabled: state.tenants.isNotEmpty,
                onSelected: (tenant) {
                  unawaited(controller.selectTenant(tenant.id));
                },
              ),
            ),
            TextButton.icon(
              key: const Key('rbac-management-refresh-button'),
              onPressed: controller.refresh,
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        if (state.isLoadingGlobal ||
            state.isLoadingTenantScoped ||
            state.isMutating)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        AdminTabs(items: _buildTabItems(state, controller)),
        Expanded(
          child: AdminSurface(
            child: switch (state.activeTab) {
              RbacAdminTab.permissionObjects => _buildPermissionObjectsTab(
                state,
              ),
              RbacAdminTab.permissionTypes => _buildPermissionTypesTab(state),
              RbacAdminTab.globalRoles => _buildGlobalRolesTab(state),
              RbacAdminTab.globalGrants => _buildGlobalGrantsTab(state),
              RbacAdminTab.globalRoleMemberships =>
                _buildGlobalRoleMembershipsTab(state),
              RbacAdminTab.tenantRoles => _buildTenantRolesTab(state),
              RbacAdminTab.tenantGrants => _buildTenantGrantsTab(state),
              RbacAdminTab.tenantRoleMemberships =>
                _buildTenantRoleMembershipsTab(state),
            },
          ),
        ),
      ],
    );
  }

  List<AdminTabItem> _buildTabItems(
    RbacAdminState state,
    RbacAdminController controller,
  ) {
    return [
      AdminTabItem(
        key: const Key('rbac-management-tab-permission-objects'),
        label: 'Permission Objects',
        count: state.permissionObjects.length,
        selected: state.activeTab == RbacAdminTab.permissionObjects,
        onSelected: () =>
            controller.setActiveTab(RbacAdminTab.permissionObjects),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-permission-types'),
        label: 'Permission Types',
        count: state.permissionTypes.length,
        selected: state.activeTab == RbacAdminTab.permissionTypes,
        onSelected: () => controller.setActiveTab(RbacAdminTab.permissionTypes),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-global-roles'),
        label: 'Global Roles',
        count: state.globalRoles.length,
        selected: state.activeTab == RbacAdminTab.globalRoles,
        onSelected: () => controller.setActiveTab(RbacAdminTab.globalRoles),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-global-grants'),
        label: 'Global Grants',
        count: state.globalPermissionEntries.length,
        selected: state.activeTab == RbacAdminTab.globalGrants,
        onSelected: () => controller.setActiveTab(RbacAdminTab.globalGrants),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-global-role-memberships'),
        label: 'Global Role Memberships',
        count: state.globalRoleMemberships.length,
        selected: state.activeTab == RbacAdminTab.globalRoleMemberships,
        onSelected: () =>
            controller.setActiveTab(RbacAdminTab.globalRoleMemberships),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-tenant-roles'),
        label: 'Tenant Roles',
        count: state.tenantRoles.length,
        selected: state.activeTab == RbacAdminTab.tenantRoles,
        onSelected: () => controller.setActiveTab(RbacAdminTab.tenantRoles),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-tenant-grants'),
        label: 'Tenant Grants',
        count: state.tenantPermissionEntries.length,
        selected: state.activeTab == RbacAdminTab.tenantGrants,
        onSelected: () => controller.setActiveTab(RbacAdminTab.tenantGrants),
      ),
      AdminTabItem(
        key: const Key('rbac-management-tab-role-memberships'),
        label: 'Tenant Role Memberships',
        count: state.tenantRoleMemberships.length,
        selected: state.activeTab == RbacAdminTab.tenantRoleMemberships,
        onSelected: () =>
            controller.setActiveTab(RbacAdminTab.tenantRoleMemberships),
      ),
    ];
  }

  Widget _buildGlobalRolesTab(RbacAdminState state) {
    return _RbacGridSection<RbacRoleEntity>(
      key: const ValueKey<String>('rbac-global-roles-section'),
      createButtonKey: const Key('rbac-global-role-create-button'),
      createLabel: 'New Global Role',
      searchFieldKey: const Key('rbac-global-roles-search-field'),
      searchHint: 'Search global roles',
      onCreate: _showCreateGlobalRoleDialog,
      emptyTitle: 'No global roles yet.',
      emptyMessage:
          'Create a global role to grant platform-wide permissions outside tenant scope.',
      rows: state.globalRoles,
      rowKey: (role) => role.id,
      searchText: _roleSearchText,
      columns: [
        AdminGridColumn<RbacRoleEntity>(
          key: 'role',
          label: 'Role',
          flex: 2,
          cell: (_, role) => AdminCellText(role.displayName),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'namespace',
          label: 'Namespace',
          cell: (_, role) => AdminCellText(role.namespace),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'name',
          label: 'Name',
          cell: (_, role) => AdminCellText(role.name),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'status',
          label: 'Status',
          width: 128,
          cell: (_, role) => AdminStatusChip(label: role.status),
        ),
      ],
      actions: [
        AdminGridAction<RbacRoleEntity>(
          icon: Icons.edit_outlined,
          tooltip: 'Edit global role',
          onPressed: (role) =>
              () => _showEditGlobalRoleDialog(role),
        ),
      ],
    );
  }

  Widget _buildPermissionObjectsTab(RbacAdminState state) {
    return _RbacGridSection<RbacPermissionObjectEntity>(
      key: const ValueKey<String>('rbac-permission-objects-section'),
      createButtonKey: const Key('rbac-permission-object-create-button'),
      createLabel: 'New Permission Object',
      searchFieldKey: const Key('rbac-permission-objects-search-field'),
      searchHint: 'Search permission objects',
      onCreate: _showCreatePermissionObjectDialog,
      emptyTitle: 'No permission objects yet.',
      emptyMessage:
          'Create a permission object before attaching actions to roles or grants.',
      rows: state.permissionObjects,
      rowKey: (permissionObject) => permissionObject.id,
      searchText: _permissionObjectSearchText,
      columns: [
        AdminGridColumn<RbacPermissionObjectEntity>(
          key: 'namespace',
          label: 'Namespace',
          flex: 2,
          cell: (_, permissionObject) =>
              AdminCellText(permissionObject.namespace),
        ),
        AdminGridColumn<RbacPermissionObjectEntity>(
          key: 'object',
          label: 'Object',
          flex: 2,
          cell: (_, permissionObject) => AdminCellText(permissionObject.name),
        ),
        AdminGridColumn<RbacPermissionObjectEntity>(
          key: 'status',
          label: 'Status',
          width: 128,
          cell: (_, permissionObject) =>
              AdminStatusChip(label: permissionObject.status),
        ),
      ],
      actionsBuilder: (_, permissionObject) {
        final isDeprecated = _isDeprecatedStatus(permissionObject.status);
        return _RbacInlineActions(
          children: [
            AdminIconButton(
              icon: isDeprecated
                  ? Icons.restore_outlined
                  : Icons.archive_outlined,
              tooltip: isDeprecated
                  ? 'Reactivate permission object'
                  : 'Deprecate permission object',
              onPressed: () => _runPermissionObjectLifecycle(
                permissionObject,
                deprecate: !isDeprecated,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionTypesTab(RbacAdminState state) {
    return _RbacGridSection<RbacPermissionTypeEntity>(
      key: const ValueKey<String>('rbac-permission-types-section'),
      createButtonKey: const Key('rbac-permission-type-create-button'),
      createLabel: 'New Permission Type',
      searchFieldKey: const Key('rbac-permission-types-search-field'),
      searchHint: 'Search permission types',
      onCreate: _showCreatePermissionTypeDialog,
      emptyTitle: 'No permission types yet.',
      emptyMessage:
          'Create a permission type to define the actions that can be granted.',
      rows: state.permissionTypes,
      rowKey: (permissionType) => permissionType.id,
      searchText: _permissionTypeSearchText,
      columns: [
        AdminGridColumn<RbacPermissionTypeEntity>(
          key: 'namespace',
          label: 'Namespace',
          flex: 2,
          cell: (_, permissionType) => AdminCellText(permissionType.namespace),
        ),
        AdminGridColumn<RbacPermissionTypeEntity>(
          key: 'action',
          label: 'Action',
          flex: 2,
          cell: (_, permissionType) => AdminCellText(permissionType.name),
        ),
        AdminGridColumn<RbacPermissionTypeEntity>(
          key: 'status',
          label: 'Status',
          width: 128,
          cell: (_, permissionType) =>
              AdminStatusChip(label: permissionType.status),
        ),
      ],
      actionsBuilder: (_, permissionType) {
        final isDeprecated = _isDeprecatedStatus(permissionType.status);
        return _RbacInlineActions(
          children: [
            AdminIconButton(
              icon: isDeprecated
                  ? Icons.restore_outlined
                  : Icons.archive_outlined,
              tooltip: isDeprecated
                  ? 'Reactivate permission type'
                  : 'Deprecate permission type',
              onPressed: () => _runPermissionTypeLifecycle(
                permissionType,
                deprecate: !isDeprecated,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildGlobalGrantsTab(RbacAdminState state) {
    return _RbacGridSection<RbacPermissionEntryEntity>(
      key: const ValueKey<String>('rbac-global-grants-section'),
      createButtonKey: const Key('rbac-global-grant-create-button'),
      createLabel: 'New Global Grant',
      searchFieldKey: const Key('rbac-global-grants-search-field'),
      searchHint: 'Search global grants',
      onCreate: _showCreateGlobalGrantDialog,
      emptyTitle: 'No global grants yet.',
      emptyMessage:
          'Create a global grant to allow or deny an action for a platform role.',
      rows: state.globalPermissionEntries,
      rowKey: (entry) => entry.id,
      searchText: _permissionEntrySearchText,
      columns: _permissionEntryColumns(),
      actionsWidth: 112,
      actionsBuilder: (_, entry) => _RbacInlineActions(
        children: [
          AdminIconButton(
            icon: entry.permitted
                ? Icons.toggle_on_outlined
                : Icons.toggle_off_outlined,
            tooltip: entry.permitted ? 'Set denied' : 'Set permitted',
            onPressed: () => _toggleGlobalGrant(entry),
          ),
          AdminIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete global grant',
            destructive: true,
            onPressed: () => _deleteGlobalGrant(entry),
          ),
        ],
      ),
    );
  }

  Widget _buildTenantRolesTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const AdminEmptyState(
        data: AdminEmptyStateData(
          title: 'Tenant required.',
          message: 'Select a tenant to manage tenant roles.',
        ),
      );
    }

    return _RbacGridSection<RbacRoleEntity>(
      key: const ValueKey<String>('rbac-tenant-roles-section'),
      createButtonKey: const Key('rbac-tenant-role-create-button'),
      createLabel: 'New Tenant Role',
      searchFieldKey: const Key('rbac-tenant-roles-search-field'),
      searchHint: 'Search tenant roles',
      onCreate: () => _showCreateTenantRoleDialog(tenantId),
      emptyTitle: 'No tenant roles yet.',
      emptyMessage:
          'Create a tenant role before assigning tenant-scoped grants or memberships.',
      rows: state.tenantRoles,
      rowKey: (role) => role.id,
      searchText: _roleSearchText,
      columns: [
        AdminGridColumn<RbacRoleEntity>(
          key: 'role',
          label: 'Role',
          flex: 2,
          cell: (_, role) => AdminCellText(role.displayName),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'namespace',
          label: 'Namespace',
          cell: (_, role) => AdminCellText(role.namespace),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'name',
          label: 'Name',
          cell: (_, role) => AdminCellText(role.name),
        ),
        AdminGridColumn<RbacRoleEntity>(
          key: 'status',
          label: 'Status',
          width: 128,
          cell: (_, role) => AdminStatusChip(label: role.status),
        ),
      ],
      actionsWidth: 112,
      actionsBuilder: (_, role) {
        final isDeprecated = _isDeprecatedStatus(role.status);
        return _RbacInlineActions(
          children: [
            AdminIconButton(
              icon: Icons.edit_outlined,
              tooltip: 'Edit tenant role',
              onPressed: () =>
                  _showEditTenantRoleDialog(tenantId: tenantId, role: role),
            ),
            AdminIconButton(
              icon: isDeprecated
                  ? Icons.restore_outlined
                  : Icons.archive_outlined,
              tooltip: isDeprecated
                  ? 'Reactivate tenant role'
                  : 'Deprecate tenant role',
              onPressed: () => _runTenantRoleLifecycle(
                tenantId: tenantId,
                role: role,
                deprecate: !isDeprecated,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTenantGrantsTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const AdminEmptyState(
        data: AdminEmptyStateData(
          title: 'Tenant required.',
          message: 'Select a tenant to manage tenant grants.',
        ),
      );
    }

    return _RbacGridSection<RbacPermissionEntryEntity>(
      key: const ValueKey<String>('rbac-tenant-grants-section'),
      createButtonKey: const Key('rbac-tenant-grant-create-button'),
      createLabel: 'New Tenant Grant',
      searchFieldKey: const Key('rbac-tenant-grants-search-field'),
      searchHint: 'Search tenant grants',
      onCreate: () => _showCreateTenantGrantDialog(tenantId),
      emptyTitle: 'No tenant grants yet.',
      emptyMessage:
          'Create a tenant grant to allow or deny a permission for a tenant role.',
      rows: state.tenantPermissionEntries,
      rowKey: (entry) => entry.id,
      searchText: _permissionEntrySearchText,
      columns: _permissionEntryColumns(),
      actionsWidth: 112,
      actionsBuilder: (_, entry) => _RbacInlineActions(
        children: [
          AdminIconButton(
            icon: entry.permitted
                ? Icons.toggle_on_outlined
                : Icons.toggle_off_outlined,
            tooltip: entry.permitted ? 'Set denied' : 'Set permitted',
            onPressed: () =>
                _toggleTenantGrant(tenantId: tenantId, entry: entry),
          ),
          AdminIconButton(
            icon: Icons.delete_outline,
            tooltip: 'Delete tenant grant',
            destructive: true,
            onPressed: () =>
                _deleteTenantGrant(tenantId: tenantId, entry: entry),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalRoleMembershipsTab(RbacAdminState state) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RbacSectionNote(
          message:
              'Users may need to sign out and back in for route and session claims to refresh.',
        ),
        Expanded(
          child: _RbacGridSection<RbacRoleMembershipEntity>(
            key: const ValueKey<String>('rbac-global-role-memberships-section'),
            createButtonKey: const Key(
              'rbac-global-role-membership-create-button',
            ),
            createLabel: 'New Global Role Membership',
            searchFieldKey: const Key(
              'rbac-global-role-memberships-search-field',
            ),
            searchHint: 'Search global role memberships',
            onCreate: _showCreateGlobalRoleMembershipDialog,
            emptyTitle: 'No global role memberships yet.',
            emptyMessage:
                'Assign a user to a global role to grant platform-wide access.',
            rows: state.globalRoleMemberships,
            rowKey: (membership) => membership.id,
            searchText: _roleMembershipSearchText,
            columns: _roleMembershipColumns(),
            actions: [
              AdminGridAction<RbacRoleMembershipEntity>(
                icon: Icons.delete_outline,
                tooltip: 'Delete global role membership',
                style: AdminGridActionStyle.destructive,
                onPressed: (membership) =>
                    () => _deleteGlobalRoleMembership(membership: membership),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTenantRoleMembershipsTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const AdminEmptyState(
        data: AdminEmptyStateData(
          title: 'Tenant required.',
          message: 'Select a tenant to manage tenant role memberships.',
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _RbacSectionNote(
          message:
              'Users may need to sign out and back in for route and session claims to refresh.',
        ),
        Expanded(
          child: _RbacGridSection<RbacRoleMembershipEntity>(
            key: const ValueKey<String>('rbac-role-memberships-section'),
            createButtonKey: const Key('rbac-role-membership-create-button'),
            createLabel: 'New Tenant Role Membership',
            searchFieldKey: const Key('rbac-role-memberships-search-field'),
            searchHint: 'Search tenant role memberships',
            onCreate: () => _showCreateTenantRoleMembershipDialog(tenantId),
            emptyTitle: 'No tenant role memberships yet.',
            emptyMessage:
                'Assign a tenant member to a role to grant tenant-scoped access.',
            rows: state.tenantRoleMemberships,
            rowKey: (membership) => membership.id,
            searchText: _roleMembershipSearchText,
            columns: _roleMembershipColumns(),
            actions: [
              AdminGridAction<RbacRoleMembershipEntity>(
                icon: Icons.delete_outline,
                tooltip: 'Delete tenant role membership',
                style: AdminGridActionStyle.destructive,
                onPressed: (membership) =>
                    () => _deleteTenantRoleMembership(
                      tenantId: tenantId,
                      membership: membership,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateGlobalRoleDialog() async {
    final namespaceController = TextEditingController(text: acpNamespace);
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Create Global Role'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: namespaceController,
                    decoration: appFormInputDecoration(
                      labelText: 'Namespace',
                      helpText: acpFieldHelpText(
                        key: 'Namespace',
                        label: 'Namespace',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Name',
                      helpText: acpFieldHelpText(key: 'Name', label: 'Name'),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
                      helpText: acpFieldHelpText(
                        key: 'DisplayName',
                        label: 'Display Name',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Create Global Role',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .createGlobalRole(
                            RbacCreateGlobalRoleInput(
                              namespace: namespaceController.text.trim(),
                              name: nameController.text.trim(),
                              displayName: displayNameController.text.trim(),
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Global role created.',
                        failureMessage: 'Global role create failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditGlobalRoleDialog(RbacRoleEntity role) async {
    final displayNameController = TextEditingController(text: role.displayName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Edit Global Role'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
                      helpText: acpFieldHelpText(
                        key: 'DisplayName',
                        label: 'Display Name',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Save Changes',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .updateGlobalRole(
                            RbacUpdateGlobalRoleInput(
                              roleId: role.id,
                              displayName: displayNameController.text.trim(),
                              rowVersion: role.rowVersion,
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Global role updated.',
                        failureMessage: 'Global role update failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateTenantRoleDialog(String tenantId) async {
    final namespaceController = TextEditingController(text: acpNamespace);
    final nameController = TextEditingController();
    final displayNameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Create Tenant Role'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: namespaceController,
                    decoration: appFormInputDecoration(
                      labelText: 'Namespace',
                      helpText: acpFieldHelpText(
                        key: 'Namespace',
                        label: 'Namespace',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Name',
                      helpText: acpFieldHelpText(key: 'Name', label: 'Name'),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
                      helpText: acpFieldHelpText(
                        key: 'DisplayName',
                        label: 'Display Name',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Create Tenant Role',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .createTenantRole(
                            RbacCreateTenantRoleInput(
                              tenantId: tenantId,
                              namespace: namespaceController.text.trim(),
                              name: nameController.text.trim(),
                              displayName: displayNameController.text.trim(),
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Tenant role created.',
                        failureMessage: 'Tenant role create failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditTenantRoleDialog({
    required String tenantId,
    required RbacRoleEntity role,
  }) async {
    final displayNameController = TextEditingController(text: role.displayName);
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Edit Tenant Role'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
                      helpText: acpFieldHelpText(
                        key: 'DisplayName',
                        label: 'Display Name',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Save Changes',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .updateTenantRole(
                            RbacUpdateTenantRoleInput(
                              tenantId: tenantId,
                              roleId: role.id,
                              displayName: displayNameController.text.trim(),
                              rowVersion: role.rowVersion,
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Tenant role updated.',
                        failureMessage: 'Tenant role update failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreatePermissionObjectDialog() async {
    await _showPermissionTaxonomyCreateDialog(isPermissionType: false);
  }

  Future<void> _showCreatePermissionTypeDialog() async {
    await _showPermissionTaxonomyCreateDialog(isPermissionType: true);
  }

  Future<void> _showPermissionTaxonomyCreateDialog({
    required bool isPermissionType,
  }) async {
    final namespaceController = TextEditingController(text: acpNamespace);
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final title = isPermissionType
        ? 'Create Permission Type'
        : 'Create Permission Object';
    final submit = isPermissionType
        ? 'Create Permission Type'
        : 'Create Permission Object';

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle(title),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: namespaceController,
                    decoration: appFormInputDecoration(
                      labelText: 'Namespace',
                      helpText: acpFieldHelpText(
                        key: 'Namespace',
                        label: 'Namespace',
                      ),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Name',
                      helpText: acpFieldHelpText(key: 'Name', label: 'Name'),
                    ),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: submit,
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final notifier = ref.read(
                        rbacAdminControllerProvider.notifier,
                      );
                      final success = isPermissionType
                          ? await notifier.createPermissionType(
                              RbacCreatePermissionTypeInput(
                                namespace: namespaceController.text.trim(),
                                name: nameController.text.trim(),
                              ),
                            )
                          : await notifier.createPermissionObject(
                              RbacCreatePermissionObjectInput(
                                namespace: namespaceController.text.trim(),
                                name: nameController.text.trim(),
                              ),
                            );

                      _showMutationResult(
                        successMessage: isPermissionType
                            ? 'Permission type created.'
                            : 'Permission object created.',
                        failureMessage: isPermissionType
                            ? 'Permission type create failed.'
                            : 'Permission object create failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateGlobalGrantDialog() async {
    final state = ref.read(rbacAdminControllerProvider);
    if (state.globalRoles.isEmpty ||
        state.permissionObjects.isEmpty ||
        state.permissionTypes.isEmpty) {
      _showMutationResult(
        successMessage: '',
        failureMessage:
            'Global roles, permission objects, and permission types are required.',
        success: false,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    RbacRoleEntity? selectedRole;
    RbacPermissionObjectEntity? selectedPermissionObject;
    RbacPermissionTypeEntity? selectedPermissionType;
    var permitted = true;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            child: SizedBox(
              width: _formDialogPanelWidth,
              child: AppFormPanel(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTitle('Create Global Grant'),
                      const SizedBox(height: 12),
                      _buildGrantRoleSearchField(
                        searchFieldKey: const Key(
                          'rbac-global-grant-role-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-global-grant-selected-role',
                        ),
                        optionKeyPrefix: 'rbac-global-grant-role-option',
                        options: state.globalRoles,
                        onSelected: (role) {
                          selectedRole = role;
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionObjectSearchField(
                        searchFieldKey: const Key(
                          'rbac-global-grant-permission-object-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-global-grant-selected-permission-object',
                        ),
                        optionKeyPrefix:
                            'rbac-global-grant-permission-object-option',
                        options: state.permissionObjects,
                        onSelected: (permissionObject) {
                          selectedPermissionObject = permissionObject;
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionTypeSearchField(
                        searchFieldKey: const Key(
                          'rbac-global-grant-permission-type-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-global-grant-selected-permission-type',
                        ),
                        optionKeyPrefix:
                            'rbac-global-grant-permission-type-option',
                        options: state.permissionTypes,
                        onSelected: (permissionType) {
                          selectedPermissionType = permissionType;
                        },
                      ),
                      SwitchListTile(
                        value: permitted,
                        title: appFieldLabelWithHelp(
                          labelText: 'Permitted',
                          helpText: acpFieldHelpText(
                            key: 'Permitted',
                            label: 'Permitted',
                            kind: AcpFieldKind.boolean,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setDialogState(() {
                            permitted = value;
                          });
                        },
                      ),
                      _DialogActions(
                        submitLabel: 'Create Global Grant',
                        onSubmit: () async {
                          final isValid =
                              formKey.currentState?.validate() ?? false;
                          final role = selectedRole;
                          final permissionObject = selectedPermissionObject;
                          final permissionType = selectedPermissionType;
                          if (!isValid ||
                              role == null ||
                              permissionObject == null ||
                              permissionType == null) {
                            return;
                          }

                          final success = await ref
                              .read(rbacAdminControllerProvider.notifier)
                              .createGlobalPermissionEntry(
                                RbacCreateGlobalPermissionEntryInput(
                                  globalRoleId: role.id,
                                  permissionObjectId: permissionObject.id,
                                  permissionTypeId: permissionType.id,
                                  permitted: permitted,
                                ),
                              );
                          _showMutationResult(
                            successMessage: 'Global grant created.',
                            failureMessage: 'Global grant create failed.',
                            success: success,
                          );

                          if (success && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateTenantGrantDialog(String tenantId) async {
    final state = ref.read(rbacAdminControllerProvider);
    if (state.tenantRoles.isEmpty ||
        state.permissionObjects.isEmpty ||
        state.permissionTypes.isEmpty) {
      _showMutationResult(
        successMessage: '',
        failureMessage:
            'Tenant roles, permission objects, and permission types are required.',
        success: false,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    RbacRoleEntity? selectedRole;
    RbacPermissionObjectEntity? selectedPermissionObject;
    RbacPermissionTypeEntity? selectedPermissionType;
    var permitted = true;

    await showDialog<void>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          return Dialog(
            child: SizedBox(
              width: _formDialogPanelWidth,
              child: AppFormPanel(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildDialogTitle('Create Tenant Grant'),
                      const SizedBox(height: 12),
                      _buildGrantRoleSearchField(
                        searchFieldKey: const Key(
                          'rbac-tenant-grant-role-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-tenant-grant-selected-role',
                        ),
                        optionKeyPrefix: 'rbac-tenant-grant-role-option',
                        options: state.tenantRoles,
                        onSelected: (role) {
                          selectedRole = role;
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionObjectSearchField(
                        searchFieldKey: const Key(
                          'rbac-tenant-grant-permission-object-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-tenant-grant-selected-permission-object',
                        ),
                        optionKeyPrefix:
                            'rbac-tenant-grant-permission-object-option',
                        options: state.permissionObjects,
                        onSelected: (permissionObject) {
                          selectedPermissionObject = permissionObject;
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildPermissionTypeSearchField(
                        searchFieldKey: const Key(
                          'rbac-tenant-grant-permission-type-search-field',
                        ),
                        selectedKey: const Key(
                          'rbac-tenant-grant-selected-permission-type',
                        ),
                        optionKeyPrefix:
                            'rbac-tenant-grant-permission-type-option',
                        options: state.permissionTypes,
                        onSelected: (permissionType) {
                          selectedPermissionType = permissionType;
                        },
                      ),
                      SwitchListTile(
                        value: permitted,
                        title: appFieldLabelWithHelp(
                          labelText: 'Permitted',
                          helpText: acpFieldHelpText(
                            key: 'Permitted',
                            label: 'Permitted',
                            kind: AcpFieldKind.boolean,
                          ),
                        ),
                        contentPadding: EdgeInsets.zero,
                        onChanged: (value) {
                          setDialogState(() {
                            permitted = value;
                          });
                        },
                      ),
                      _DialogActions(
                        submitLabel: 'Create Tenant Grant',
                        onSubmit: () async {
                          final isValid =
                              formKey.currentState?.validate() ?? false;
                          final role = selectedRole;
                          final permissionObject = selectedPermissionObject;
                          final permissionType = selectedPermissionType;
                          if (!isValid ||
                              role == null ||
                              permissionObject == null ||
                              permissionType == null) {
                            return;
                          }

                          final success = await ref
                              .read(rbacAdminControllerProvider.notifier)
                              .createTenantPermissionEntry(
                                RbacCreateTenantPermissionEntryInput(
                                  tenantId: tenantId,
                                  roleId: role.id,
                                  permissionObjectId: permissionObject.id,
                                  permissionTypeId: permissionType.id,
                                  permitted: permitted,
                                ),
                              );
                          _showMutationResult(
                            successMessage: 'Tenant grant created.',
                            failureMessage: 'Tenant grant create failed.',
                            success: success,
                          );

                          if (success && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCreateGlobalRoleMembershipDialog() async {
    final state = ref.read(rbacAdminControllerProvider);
    final activeRoles = state.globalRoles
        .where((role) => !role.deleted && _isAssignableStatus(role.status))
        .toList(growable: false);
    final activeUsers = state.globalUsers
        .where((user) => !user.deleted)
        .toList(growable: false);
    if (activeRoles.isEmpty || activeUsers.isEmpty) {
      _showMutationResult(
        successMessage: '',
        failureMessage: 'Active global roles and users are required.',
        success: false,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    RbacRoleEntity? selectedRole;
    RbacAssignableUserEntity? selectedUser;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Create Global Role Membership'),
                  const SizedBox(height: 12),
                  _RbacEntitySearchField<RbacAssignableUserEntity>(
                    searchFieldKey: const Key(
                      'rbac-global-role-membership-user-search-field',
                    ),
                    selectedKey: const Key(
                      'rbac-global-role-membership-selected-user',
                    ),
                    optionKeyPrefix: 'rbac-global-role-membership-user-option',
                    labelText: 'User',
                    hintText: 'Search by name or email',
                    helpText: acpFieldHelpText(key: 'UserId', label: 'User'),
                    suffixIcon: Icons.person_search_outlined,
                    options: activeUsers,
                    optionKey: (user) => user.id,
                    optionTitle: (user) => user.displayName,
                    optionSubtitle: _globalUserSearchSubtitle,
                    optionSearchText: _globalUserSearchText,
                    selectedLabel: _globalUserOptionLabel,
                    emptyMessage: 'No matching users found.',
                    validator: (user) {
                      if (user == null) {
                        return 'Select a user.';
                      }

                      return null;
                    },
                    onSelected: (user) {
                      selectedUser = user;
                    },
                  ),
                  const SizedBox(height: 8),
                  _RbacEntitySearchField<RbacRoleEntity>(
                    searchFieldKey: const Key(
                      'rbac-global-role-membership-role-search-field',
                    ),
                    selectedKey: const Key(
                      'rbac-global-role-membership-selected-role',
                    ),
                    optionKeyPrefix: 'rbac-global-role-membership-role-option',
                    labelText: 'Global Role',
                    hintText: 'Search by role name or key',
                    helpText: acpFieldHelpText(
                      key: 'GlobalRoleId',
                      label: 'Global Role',
                    ),
                    suffixIcon: Icons.manage_search_outlined,
                    options: activeRoles,
                    optionKey: (role) => role.id,
                    optionTitle: (role) => role.displayName,
                    optionSubtitle: _roleSearchSubtitle,
                    optionSearchText: _roleSearchText,
                    selectedLabel: _roleSelectedLabel,
                    emptyMessage: 'No matching global roles found.',
                    validator: (role) {
                      if (role == null) {
                        return 'Select a global role.';
                      }
                      if (_hasRoleMembershipDuplicate(
                        state.globalRoleMemberships,
                        roleId: role.id,
                        userId: selectedUser?.id,
                      )) {
                        return 'This user already has this role.';
                      }

                      return null;
                    },
                    onSelected: (role) {
                      selectedRole = role;
                    },
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Create Global Role Membership',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid ||
                          selectedRole == null ||
                          selectedUser == null) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .createGlobalRoleMembership(
                            RbacCreateGlobalRoleMembershipInput(
                              roleId: selectedRole!.id,
                              userId: selectedUser!.id,
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Global role membership created.',
                        failureMessage: 'Global role membership create failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showCreateTenantRoleMembershipDialog(String tenantId) async {
    final state = ref.read(rbacAdminControllerProvider);
    final activeRoles = state.tenantRoles
        .where((role) => !role.deleted && _isAssignableStatus(role.status))
        .toList(growable: false);
    final activeMembers = state.tenantMembers
        .where(
          (member) => !member.deleted && _isAssignableStatus(member.status),
        )
        .toList(growable: false);
    if (activeRoles.isEmpty || activeMembers.isEmpty) {
      _showMutationResult(
        successMessage: '',
        failureMessage:
            'Active tenant roles and active tenant members are required.',
        success: false,
      );
      return;
    }

    final formKey = GlobalKey<FormState>();
    RbacRoleEntity? selectedRole;
    RbacTenantMemberEntity? selectedMember;

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildDialogTitle('Create Tenant Role Membership'),
                  const SizedBox(height: 12),
                  _RbacEntitySearchField<RbacTenantMemberEntity>(
                    searchFieldKey: const Key(
                      'rbac-role-membership-user-search-field',
                    ),
                    selectedKey: const Key(
                      'rbac-role-membership-selected-user',
                    ),
                    optionKeyPrefix: 'rbac-role-membership-user-option',
                    labelText: 'User',
                    hintText: 'Search by name or email',
                    helpText: acpFieldHelpText(key: 'UserId', label: 'User'),
                    suffixIcon: Icons.person_search_outlined,
                    options: activeMembers,
                    optionKey: (member) => member.userId,
                    optionTitle: (member) => member.displayName,
                    optionSubtitle: _tenantMemberSearchSubtitle,
                    optionSearchText: _tenantMemberSearchText,
                    selectedLabel: _tenantMemberOptionLabel,
                    emptyMessage: 'No matching users found.',
                    validator: (member) {
                      if (member == null) {
                        return 'Select a user.';
                      }

                      return null;
                    },
                    onSelected: (member) {
                      selectedMember = member;
                    },
                  ),
                  const SizedBox(height: 8),
                  _RbacEntitySearchField<RbacRoleEntity>(
                    searchFieldKey: const Key(
                      'rbac-role-membership-role-search-field',
                    ),
                    selectedKey: const Key(
                      'rbac-role-membership-selected-role',
                    ),
                    optionKeyPrefix: 'rbac-role-membership-role-option',
                    labelText: 'Role',
                    hintText: 'Search by role name or key',
                    helpText: acpFieldHelpText(key: 'RoleId', label: 'Role'),
                    suffixIcon: Icons.manage_search_outlined,
                    options: activeRoles,
                    optionKey: (role) => role.id,
                    optionTitle: (role) => role.displayName,
                    optionSubtitle: _roleSearchSubtitle,
                    optionSearchText: _roleSearchText,
                    selectedLabel: _roleSelectedLabel,
                    emptyMessage: 'No matching roles found.',
                    validator: (role) {
                      if (role == null) {
                        return 'Select a role.';
                      }
                      if (_hasRoleMembershipDuplicate(
                        state.tenantRoleMemberships,
                        roleId: role.id,
                        userId: selectedMember?.userId,
                      )) {
                        return 'This user already has this role.';
                      }

                      return null;
                    },
                    onSelected: (role) {
                      selectedRole = role;
                    },
                  ),
                  const SizedBox(height: 14),
                  _DialogActions(
                    submitLabel: 'Create Tenant Role Membership',
                    onSubmit: () async {
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid ||
                          selectedRole == null ||
                          selectedMember == null) {
                        return;
                      }

                      final success = await ref
                          .read(rbacAdminControllerProvider.notifier)
                          .createTenantRoleMembership(
                            RbacCreateRoleMembershipInput(
                              tenantId: tenantId,
                              roleId: selectedRole!.id,
                              userId: selectedMember!.userId,
                            ),
                          );
                      _showMutationResult(
                        successMessage: 'Tenant role membership created.',
                        failureMessage: 'Tenant role membership create failed.',
                        success: success,
                      );

                      if (success && mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _runTenantRoleLifecycle({
    required String tenantId,
    required RbacRoleEntity role,
    required bool deprecate,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: deprecate
          ? 'Deprecate this tenant role?'
          : 'Reactivate this tenant role?',
      confirmLabel: 'Continue',
    );
    if (confirmed != true) {
      return;
    }

    final success = deprecate
        ? await ref
              .read(rbacAdminControllerProvider.notifier)
              .deprecateTenantRole(
                RbacTenantRoleLifecycleInput(
                  tenantId: tenantId,
                  roleId: role.id,
                  rowVersion: role.rowVersion,
                ),
              )
        : await ref
              .read(rbacAdminControllerProvider.notifier)
              .reactivateTenantRole(
                RbacTenantRoleLifecycleInput(
                  tenantId: tenantId,
                  roleId: role.id,
                  rowVersion: role.rowVersion,
                ),
              );

    _showMutationResult(
      successMessage: deprecate
          ? 'Tenant role deprecated.'
          : 'Tenant role reactivated.',
      failureMessage: deprecate
          ? 'Tenant role deprecate failed.'
          : 'Tenant role reactivate failed.',
      success: success,
    );
  }

  Future<void> _runPermissionObjectLifecycle(
    RbacPermissionObjectEntity permissionObject, {
    required bool deprecate,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: deprecate
          ? 'Deprecate this permission object?'
          : 'Reactivate this permission object?',
      confirmLabel: 'Continue',
    );
    if (confirmed != true) {
      return;
    }

    final success = deprecate
        ? await ref
              .read(rbacAdminControllerProvider.notifier)
              .deprecatePermissionObject(
                RbacPermissionObjectLifecycleInput(
                  permissionObjectId: permissionObject.id,
                  rowVersion: permissionObject.rowVersion,
                ),
              )
        : await ref
              .read(rbacAdminControllerProvider.notifier)
              .reactivatePermissionObject(
                RbacPermissionObjectLifecycleInput(
                  permissionObjectId: permissionObject.id,
                  rowVersion: permissionObject.rowVersion,
                ),
              );

    _showMutationResult(
      successMessage: deprecate
          ? 'Permission object deprecated.'
          : 'Permission object reactivated.',
      failureMessage: deprecate
          ? 'Permission object deprecate failed.'
          : 'Permission object reactivate failed.',
      success: success,
    );
  }

  Future<void> _runPermissionTypeLifecycle(
    RbacPermissionTypeEntity permissionType, {
    required bool deprecate,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: deprecate
          ? 'Deprecate this permission type?'
          : 'Reactivate this permission type?',
      confirmLabel: 'Continue',
    );
    if (confirmed != true) {
      return;
    }

    final success = deprecate
        ? await ref
              .read(rbacAdminControllerProvider.notifier)
              .deprecatePermissionType(
                RbacPermissionTypeLifecycleInput(
                  permissionTypeId: permissionType.id,
                  rowVersion: permissionType.rowVersion,
                ),
              )
        : await ref
              .read(rbacAdminControllerProvider.notifier)
              .reactivatePermissionType(
                RbacPermissionTypeLifecycleInput(
                  permissionTypeId: permissionType.id,
                  rowVersion: permissionType.rowVersion,
                ),
              );

    _showMutationResult(
      successMessage: deprecate
          ? 'Permission type deprecated.'
          : 'Permission type reactivated.',
      failureMessage: deprecate
          ? 'Permission type deprecate failed.'
          : 'Permission type reactivate failed.',
      success: success,
    );
  }

  Future<void> _toggleGlobalGrant(RbacPermissionEntryEntity entry) async {
    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .updateGlobalPermissionEntry(
          RbacUpdateGlobalPermissionEntryInput(
            entryId: entry.id,
            rowVersion: entry.rowVersion,
            permitted: !entry.permitted,
          ),
        );

    _showMutationResult(
      successMessage: 'Global grant updated.',
      failureMessage: 'Global grant update failed.',
      success: success,
    );
  }

  Future<void> _deleteGlobalGrant(RbacPermissionEntryEntity entry) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: 'Delete this global grant?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .deleteGlobalPermissionEntry(
          RbacDeleteGlobalPermissionEntryInput(
            entryId: entry.id,
            rowVersion: entry.rowVersion,
          ),
        );

    _showMutationResult(
      successMessage: 'Global grant deleted.',
      failureMessage: 'Global grant delete failed.',
      success: success,
    );
  }

  Future<void> _toggleTenantGrant({
    required String tenantId,
    required RbacPermissionEntryEntity entry,
  }) async {
    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .updateTenantPermissionEntry(
          RbacUpdateTenantPermissionEntryInput(
            tenantId: tenantId,
            entryId: entry.id,
            rowVersion: entry.rowVersion,
            permitted: !entry.permitted,
          ),
        );

    _showMutationResult(
      successMessage: 'Tenant grant updated.',
      failureMessage: 'Tenant grant update failed.',
      success: success,
    );
  }

  Future<void> _deleteTenantGrant({
    required String tenantId,
    required RbacPermissionEntryEntity entry,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: 'Delete this tenant grant?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .deleteTenantPermissionEntry(
          RbacDeleteTenantPermissionEntryInput(
            tenantId: tenantId,
            entryId: entry.id,
            rowVersion: entry.rowVersion,
          ),
        );

    _showMutationResult(
      successMessage: 'Tenant grant deleted.',
      failureMessage: 'Tenant grant delete failed.',
      success: success,
    );
  }

  Future<void> _deleteGlobalRoleMembership({
    required RbacRoleMembershipEntity membership,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: 'Delete this global role membership?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .deleteGlobalRoleMembership(
          RbacDeleteGlobalRoleMembershipInput(
            membershipId: membership.id,
            rowVersion: membership.rowVersion,
          ),
        );

    _showMutationResult(
      successMessage: 'Global role membership deleted.',
      failureMessage: 'Global role membership delete failed.',
      success: success,
    );
  }

  Future<void> _deleteTenantRoleMembership({
    required String tenantId,
    required RbacRoleMembershipEntity membership,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: 'Delete this tenant role membership?',
      confirmLabel: 'Delete',
    );
    if (confirmed != true) {
      return;
    }

    final success = await ref
        .read(rbacAdminControllerProvider.notifier)
        .deleteTenantRoleMembership(
          RbacDeleteRoleMembershipInput(
            tenantId: tenantId,
            membershipId: membership.id,
            rowVersion: membership.rowVersion,
          ),
        );

    _showMutationResult(
      successMessage: 'Tenant role membership deleted.',
      failureMessage: 'Tenant role membership delete failed.',
      success: success,
    );
  }

  void _showMutationResult({
    required bool success,
    required String successMessage,
    required String failureMessage,
  }) {
    final navigator = ref.read(appNavigatorProvider);
    final snackBars = ref.read(snackBarDispatcherProvider);
    snackBars.show(navigator, success ? successMessage : failureMessage);
  }

  Widget _buildDialogTitle(String title) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildGrantRoleSearchField({
    required Key searchFieldKey,
    required Key selectedKey,
    required String optionKeyPrefix,
    required List<RbacRoleEntity> options,
    required ValueChanged<RbacRoleEntity?> onSelected,
  }) {
    return _RbacEntitySearchField<RbacRoleEntity>(
      searchFieldKey: searchFieldKey,
      selectedKey: selectedKey,
      optionKeyPrefix: optionKeyPrefix,
      labelText: 'Role',
      hintText: 'Search by role name or key',
      helpText: acpFieldHelpText(key: 'Role', label: 'Role'),
      suffixIcon: Icons.manage_search_outlined,
      options: options,
      optionKey: (role) => role.id,
      optionTitle: (role) => role.displayName,
      optionSubtitle: _roleSearchSubtitle,
      optionSearchText: _roleSearchText,
      selectedLabel: _roleSelectedLabel,
      emptyMessage: 'No matching roles found.',
      validator: (role) => role == null ? 'Select a role.' : null,
      onSelected: onSelected,
    );
  }

  Widget _buildPermissionObjectSearchField({
    required Key searchFieldKey,
    required Key selectedKey,
    required String optionKeyPrefix,
    required List<RbacPermissionObjectEntity> options,
    required ValueChanged<RbacPermissionObjectEntity?> onSelected,
  }) {
    return _RbacEntitySearchField<RbacPermissionObjectEntity>(
      searchFieldKey: searchFieldKey,
      selectedKey: selectedKey,
      optionKeyPrefix: optionKeyPrefix,
      labelText: 'Permission Object',
      hintText: 'Search by permission object',
      helpText: acpFieldHelpText(
        key: 'PermissionObject',
        label: 'Permission Object',
      ),
      suffixIcon: Icons.category_outlined,
      options: options,
      optionKey: (permissionObject) => permissionObject.id,
      optionTitle: (permissionObject) => permissionObject.key,
      optionSubtitle: _permissionObjectSearchSubtitle,
      optionSearchText: _permissionObjectSearchText,
      selectedLabel: (permissionObject) => permissionObject.key,
      emptyMessage: 'No matching permission objects found.',
      validator: (permissionObject) =>
          permissionObject == null ? 'Select a permission object.' : null,
      onSelected: onSelected,
    );
  }

  Widget _buildPermissionTypeSearchField({
    required Key searchFieldKey,
    required Key selectedKey,
    required String optionKeyPrefix,
    required List<RbacPermissionTypeEntity> options,
    required ValueChanged<RbacPermissionTypeEntity?> onSelected,
  }) {
    return _RbacEntitySearchField<RbacPermissionTypeEntity>(
      searchFieldKey: searchFieldKey,
      selectedKey: selectedKey,
      optionKeyPrefix: optionKeyPrefix,
      labelText: 'Permission Type',
      hintText: 'Search by permission type',
      helpText: acpFieldHelpText(
        key: 'PermissionType',
        label: 'Permission Type',
      ),
      suffixIcon: Icons.rule_outlined,
      options: options,
      optionKey: (permissionType) => permissionType.id,
      optionTitle: (permissionType) => permissionType.key,
      optionSubtitle: _permissionTypeSearchSubtitle,
      optionSearchText: _permissionTypeSearchText,
      selectedLabel: (permissionType) => permissionType.key,
      emptyMessage: 'No matching permission types found.',
      validator: (permissionType) =>
          permissionType == null ? 'Select a permission type.' : null,
      onSelected: onSelected,
    );
  }

  List<AdminGridColumn<RbacPermissionEntryEntity>> _permissionEntryColumns() {
    return [
      AdminGridColumn<RbacPermissionEntryEntity>(
        key: 'role',
        label: 'Role',
        flex: 2,
        cell: (_, entry) => AdminCellText(entry.roleDisplayName),
      ),
      AdminGridColumn<RbacPermissionEntryEntity>(
        key: 'namespace',
        label: 'Namespace',
        flex: 2,
        cell: (_, entry) => AdminCellText(_permissionEntryNamespace(entry)),
      ),
      AdminGridColumn<RbacPermissionEntryEntity>(
        key: 'object',
        label: 'Object',
        flex: 2,
        cell: (_, entry) => AdminCellText(
          _splitPermissionKey(entry.permissionObjectDisplayName).name,
        ),
      ),
      AdminGridColumn<RbacPermissionEntryEntity>(
        key: 'action',
        label: 'Action',
        flex: 2,
        cell: (_, entry) => AdminCellText(
          _splitPermissionKey(entry.permissionTypeDisplayName).name,
        ),
      ),
      AdminGridColumn<RbacPermissionEntryEntity>(
        key: 'decision',
        label: 'Decision',
        width: 128,
        cell: (_, entry) =>
            AdminStatusChip(label: entry.permitted ? 'permitted' : 'denied'),
      ),
    ];
  }

  List<AdminGridColumn<RbacRoleMembershipEntity>> _roleMembershipColumns() {
    return [
      AdminGridColumn<RbacRoleMembershipEntity>(
        key: 'user',
        label: 'User',
        flex: 2,
        cell: (_, membership) => AdminCellText(membership.userDisplayName),
      ),
      AdminGridColumn<RbacRoleMembershipEntity>(
        key: 'email',
        label: 'Email',
        flex: 2,
        cell: (_, membership) => AdminCellText(membership.userEmail),
      ),
      AdminGridColumn<RbacRoleMembershipEntity>(
        key: 'role',
        label: 'Role',
        flex: 2,
        cell: (_, membership) => AdminCellText(membership.roleDisplayName),
      ),
      AdminGridColumn<RbacRoleMembershipEntity>(
        key: 'namespace',
        label: 'Namespace',
        cell: (_, membership) {
          final roleKeyParts = _splitPermissionKey(membership.roleKey);
          return AdminCellText(
            roleKeyParts.namespace.isEmpty
                ? membership.roleNamespace
                : roleKeyParts.namespace,
          );
        },
      ),
      AdminGridColumn<RbacRoleMembershipEntity>(
        key: 'roleName',
        label: 'Role name',
        cell: (_, membership) {
          final roleKeyParts = _splitPermissionKey(membership.roleKey);
          return AdminCellText(
            roleKeyParts.name.isEmpty ? membership.roleName : roleKeyParts.name,
          );
        },
      ),
    ];
  }

  String _permissionEntryNamespace(RbacPermissionEntryEntity entry) {
    final objectParts = _splitPermissionKey(entry.permissionObjectDisplayName);
    if (objectParts.namespace.isNotEmpty) {
      return objectParts.namespace;
    }

    return _splitPermissionKey(entry.permissionTypeDisplayName).namespace;
  }

  _RbacKeyParts _splitPermissionKey(String value) {
    final trimmed = value.trim();
    final separator = trimmed.indexOf(':');
    if (separator <= 0 || separator == trimmed.length - 1) {
      return _RbacKeyParts(namespace: '', name: trimmed);
    }

    return _RbacKeyParts(
      namespace: trimmed.substring(0, separator),
      name: trimmed.substring(separator + 1),
    );
  }

  String? _requiredValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Field cannot be empty.';
    }

    return null;
  }

  bool _isDeprecatedStatus(String status) {
    return status.toLowerCase().contains('deprecated');
  }

  bool _isAssignableStatus(String status) {
    final normalized = status.toLowerCase();
    return !normalized.contains('deprecated') &&
        !normalized.contains('removed') &&
        !normalized.contains('suspended');
  }

  String _permissionEntrySearchText(RbacPermissionEntryEntity entry) {
    return _joinSearchText([
      entry.roleDisplayName,
      entry.permissionObjectDisplayName,
      entry.permissionTypeDisplayName,
      entry.permitted ? 'permitted' : 'denied',
    ]);
  }

  String _roleMembershipSearchText(RbacRoleMembershipEntity membership) {
    return _joinSearchText([
      membership.userDisplayName,
      membership.userEmail,
      membership.roleDisplayName,
      membership.roleKey,
      membership.roleNamespace,
      membership.roleName,
    ]);
  }

  bool _hasRoleMembershipDuplicate(
    List<RbacRoleMembershipEntity> memberships, {
    required String? roleId,
    required String? userId,
  }) {
    if (roleId == null || userId == null) {
      return false;
    }

    return memberships.any(
      (membership) =>
          membership.roleId == roleId &&
          membership.userId == userId &&
          !membership.deleted,
    );
  }

  String _globalUserOptionLabel(RbacAssignableUserEntity user) {
    if (user.email.isEmpty || user.email == user.displayName) {
      return user.displayName;
    }

    return '${user.displayName} (${user.email})';
  }

  String _globalUserSearchText(RbacAssignableUserEntity user) {
    return _joinSearchText([
      user.displayName,
      user.username,
      user.email,
      user.id,
    ]);
  }

  String _globalUserSearchSubtitle(RbacAssignableUserEntity user) {
    final details = <String>[
      user.username,
      user.email,
      user.id,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    if (details.isEmpty) {
      return user.id;
    }

    return details.join('  |  ');
  }

  String _tenantMemberOptionLabel(RbacTenantMemberEntity member) {
    if (member.email.isEmpty || member.email == member.displayName) {
      return member.displayName;
    }

    return '${member.displayName} (${member.email})';
  }

  String _tenantMemberSearchText(RbacTenantMemberEntity member) {
    return _joinSearchText([
      member.displayName,
      member.username,
      member.email,
      member.userId,
    ]);
  }

  String _tenantMemberSearchSubtitle(RbacTenantMemberEntity member) {
    final details = <String>[
      member.username,
      member.email,
      member.userId,
    ].where((value) => value.trim().isNotEmpty).toList(growable: false);
    if (details.isEmpty) {
      return member.userId;
    }

    return details.join('  |  ');
  }

  String _roleSelectedLabel(RbacRoleEntity role) {
    return '${role.displayName}  |  ${role.key}';
  }

  String _roleSearchText(RbacRoleEntity role) {
    return _joinSearchText([
      role.displayName,
      role.key,
      role.namespace,
      role.name,
      role.id,
    ]);
  }

  String _roleSearchSubtitle(RbacRoleEntity role) {
    return '${role.key}  |  ${role.id}';
  }

  String _permissionObjectSearchText(
    RbacPermissionObjectEntity permissionObject,
  ) {
    return _joinSearchText([
      permissionObject.key,
      permissionObject.namespace,
      permissionObject.name,
      permissionObject.id,
    ]);
  }

  String _permissionObjectSearchSubtitle(
    RbacPermissionObjectEntity permissionObject,
  ) {
    return '${permissionObject.status}  |  ${permissionObject.id}';
  }

  String _permissionTypeSearchText(RbacPermissionTypeEntity permissionType) {
    return _joinSearchText([
      permissionType.key,
      permissionType.namespace,
      permissionType.name,
      permissionType.id,
    ]);
  }

  String _permissionTypeSearchSubtitle(
    RbacPermissionTypeEntity permissionType,
  ) {
    return '${permissionType.status}  |  ${permissionType.id}';
  }

  String _joinSearchText(List<String> values) {
    return values.map((value) => value.trim()).join(' ');
  }
}

class _RbacEntitySearchField<T> extends StatefulWidget {
  const _RbacEntitySearchField({
    required this.searchFieldKey,
    required this.selectedKey,
    required this.optionKeyPrefix,
    required this.labelText,
    required this.hintText,
    required this.helpText,
    required this.suffixIcon,
    required this.options,
    required this.optionKey,
    required this.optionTitle,
    required this.optionSubtitle,
    required this.optionSearchText,
    required this.selectedLabel,
    required this.emptyMessage,
    required this.onSelected,
    this.validator,
  });

  final Key searchFieldKey;
  final Key selectedKey;
  final String optionKeyPrefix;
  final String labelText;
  final String hintText;
  final String? helpText;
  final IconData suffixIcon;
  final List<T> options;
  final String Function(T option) optionKey;
  final String Function(T option) optionTitle;
  final String Function(T option) optionSubtitle;
  final String Function(T option) optionSearchText;
  final String Function(T option) selectedLabel;
  final String emptyMessage;
  final ValueChanged<T?> onSelected;
  final FormFieldValidator<T>? validator;

  @override
  State<_RbacEntitySearchField<T>> createState() =>
      _RbacEntitySearchFieldState<T>();
}

class _RbacEntitySearchFieldState<T> extends State<_RbacEntitySearchField<T>> {
  final TextEditingController _searchController = TextEditingController();

  T? _selected;
  bool _hasSearched = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<T>(
      validator: widget.validator,
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: widget.searchFieldKey,
              controller: _searchController,
              decoration: appFormInputDecoration(
                labelText: widget.labelText,
                hintText: widget.hintText,
                suffixIcon: Icon(widget.suffixIcon),
                helpText: widget.helpText,
              ),
              onChanged: (value) {
                setState(() {
                  _hasSearched = value.trim().isNotEmpty;
                });
              },
            ),
            if (fieldState.errorText != null) ...[
              const SizedBox(height: 6),
              AppErrorAlert(message: fieldState.errorText!),
            ],
            if (_selected != null) ...[
              const SizedBox(height: 8),
              _RbacSelectedEntityTile(
                selectedKey: widget.selectedKey,
                label: widget.selectedLabel(_selected as T),
                onClear: () => _clearSelection(fieldState),
              ),
            ],
            if (_hasSearched) ...[
              const SizedBox(height: 8),
              _buildResults(fieldState),
            ],
          ],
        );
      },
    );
  }

  Widget _buildResults(FormFieldState<T> fieldState) {
    final results = _filteredOptions();
    if (results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(widget.emptyMessage),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final option = results[index];
            final isSelected = identical(_selected, option);
            return ListTile(
              key: Key('${widget.optionKeyPrefix}-${widget.optionKey(option)}'),
              selected: isSelected,
              leading: Icon(
                isSelected
                    ? Icons.check_circle_outline
                    : Icons.manage_search_outlined,
              ),
              title: Text(widget.optionTitle(option)),
              subtitle: Text(widget.optionSubtitle(option)),
              onTap: () => _selectOption(option, fieldState),
            );
          },
        ),
      ),
    );
  }

  List<T> _filteredOptions() {
    final normalized = _searchController.text.trim().toLowerCase();
    if (normalized.isEmpty) {
      return <T>[];
    }

    return widget.options
        .where(
          (option) => widget
              .optionSearchText(option)
              .toLowerCase()
              .contains(normalized),
        )
        .toList(growable: false);
  }

  void _selectOption(T option, FormFieldState<T> fieldState) {
    setState(() {
      _selected = option;
      _searchController.text = widget.optionTitle(option);
      _hasSearched = false;
    });
    fieldState.didChange(option);
    fieldState.validate();
    widget.onSelected(option);
  }

  void _clearSelection(FormFieldState<T> fieldState) {
    setState(() {
      _selected = null;
      _searchController.clear();
      _hasSearched = false;
    });
    fieldState.didChange(null);
    fieldState.validate();
    widget.onSelected(null);
  }
}

class _RbacSelectedEntityTile extends StatelessWidget {
  const _RbacSelectedEntityTile({
    required this.selectedKey,
    required this.label,
    required this.onClear,
  });

  final Key selectedKey;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: selectedKey,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppUiPalette.surfaceStrong,
        border: Border.all(color: AppUiPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(label, overflow: TextOverflow.ellipsis)),
          IconButton(
            tooltip: 'Clear selection',
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 18),
          ),
        ],
      ),
    );
  }
}

class _RbacKeyParts {
  const _RbacKeyParts({required this.namespace, required this.name});

  final String namespace;
  final String name;
}

class _RbacSectionNote extends StatelessWidget {
  const _RbacSectionNote({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: AppUiPalette.textSecondary,
          height: 1.3,
        ),
      ),
    );
  }
}

class _RbacInlineActions extends StatelessWidget {
  const _RbacInlineActions({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.end,
      children: children,
    );
  }
}

class _RbacGridSection<T> extends StatefulWidget {
  const _RbacGridSection({
    required this.createButtonKey,
    required this.createLabel,
    required this.searchFieldKey,
    required this.searchHint,
    required this.onCreate,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.rows,
    required this.rowKey,
    required this.searchText,
    required this.columns,
    this.actions = const [],
    this.actionsBuilder,
    this.actionsWidth,
    this.minWidth = 960,
    super.key,
  });

  final Key createButtonKey;
  final String createLabel;
  final Key searchFieldKey;
  final String searchHint;
  final VoidCallback onCreate;
  final String emptyTitle;
  final String emptyMessage;
  final List<T> rows;
  final String Function(T row) rowKey;
  final String Function(T row) searchText;
  final List<AdminGridColumn<T>> columns;
  final List<AdminGridAction<T>> actions;
  final Widget Function(BuildContext context, T row)? actionsBuilder;
  final double? actionsWidth;
  final double minWidth;

  @override
  State<_RbacGridSection<T>> createState() => _RbacGridSectionState<T>();
}

class _RbacGridSectionState<T> extends State<_RbacGridSection<T>> {
  static const List<int> _pageSizes = <int>[15, 25, 50];

  final TextEditingController _searchController = TextEditingController();
  int _page = 1;
  int _pageSize = _pageSizes.first;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<T> _filteredRows() {
    final tokens = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return widget.rows;
    }

    return widget.rows
        .where((row) {
          final searchText = widget.searchText(row).toLowerCase();
          return tokens.every(searchText.contains);
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final filteredRows = _filteredRows();
    final hasSearchTerm = _searchController.text.trim().isNotEmpty;
    final pageCount = math.max((filteredRows.length / _pageSize).ceil(), 1);
    final effectivePage = math.min(_page, pageCount);
    final pageStart = math.min(
      (effectivePage - 1) * _pageSize,
      filteredRows.length,
    );
    final pageEnd = math.min(pageStart + _pageSize, filteredRows.length);
    final visibleRows = filteredRows.sublist(pageStart, pageEnd);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminToolbar(
          children: [
            FilledButton.icon(
              key: widget.createButtonKey,
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(widget.createLabel),
            ),
            SizedBox(
              width: 320,
              child: TextField(
                key: widget.searchFieldKey,
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: widget.searchHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasSearchTerm
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _page = 1;
                            });
                          },
                        )
                      : null,
                ),
                onChanged: (_) {
                  setState(() {
                    _page = 1;
                  });
                },
              ),
            ),
          ],
        ),
        Expanded(
          child: AdminDataGrid<T>(
            rows: visibleRows,
            columns: widget.columns,
            actions: widget.actions,
            actionsBuilder: widget.actionsBuilder,
            actionsWidth: widget.actionsWidth,
            rowKey: widget.rowKey,
            hasActiveFilter: hasSearchTerm,
            emptyState: AdminEmptyStateData(
              title: widget.emptyTitle,
              message: widget.emptyMessage,
              primaryAction: FilledButton.icon(
                onPressed: widget.onCreate,
                icon: const Icon(Icons.add),
                label: Text(widget.createLabel),
              ),
            ),
            filteredEmptyState: const AdminEmptyStateData(
              title: 'No matching records.',
              message: 'Clear the search or adjust filters.',
            ),
            minWidth: widget.minWidth,
            footer: AdminGridFooter(
              state: AdminPaginationState(
                visibleCount: visibleRows.length,
                totalCount: filteredRows.length,
                page: effectivePage,
                pages: pageCount,
                pageSize: _pageSize,
                pageSizes: _pageSizes,
                onPageSizeChanged: (value) {
                  setState(() {
                    _pageSize = value;
                    _page = 1;
                  });
                },
                onFirstPage: effectivePage <= 1
                    ? null
                    : () {
                        setState(() {
                          _page = 1;
                        });
                      },
                onPreviousPage: effectivePage <= 1
                    ? null
                    : () {
                        setState(() {
                          _page = effectivePage - 1;
                        });
                      },
                onNextPage: effectivePage >= pageCount
                    ? null
                    : () {
                        setState(() {
                          _page = effectivePage + 1;
                        });
                      },
                onLastPage: effectivePage >= pageCount
                    ? null
                    : () {
                        setState(() {
                          _page = pageCount;
                        });
                      },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.submitLabel, required this.onSubmit});

  final String submitLabel;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: onSubmit, child: Text(submitLabel)),
        ],
      ),
    );
  }
}
