// coverage:ignore-file
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
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
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _formDialogPanelWidth = 520;

class _RbacTabChip extends StatelessWidget {
  const _RbacTabChip({
    required this.chipKey,
    required this.label,
    required this.tooltip,
    required this.tooltipKey,
    required this.selected,
    required this.onSelected,
  });

  final Key chipKey;
  final String label;
  final String tooltip;
  final Key tooltipKey;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.centerRight,
      children: [
        ChoiceChip(
          key: chipKey,
          label: Padding(
            padding: const EdgeInsets.only(right: 24),
            child: Text(label),
          ),
          selected: selected,
          onSelected: onSelected,
        ),
        Positioned(
          right: 6,
          top: 0,
          bottom: 0,
          child: Center(
            child: Tooltip(
              key: tooltipKey,
              message: tooltip,
              child: const SizedBox.square(
                dimension: 18,
                child: Center(
                  child: Icon(
                    Icons.info_outline,
                    size: 16,
                    color: AppUiPalette.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

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
        Row(
          children: [
            TextButton.icon(
              key: const Key('rbac-management-refresh-button'),
              onPressed: () => controller.refresh(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
            const SizedBox(width: 12),
            Expanded(
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
          ],
        ),
        if (state.isLoadingGlobal ||
            state.isLoadingTenantScoped ||
            state.isMutating)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: LinearProgressIndicator(),
          ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-global-roles'),
              label: 'Global Roles',
              tooltip:
                  'Platform-wide roles that can be granted outside a tenant.',
              tooltipKey: const Key('rbac-management-tab-global-roles-info'),
              selected: state.activeTab == RbacAdminTab.globalRoles,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.globalRoles),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-permission-objects'),
              label: 'Permission Objects',
              tooltip:
                  'Protected object types that permissions can be granted on.',
              tooltipKey: const Key(
                'rbac-management-tab-permission-objects-info',
              ),
              selected: state.activeTab == RbacAdminTab.permissionObjects,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.permissionObjects),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-permission-types'),
              label: 'Permission Types',
              tooltip:
                  'Actions that can be allowed or denied for permission objects.',
              tooltipKey: const Key(
                'rbac-management-tab-permission-types-info',
              ),
              selected: state.activeTab == RbacAdminTab.permissionTypes,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.permissionTypes),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-global-grants'),
              label: 'Global Grants',
              tooltip:
                  'Global role permissions that apply without tenant scope.',
              tooltipKey: const Key('rbac-management-tab-global-grants-info'),
              selected: state.activeTab == RbacAdminTab.globalGrants,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.globalGrants),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-tenant-roles'),
              label: 'Tenant Roles',
              tooltip: 'Roles available only within the selected tenant.',
              tooltipKey: const Key('rbac-management-tab-tenant-roles-info'),
              selected: state.activeTab == RbacAdminTab.tenantRoles,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.tenantRoles),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-role-memberships'),
              label: 'Role Memberships',
              tooltip: 'Users assigned to tenant roles in the selected tenant.',
              tooltipKey: const Key(
                'rbac-management-tab-role-memberships-info',
              ),
              selected: state.activeTab == RbacAdminTab.roleMemberships,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.roleMemberships),
            ),
            _RbacTabChip(
              chipKey: const Key('rbac-management-tab-tenant-grants'),
              label: 'Tenant Grants',
              tooltip:
                  'Permissions assigned to tenant roles in the selected tenant.',
              tooltipKey: const Key('rbac-management-tab-tenant-grants-info'),
              selected: state.activeTab == RbacAdminTab.tenantGrants,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.tenantGrants),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: AppFormPanel(
            margin: EdgeInsets.zero,
            child: switch (state.activeTab) {
              RbacAdminTab.globalRoles => _buildGlobalRolesTab(state),
              RbacAdminTab.permissionObjects => _buildPermissionObjectsTab(
                state,
              ),
              RbacAdminTab.permissionTypes => _buildPermissionTypesTab(state),
              RbacAdminTab.globalGrants => _buildGlobalGrantsTab(state),
              RbacAdminTab.tenantRoles => _buildTenantRolesTab(state),
              RbacAdminTab.roleMemberships => _buildRoleMembershipsTab(state),
              RbacAdminTab.tenantGrants => _buildTenantGrantsTab(state),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalRolesTab(RbacAdminState state) {
    return _RbacListSection(
      key: const ValueKey<String>('rbac-global-roles-section'),
      createButtonKey: const Key('rbac-global-role-create-button'),
      createLabel: 'New Global Role',
      searchFieldKey: const Key('rbac-global-roles-search-field'),
      searchHint: 'Search global roles',
      onCreate: _showCreateGlobalRoleDialog,
      emptyMessage: 'No global roles found.',
      items: state.globalRoles
          .map(
            (role) => _RbacSearchItem(
              searchText: _joinSearchText([
                role.displayName,
                role.key,
                role.namespace,
                role.name,
                role.status,
              ]),
              child: ListTile(
                title: Text(role.displayName),
                subtitle: Text('${role.key}  |  ${role.status}'),
                trailing: _ActionIcon(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit global role',
                  onPressed: () => _showEditGlobalRoleDialog(role),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPermissionObjectsTab(RbacAdminState state) {
    return _RbacListSection(
      key: const ValueKey<String>('rbac-permission-objects-section'),
      createButtonKey: const Key('rbac-permission-object-create-button'),
      createLabel: 'New Permission Object',
      searchFieldKey: const Key('rbac-permission-objects-search-field'),
      searchHint: 'Search permission objects',
      onCreate: _showCreatePermissionObjectDialog,
      emptyMessage: 'No permission objects found.',
      items: state.permissionObjects
          .map(
            (permissionObject) => _RbacSearchItem(
              searchText: _joinSearchText([
                permissionObject.key,
                permissionObject.namespace,
                permissionObject.name,
                permissionObject.status,
              ]),
              child: ListTile(
                title: Text(permissionObject.key),
                subtitle: Text(permissionObject.status),
                trailing: _ActionIcon(
                  icon: _isDeprecatedStatus(permissionObject.status)
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  tooltip: _isDeprecatedStatus(permissionObject.status)
                      ? 'Reactivate permission object'
                      : 'Deprecate permission object',
                  onPressed: () => _runPermissionObjectLifecycle(
                    permissionObject,
                    deprecate: !_isDeprecatedStatus(permissionObject.status),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPermissionTypesTab(RbacAdminState state) {
    return _RbacListSection(
      key: const ValueKey<String>('rbac-permission-types-section'),
      createButtonKey: const Key('rbac-permission-type-create-button'),
      createLabel: 'New Permission Type',
      searchFieldKey: const Key('rbac-permission-types-search-field'),
      searchHint: 'Search permission types',
      onCreate: _showCreatePermissionTypeDialog,
      emptyMessage: 'No permission types found.',
      items: state.permissionTypes
          .map(
            (permissionType) => _RbacSearchItem(
              searchText: _joinSearchText([
                permissionType.key,
                permissionType.namespace,
                permissionType.name,
                permissionType.status,
              ]),
              child: ListTile(
                title: Text(permissionType.key),
                subtitle: Text(permissionType.status),
                trailing: _ActionIcon(
                  icon: _isDeprecatedStatus(permissionType.status)
                      ? Icons.play_circle_outline
                      : Icons.pause_circle_outline,
                  tooltip: _isDeprecatedStatus(permissionType.status)
                      ? 'Reactivate permission type'
                      : 'Deprecate permission type',
                  onPressed: () => _runPermissionTypeLifecycle(
                    permissionType,
                    deprecate: !_isDeprecatedStatus(permissionType.status),
                  ),
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildGlobalGrantsTab(RbacAdminState state) {
    return _RbacListSection(
      key: const ValueKey<String>('rbac-global-grants-section'),
      createButtonKey: const Key('rbac-global-grant-create-button'),
      createLabel: 'New Global Grant',
      searchFieldKey: const Key('rbac-global-grants-search-field'),
      searchHint: 'Search global grants',
      onCreate: _showCreateGlobalGrantDialog,
      emptyMessage: 'No global grants found.',
      items: state.globalPermissionEntries
          .map(
            (entry) => _RbacSearchItem(
              searchText: _permissionEntrySearchText(entry),
              child: ListTile(
                title: Text(entry.roleDisplayName),
                subtitle: Text(
                  '${entry.permissionObjectDisplayName}  |  ${entry.permissionTypeDisplayName}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    _ActionIcon(
                      icon: entry.permitted
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      tooltip: entry.permitted ? 'Set denied' : 'Set permitted',
                      onPressed: () => _toggleGlobalGrant(entry),
                    ),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete global grant',
                      onPressed: () => _deleteGlobalGrant(entry),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildTenantRolesTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const Center(
        child: Text('Select a tenant to manage tenant roles.'),
      );
    }

    return _RbacListSection(
      key: const ValueKey<String>('rbac-tenant-roles-section'),
      createButtonKey: const Key('rbac-tenant-role-create-button'),
      createLabel: 'New Tenant Role',
      searchFieldKey: const Key('rbac-tenant-roles-search-field'),
      searchHint: 'Search tenant roles',
      onCreate: () => _showCreateTenantRoleDialog(tenantId),
      emptyMessage: 'No tenant roles found.',
      items: state.tenantRoles
          .map(
            (role) => _RbacSearchItem(
              searchText: _joinSearchText([
                role.displayName,
                role.key,
                role.namespace,
                role.name,
                role.status,
              ]),
              child: ListTile(
                title: Text(role.displayName),
                subtitle: Text('${role.key}  |  ${role.status}'),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    _ActionIcon(
                      icon: Icons.edit_outlined,
                      tooltip: 'Edit tenant role',
                      onPressed: () => _showEditTenantRoleDialog(
                        tenantId: tenantId,
                        role: role,
                      ),
                    ),
                    _ActionIcon(
                      icon: _isDeprecatedStatus(role.status)
                          ? Icons.play_circle_outline
                          : Icons.pause_circle_outline,
                      tooltip: _isDeprecatedStatus(role.status)
                          ? 'Reactivate tenant role'
                          : 'Deprecate tenant role',
                      onPressed: () => _runTenantRoleLifecycle(
                        tenantId: tenantId,
                        role: role,
                        deprecate: !_isDeprecatedStatus(role.status),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildTenantGrantsTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const Center(
        child: Text('Select a tenant to manage tenant grants.'),
      );
    }

    return _RbacListSection(
      key: const ValueKey<String>('rbac-tenant-grants-section'),
      createButtonKey: const Key('rbac-tenant-grant-create-button'),
      createLabel: 'New Tenant Grant',
      searchFieldKey: const Key('rbac-tenant-grants-search-field'),
      searchHint: 'Search tenant grants',
      onCreate: () => _showCreateTenantGrantDialog(tenantId),
      emptyMessage: 'No tenant grants found.',
      items: state.tenantPermissionEntries
          .map(
            (entry) => _RbacSearchItem(
              searchText: _permissionEntrySearchText(entry),
              child: ListTile(
                title: Text(entry.roleDisplayName),
                subtitle: Text(
                  '${entry.permissionObjectDisplayName}  |  ${entry.permissionTypeDisplayName}',
                ),
                trailing: Wrap(
                  spacing: 4,
                  children: [
                    _ActionIcon(
                      icon: entry.permitted
                          ? Icons.toggle_on_outlined
                          : Icons.toggle_off_outlined,
                      tooltip: entry.permitted ? 'Set denied' : 'Set permitted',
                      onPressed: () =>
                          _toggleTenantGrant(tenantId: tenantId, entry: entry),
                    ),
                    _ActionIcon(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete tenant grant',
                      onPressed: () =>
                          _deleteTenantGrant(tenantId: tenantId, entry: entry),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildRoleMembershipsTab(RbacAdminState state) {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return const Center(
        child: Text('Select a tenant to manage role memberships.'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text(
            'Users may need to sign out and back in for route and session claims to refresh.',
            style: TextStyle(color: AppUiPalette.textSecondary),
          ),
        ),
        Expanded(
          child: _RbacListSection(
            key: const ValueKey<String>('rbac-role-memberships-section'),
            createButtonKey: const Key('rbac-role-membership-create-button'),
            createLabel: 'New Role Membership',
            searchFieldKey: const Key('rbac-role-memberships-search-field'),
            searchHint: 'Search role memberships',
            onCreate: () => _showCreateRoleMembershipDialog(tenantId),
            emptyMessage: 'No role memberships found.',
            items: state.tenantRoleMemberships
                .map(
                  (membership) => _RbacSearchItem(
                    searchText: _roleMembershipSearchText(membership),
                    child: ListTile(
                      title: Text(membership.userDisplayName),
                      subtitle: Text(
                        '${membership.roleDisplayName}  |  ${membership.roleKey}',
                      ),
                      trailing: _ActionIcon(
                        icon: Icons.delete_outline,
                        tooltip: 'Delete role membership',
                        onPressed: () => _deleteRoleMembership(
                          tenantId: tenantId,
                          membership: membership,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(growable: false),
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

  Future<void> _showCreateRoleMembershipDialog(String tenantId) async {
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
                  _buildDialogTitle('Create Role Membership'),
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
                        state,
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
                    submitLabel: 'Create Role Membership',
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
                        successMessage: 'Role membership created.',
                        failureMessage: 'Role membership create failed.',
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

  Future<void> _deleteRoleMembership({
    required String tenantId,
    required RbacRoleMembershipEntity membership,
  }) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: 'Delete this role membership?',
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
      successMessage: 'Role membership deleted.',
      failureMessage: 'Role membership delete failed.',
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
    RbacAdminState state, {
    required String? roleId,
    required String? userId,
  }) {
    if (roleId == null || userId == null) {
      return false;
    }

    return state.tenantRoleMemberships.any(
      (membership) =>
          membership.roleId == roleId &&
          membership.userId == userId &&
          !membership.deleted,
    );
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

class _RbacSearchItem {
  _RbacSearchItem({required String searchText, required this.child})
    : searchText = searchText.toLowerCase();

  final String searchText;
  final Widget child;

  bool matches(List<String> tokens) {
    return tokens.every(searchText.contains);
  }
}

class _RbacListSection extends StatefulWidget {
  const _RbacListSection({
    required this.createButtonKey,
    required this.createLabel,
    required this.searchFieldKey,
    required this.searchHint,
    required this.onCreate,
    required this.emptyMessage,
    required this.items,
    super.key,
  });

  final Key createButtonKey;
  final String createLabel;
  final Key searchFieldKey;
  final String searchHint;
  final VoidCallback onCreate;
  final String emptyMessage;
  final List<_RbacSearchItem> items;

  @override
  State<_RbacListSection> createState() => _RbacListSectionState();
}

class _RbacListSectionState extends State<_RbacListSection> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_RbacSearchItem> _visibleItems() {
    final tokens = _searchController.text
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList(growable: false);
    if (tokens.isEmpty) {
      return widget.items;
    }

    return widget.items
        .where((item) => item.matches(tokens))
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = _visibleItems();
    final hasSearchTerm = _searchController.text.trim().isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            OutlinedButton.icon(
              key: widget.createButtonKey,
              onPressed: widget.onCreate,
              icon: const Icon(Icons.add),
              label: Text(widget.createLabel),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                key: widget.searchFieldKey,
                controller: _searchController,
                decoration: appFormInputDecoration(
                  labelText: 'Search',
                  hintText: widget.searchHint,
                  suffixIcon: hasSearchTerm
                      ? IconButton(
                          tooltip: 'Clear search',
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setState(_searchController.clear);
                          },
                        )
                      : const Icon(Icons.search),
                ),
                onChanged: (_) {
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: visibleItems.isEmpty
              ? Center(
                  child: Text(
                    hasSearchTerm ? 'No matching rows.' : widget.emptyMessage,
                  ),
                )
              : ListView.separated(
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => visibleItems[index].child,
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

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}
