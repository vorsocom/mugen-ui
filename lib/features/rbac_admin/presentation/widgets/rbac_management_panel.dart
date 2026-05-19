// coverage:ignore-file
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/providers/rbac_admin_providers.dart';
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
              child: Container(
                key: const Key('rbac-management-tenant-selector'),
                child: DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'rbac-management-tenant-selector-${state.selectedTenantId ?? 'none'}',
                  ),
                  isExpanded: true,
                  initialValue: state.selectedTenantId,
                  decoration: appFormInputDecoration(
                    labelText: 'Tenant',
                    hintText: 'Select tenant',
                  ),
                  items: state.tenants
                      .map(
                        (tenant) => DropdownMenuItem<String>(
                          value: tenant.id,
                          child: Text('${tenant.name} (${tenant.slug})'),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: state.tenants.isEmpty
                      ? null
                      : (value) {
                          if (value == null) {
                            return;
                          }
                          controller.selectTenant(value);
                        },
                ),
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
            child: Text(
              state.errorMessage!,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppUiPalette.danger),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            ChoiceChip(
              key: const Key('rbac-management-tab-global-roles'),
              label: const Text('Global Roles'),
              selected: state.activeTab == RbacAdminTab.globalRoles,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.globalRoles),
            ),
            ChoiceChip(
              key: const Key('rbac-management-tab-permission-objects'),
              label: const Text('Permission Objects'),
              selected: state.activeTab == RbacAdminTab.permissionObjects,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.permissionObjects),
            ),
            ChoiceChip(
              key: const Key('rbac-management-tab-permission-types'),
              label: const Text('Permission Types'),
              selected: state.activeTab == RbacAdminTab.permissionTypes,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.permissionTypes),
            ),
            ChoiceChip(
              key: const Key('rbac-management-tab-global-grants'),
              label: const Text('Global Grants'),
              selected: state.activeTab == RbacAdminTab.globalGrants,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.globalGrants),
            ),
            ChoiceChip(
              key: const Key('rbac-management-tab-tenant-roles'),
              label: const Text('Tenant Roles'),
              selected: state.activeTab == RbacAdminTab.tenantRoles,
              onSelected: (_) =>
                  controller.setActiveTab(RbacAdminTab.tenantRoles),
            ),
            ChoiceChip(
              key: const Key('rbac-management-tab-tenant-grants'),
              label: const Text('Tenant Grants'),
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
              RbacAdminTab.tenantGrants => _buildTenantGrantsTab(state),
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGlobalRolesTab(RbacAdminState state) {
    return _RbacListSection(
      createButtonKey: const Key('rbac-global-role-create-button'),
      createLabel: 'New Global Role',
      onCreate: _showCreateGlobalRoleDialog,
      emptyMessage: 'No global roles found.',
      children: state.globalRoles
          .map(
            (role) => ListTile(
              title: Text(role.displayName),
              subtitle: Text('${role.key}  |  ${role.status}'),
              trailing: _ActionIcon(
                icon: Icons.edit_outlined,
                tooltip: 'Edit global role',
                onPressed: () => _showEditGlobalRoleDialog(role),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildPermissionObjectsTab(RbacAdminState state) {
    return _RbacListSection(
      createButtonKey: const Key('rbac-permission-object-create-button'),
      createLabel: 'New Permission Object',
      onCreate: _showCreatePermissionObjectDialog,
      emptyMessage: 'No permission objects found.',
      children: state.permissionObjects
          .map(
            (permissionObject) => ListTile(
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
          )
          .toList(growable: false),
    );
  }

  Widget _buildPermissionTypesTab(RbacAdminState state) {
    return _RbacListSection(
      createButtonKey: const Key('rbac-permission-type-create-button'),
      createLabel: 'New Permission Type',
      onCreate: _showCreatePermissionTypeDialog,
      emptyMessage: 'No permission types found.',
      children: state.permissionTypes
          .map(
            (permissionType) => ListTile(
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
          )
          .toList(growable: false),
    );
  }

  Widget _buildGlobalGrantsTab(RbacAdminState state) {
    return _RbacListSection(
      createButtonKey: const Key('rbac-global-grant-create-button'),
      createLabel: 'New Global Grant',
      onCreate: _showCreateGlobalGrantDialog,
      emptyMessage: 'No global grants found.',
      children: state.globalPermissionEntries
          .map(
            (entry) => ListTile(
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
      createButtonKey: const Key('rbac-tenant-role-create-button'),
      createLabel: 'New Tenant Role',
      onCreate: () => _showCreateTenantRoleDialog(tenantId),
      emptyMessage: 'No tenant roles found.',
      children: state.tenantRoles
          .map(
            (role) => ListTile(
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
      createButtonKey: const Key('rbac-tenant-grant-create-button'),
      createLabel: 'New Tenant Grant',
      onCreate: () => _showCreateTenantGrantDialog(tenantId),
      emptyMessage: 'No tenant grants found.',
      children: state.tenantPermissionEntries
          .map(
            (entry) => ListTile(
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
          )
          .toList(growable: false),
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
                    decoration: appFormInputDecoration(labelText: 'Namespace'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(labelText: 'Name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
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
                    decoration: appFormInputDecoration(labelText: 'Namespace'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(labelText: 'Name'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: displayNameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Display Name',
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
                    decoration: appFormInputDecoration(labelText: 'Namespace'),
                    validator: _requiredValidator,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(labelText: 'Name'),
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
    String? selectedRoleId = state.globalRoles.first.id;
    String? selectedPermissionObjectId = state.permissionObjects.first.id;
    String? selectedPermissionTypeId = state.permissionTypes.first.id;
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
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedRoleId,
                        decoration: appFormInputDecoration(labelText: 'Role'),
                        items: state.globalRoles
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role.id,
                                child: _buildDropdownLabel(role.displayName),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRoleId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedPermissionObjectId,
                        decoration: appFormInputDecoration(
                          labelText: 'Permission Object',
                        ),
                        items: state.permissionObjects
                            .map(
                              (permissionObject) => DropdownMenuItem<String>(
                                value: permissionObject.id,
                                child: _buildDropdownLabel(
                                  permissionObject.key,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPermissionObjectId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedPermissionTypeId,
                        decoration: appFormInputDecoration(
                          labelText: 'Permission Type',
                        ),
                        items: state.permissionTypes
                            .map(
                              (permissionType) => DropdownMenuItem<String>(
                                value: permissionType.id,
                                child: _buildDropdownLabel(permissionType.key),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPermissionTypeId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      SwitchListTile(
                        value: permitted,
                        title: const Text('Permitted'),
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
                          if (!isValid ||
                              selectedRoleId == null ||
                              selectedPermissionObjectId == null ||
                              selectedPermissionTypeId == null) {
                            return;
                          }

                          final success = await ref
                              .read(rbacAdminControllerProvider.notifier)
                              .createGlobalPermissionEntry(
                                RbacCreateGlobalPermissionEntryInput(
                                  globalRoleId: selectedRoleId!,
                                  permissionObjectId:
                                      selectedPermissionObjectId!,
                                  permissionTypeId: selectedPermissionTypeId!,
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
    String? selectedRoleId = state.tenantRoles.first.id;
    String? selectedPermissionObjectId = state.permissionObjects.first.id;
    String? selectedPermissionTypeId = state.permissionTypes.first.id;
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
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedRoleId,
                        decoration: appFormInputDecoration(labelText: 'Role'),
                        items: state.tenantRoles
                            .map(
                              (role) => DropdownMenuItem<String>(
                                value: role.id,
                                child: _buildDropdownLabel(role.displayName),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedRoleId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedPermissionObjectId,
                        decoration: appFormInputDecoration(
                          labelText: 'Permission Object',
                        ),
                        items: state.permissionObjects
                            .map(
                              (permissionObject) => DropdownMenuItem<String>(
                                value: permissionObject.id,
                                child: _buildDropdownLabel(
                                  permissionObject.key,
                                ),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPermissionObjectId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: selectedPermissionTypeId,
                        decoration: appFormInputDecoration(
                          labelText: 'Permission Type',
                        ),
                        items: state.permissionTypes
                            .map(
                              (permissionType) => DropdownMenuItem<String>(
                                value: permissionType.id,
                                child: _buildDropdownLabel(permissionType.key),
                              ),
                            )
                            .toList(growable: false),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedPermissionTypeId = value;
                          });
                        },
                        validator: (value) =>
                            value == null ? 'Field cannot be empty.' : null,
                      ),
                      SwitchListTile(
                        value: permitted,
                        title: const Text('Permitted'),
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
                          if (!isValid ||
                              selectedRoleId == null ||
                              selectedPermissionObjectId == null ||
                              selectedPermissionTypeId == null) {
                            return;
                          }

                          final success = await ref
                              .read(rbacAdminControllerProvider.notifier)
                              .createTenantPermissionEntry(
                                RbacCreateTenantPermissionEntryInput(
                                  tenantId: tenantId,
                                  roleId: selectedRoleId!,
                                  permissionObjectId:
                                      selectedPermissionObjectId!,
                                  permissionTypeId: selectedPermissionTypeId!,
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

  Widget _buildDropdownLabel(String label) {
    return Tooltip(
      message: label,
      child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
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
}

class _RbacListSection extends StatelessWidget {
  const _RbacListSection({
    required this.createButtonKey,
    required this.createLabel,
    required this.onCreate,
    required this.emptyMessage,
    required this.children,
  });

  final Key createButtonKey;
  final String createLabel;
  final VoidCallback onCreate;
  final String emptyMessage;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: createButtonKey,
            onPressed: onCreate,
            icon: const Icon(Icons.add),
            label: Text(createLabel),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: children.isEmpty
              ? Center(child: Text(emptyMessage))
              : ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, index) => children[index],
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
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 8),
        FilledButton(onPressed: onSubmit, child: Text(submitLabel)),
      ],
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
