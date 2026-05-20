import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/providers/tenant_admin_providers.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _formDialogPanelWidth = 520;
const Duration _membershipSearchDebounceDuration = Duration(milliseconds: 300);
const int _membershipUserSearchPageSize = 20;
const String _defaultTenantMembershipRole = 'member';

const List<_TenantMembershipRoleOption> _tenantMembershipRoleOptions =
    <_TenantMembershipRoleOption>[
      _TenantMembershipRoleOption(value: 'member', label: 'Member'),
      _TenantMembershipRoleOption(value: 'admin', label: 'Admin'),
      _TenantMembershipRoleOption(value: 'owner', label: 'Owner'),
    ];

class _TenantMembershipRoleOption {
  const _TenantMembershipRoleOption({required this.value, required this.label});

  final String value;
  final String label;
}

class TenantManagementPanel extends ConsumerStatefulWidget {
  const TenantManagementPanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<TenantManagementPanel> createState() =>
      _TenantManagementPanelState();
}

class _TenantManagementPanelState extends ConsumerState<TenantManagementPanel> {
  Timer? _searchDebounce;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(tenantAdminControllerProvider.notifier).loadTenants();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantAdminControllerProvider);
    final controller = ref.read(tenantAdminControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FilledButton.icon(
              key: const Key('tenant-management-new-tenant-button'),
              onPressed: () => _showTenantDialog(),
              icon: const Icon(Icons.add),
              label: const Text('New Tenant'),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              onPressed: () => controller.loadTenants(),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextFormField(
          key: const Key('tenant-management-search-field'),
          decoration: appFormInputDecoration(
            labelText: 'Search tenants',
            hintText: 'Name or slug',
            suffixIcon: const Icon(Icons.search),
          ),
          onChanged: (value) {
            _searchDebounce?.cancel();
            _searchDebounce = Timer(_searchDebounceDuration, () async {
              controller.setSearchTerm(value.trim());
              await controller.loadTenants();
            });
          },
        ),
        if (state.isLoadingTenants)
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
        AppFormPanel(
          margin: EdgeInsets.zero,
          child: _TenantSelector(
            tenants: state.tenants,
            selectedTenant: state.selectedTenant,
            selectedTenantId: state.selectedTenantId,
            onSelected: controller.selectTenant,
            onEdit: state.selectedTenant == null
                ? null
                : () => _showTenantDialog(existingTenant: state.selectedTenant),
            onLifecycleAction: state.selectedTenant == null
                ? null
                : () => _runTenantLifecycle(state.selectedTenant!),
          ),
        ),
        const SizedBox(height: 8),
        _TenantPaginator(state: state),
        const SizedBox(height: 8),
        Expanded(
          child: AppFormPanel(
            margin: EdgeInsets.zero,
            child: state.selectedTenant == null
                ? const Center(
                    child: Text(
                      'Select a tenant to manage domains and access.',
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          _TenantTabChip(
                            chipKey: const Key('tenant-management-tab-domains'),
                            label: 'Domains',
                            tooltip:
                                'Verified tenant domains used to identify tenant-owned traffic.',
                            tooltipKey: const Key(
                              'tenant-management-tab-domains-info',
                            ),
                            selected: state.activeTab == TenantAdminTab.domains,
                            onSelected: (_) =>
                                controller.setActiveTab(TenantAdminTab.domains),
                          ),
                          _TenantTabChip(
                            chipKey: const Key(
                              'tenant-management-tab-invitations',
                            ),
                            label: 'Invitations',
                            tooltip:
                                'Pending invitations for adding users to this tenant.',
                            tooltipKey: const Key(
                              'tenant-management-tab-invitations-info',
                            ),
                            selected:
                                state.activeTab == TenantAdminTab.invitations,
                            onSelected: (_) => controller.setActiveTab(
                              TenantAdminTab.invitations,
                            ),
                          ),
                          _TenantTabChip(
                            chipKey: const Key(
                              'tenant-management-tab-memberships',
                            ),
                            label: 'Memberships',
                            tooltip:
                                'Users assigned to this tenant and their tenant roles.',
                            tooltipKey: const Key(
                              'tenant-management-tab-memberships-info',
                            ),
                            selected:
                                state.activeTab == TenantAdminTab.memberships,
                            onSelected: (_) => controller.setActiveTab(
                              TenantAdminTab.memberships,
                            ),
                          ),
                        ],
                      ),
                      if (state.isLoadingDetails)
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: LinearProgressIndicator(),
                        ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: switch (state.activeTab) {
                          TenantAdminTab.domains => _TenantDomainsTab(
                            tenant: state.selectedTenant!,
                            domains: state.domains,
                          ),
                          TenantAdminTab.invitations => _TenantInvitationsTab(
                            tenant: state.selectedTenant!,
                            invitations: state.invitations,
                          ),
                          TenantAdminTab.memberships => _TenantMembershipsTab(
                            tenant: state.selectedTenant!,
                            memberships: state.memberships,
                          ),
                        },
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Future<void> _runTenantLifecycle(TenantEntity tenant) async {
    final isActive = _isActiveStatus(tenant.status);
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: isActive
          ? 'Deactivating this tenant stops tenant access until reactivated.'
          : 'Reactivating this tenant restores tenant access.',
      confirmLabel: 'Continue',
    );
    if (confirmed != true) {
      return;
    }

    final controller = ref.read(tenantAdminControllerProvider.notifier);
    final success = isActive
        ? await controller.deactivateTenant(
            TenantLifecycleInput(
              tenantId: tenant.id,
              rowVersion: tenant.rowVersion,
            ),
          )
        : await controller.reactivateTenant(
            TenantLifecycleInput(
              tenantId: tenant.id,
              rowVersion: tenant.rowVersion,
            ),
          );
    if (!mounted) {
      return;
    }

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);
    snackBar.show(
      navigator,
      success ? 'Tenant update completed.' : 'Tenant update failed.',
    );
  }

  Future<void> _showTenantDialog({TenantEntity? existingTenant}) async {
    final isEditing = existingTenant != null;
    final nameController = TextEditingController(text: existingTenant?.name);
    final slugController = TextEditingController(text: existingTenant?.slug);
    final formKey = GlobalKey<FormState>();
    final controller = ref.read(tenantAdminControllerProvider.notifier);
    final navigator = ref.read(appNavigatorProvider);
    final snackBar = ref.read(snackBarDispatcherProvider);

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
                  Text(
                    isEditing ? 'Edit Tenant' : 'Create Tenant',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: nameController,
                    decoration: appFormInputDecoration(
                      labelText: 'Name',
                      helpText: acpFieldHelpText(key: 'Name', label: 'Name'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Field cannot be empty.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: slugController,
                    decoration: appFormInputDecoration(
                      labelText: 'Slug',
                      helpText: acpFieldHelpText(key: 'Slug', label: 'Slug'),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Field cannot be empty.';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final isValid =
                              formKey.currentState?.validate() ?? false;
                          if (!isValid) {
                            return;
                          }

                          final success = isEditing
                              ? await controller.updateTenant(
                                  UpdateTenantInput(
                                    tenantId: existingTenant.id,
                                    name: nameController.text.trim(),
                                    slug: slugController.text.trim(),
                                    rowVersion: existingTenant.rowVersion,
                                  ),
                                )
                              : await controller.createTenant(
                                  CreateTenantInput(
                                    name: nameController.text.trim(),
                                    slug: slugController.text.trim(),
                                  ),
                                );
                          snackBar.show(
                            navigator,
                            success
                                ? 'Tenant saved successfully.'
                                : 'Tenant save failed.',
                          );
                          if (success && mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          isEditing ? 'Save Changes' : 'Create Tenant',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TenantSelector extends StatelessWidget {
  const _TenantSelector({
    required this.tenants,
    required this.selectedTenant,
    required this.selectedTenantId,
    required this.onSelected,
    required this.onEdit,
    required this.onLifecycleAction,
  });

  final List<TenantEntity> tenants;
  final TenantEntity? selectedTenant;
  final String? selectedTenantId;
  final Future<void> Function(String tenantId) onSelected;
  final VoidCallback? onEdit;
  final VoidCallback? onLifecycleAction;

  @override
  Widget build(BuildContext context) {
    if (tenants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('No tenants found.'),
      );
    }

    final selected = selectedTenant;
    final lifecycleIsActive =
        selected != null && _isActiveStatus(selected.status);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 420,
          child: DropdownButtonFormField<String>(
            key: const Key('tenant-management-tenant-selector'),
            initialValue: selectedTenantId,
            isExpanded: true,
            decoration: appFormInputDecoration(labelText: 'Tenant'),
            items: tenants
                .map(
                  (tenant) => DropdownMenuItem<String>(
                    value: tenant.id,
                    child: Text(_tenantSelectorLabel(tenant)),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              unawaited(onSelected(value));
            },
          ),
        ),
        if (selected != null)
          Container(
            key: const Key('tenant-management-selected-tenant-actions'),
            decoration: BoxDecoration(
              color: AppUiPalette.surfaceMuted,
              border: Border.all(color: AppUiPalette.border),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionIcon(
                  icon: Icons.edit_outlined,
                  tooltip: 'Edit tenant',
                  onPressed: onEdit,
                ),
                _ActionIcon(
                  icon: lifecycleIsActive
                      ? Icons.pause_circle_outline
                      : Icons.play_circle_outline,
                  tooltip: lifecycleIsActive
                      ? 'Deactivate tenant'
                      : 'Reactivate tenant',
                  onPressed: onLifecycleAction,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _TenantTabChip extends StatelessWidget {
  const _TenantTabChip({
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

class _TenantPaginator extends ConsumerWidget {
  const _TenantPaginator({required this.state});

  final TenantAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(tenantAdminControllerProvider.notifier);
    final hasPrev = state.page > 1;
    final hasNext = state.page < state.pages;
    return Row(
      children: [
        const Text('Rows per page'),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: state.pageSize,
          onChanged: (value) async {
            if (value == null) {
              return;
            }
            controller.setRowsPerPage(value);
            await controller.loadTenants();
          },
          items: const [
            DropdownMenuItem<int>(value: 15, child: Text('15')),
            DropdownMenuItem<int>(value: 25, child: Text('25')),
            DropdownMenuItem<int>(value: 50, child: Text('50')),
          ],
        ),
        const Spacer(),
        Text('Page ${state.page} / ${state.pages}'),
        IconButton(
          tooltip: 'Previous page',
          onPressed: !hasPrev
              ? null
              : () async {
                  controller.setPage(state.page - 1);
                  await controller.loadTenants();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: !hasNext
              ? null
              : () async {
                  controller.setPage(state.page + 1);
                  await controller.loadTenants();
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class _TenantDomainsTab extends ConsumerWidget {
  const _TenantDomainsTab({required this.tenant, required this.domains});

  final TenantEntity tenant;
  final List<TenantDomainEntity> domains;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TenantDetailList(
      emptyMessage: 'No domains added.',
      onCreate: () {
        unawaited(_showDomainDialog(context, ref, tenant: tenant));
      },
      createLabel: 'Add Domain',
      children: domains
          .map(
            (domain) => ListTile(
              title: Text(domain.domain),
              subtitle: Text(domain.isPrimary ? 'Primary' : 'Secondary'),
              trailing: Wrap(
                spacing: 4,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit domain',
                    onPressed: () => _showDomainDialog(
                      context,
                      ref,
                      tenant: tenant,
                      existing: domain,
                    ),
                  ),
                  _ActionIcon(
                    icon: Icons.delete_outline,
                    tooltip: 'Delete domain',
                    onPressed: () async {
                      final confirmed = await showAppConfirmationDialog(
                        context: context,
                        title: 'Confirmation Required',
                        message: 'Delete this tenant domain?',
                        confirmLabel: 'Delete',
                      );
                      if (confirmed != true) {
                        return;
                      }

                      final controller = ref.read(
                        tenantAdminControllerProvider.notifier,
                      );
                      final success = await controller.deleteDomain(
                        DeleteTenantDomainInput(
                          tenantId: tenant.id,
                          domainId: domain.id,
                          rowVersion: domain.rowVersion,
                        ),
                      );
                      final snackBar = ref.read(snackBarDispatcherProvider);
                      final navigator = ref.read(appNavigatorProvider);
                      snackBar.show(
                        navigator,
                        success
                            ? 'Domain deleted successfully.'
                            : 'Domain delete failed.',
                      );
                    },
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _TenantInvitationsTab extends ConsumerWidget {
  const _TenantInvitationsTab({
    required this.tenant,
    required this.invitations,
  });

  final TenantEntity tenant;
  final List<TenantInvitationEntity> invitations;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TenantDetailList(
      emptyMessage: 'No invitations found.',
      onCreate: () {
        unawaited(_showInvitationDialog(context, ref, tenant: tenant));
      },
      createLabel: 'Invite Member',
      children: invitations
          .map((invitation) {
            final normalizedStatus = invitation.status.toLowerCase();
            final canResend = !normalizedStatus.contains('revoked');
            final canRevoke = !normalizedStatus.contains('revoked');
            return ListTile(
              title: Text(invitation.email),
              subtitle: Text(
                '${invitation.roleInTenant}  |  ${invitation.status}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  _ActionIcon(
                    icon: Icons.forward_to_inbox_outlined,
                    tooltip: 'Resend invitation',
                    onPressed: !canResend
                        ? null
                        : () async {
                            await _runInvitationAction(
                              context,
                              ref,
                              input: TenantInvitationActionInput(
                                tenantId: tenant.id,
                                invitationId: invitation.id,
                                rowVersion: invitation.rowVersion,
                              ),
                              actionLabel: 'Invitation resent.',
                              action: (controller, input) =>
                                  controller.resendInvitation(input),
                            );
                          },
                  ),
                  _ActionIcon(
                    icon: Icons.cancel_outlined,
                    tooltip: 'Revoke invitation',
                    onPressed: !canRevoke
                        ? null
                        : () async {
                            await _runInvitationAction(
                              context,
                              ref,
                              input: TenantInvitationActionInput(
                                tenantId: tenant.id,
                                invitationId: invitation.id,
                                rowVersion: invitation.rowVersion,
                              ),
                              actionLabel: 'Invitation revoked.',
                              action: (controller, input) =>
                                  controller.revokeInvitation(input),
                            );
                          },
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _TenantMembershipsTab extends ConsumerWidget {
  const _TenantMembershipsTab({
    required this.tenant,
    required this.memberships,
  });

  final TenantEntity tenant;
  final List<TenantMembershipEntity> memberships;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TenantDetailList(
      emptyMessage: 'No memberships found.',
      onCreate: () {
        unawaited(
          _showMembershipDialog(
            context,
            tenant: tenant,
            memberships: memberships,
          ),
        );
      },
      createLabel: 'Add Membership',
      children: memberships
          .map((membership) {
            final normalizedStatus = membership.status.toLowerCase();
            final isSuspended = normalizedStatus.contains('suspend');
            return ListTile(
              title: Text(_tenantMembershipUserTitle(membership)),
              subtitle: Text(_tenantMembershipSubtitle(membership)),
              trailing: Wrap(
                spacing: 4,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit membership role',
                    onPressed: () => _showMembershipDialog(
                      context,
                      tenant: tenant,
                      memberships: memberships,
                      existing: membership,
                    ),
                  ),
                  _ActionIcon(
                    icon: isSuspended
                        ? Icons.play_circle_outline
                        : Icons.pause_circle_outline,
                    tooltip: isSuspended
                        ? 'Unsuspend membership'
                        : 'Suspend membership',
                    onPressed: () async {
                      final controller = ref.read(
                        tenantAdminControllerProvider.notifier,
                      );
                      final input = TenantMembershipActionInput(
                        tenantId: tenant.id,
                        membershipId: membership.id,
                        rowVersion: membership.rowVersion,
                      );
                      final success = isSuspended
                          ? await controller.unsuspendMembership(input)
                          : await controller.suspendMembership(input);
                      final snackBar = ref.read(snackBarDispatcherProvider);
                      final navigator = ref.read(appNavigatorProvider);
                      snackBar.show(
                        navigator,
                        success
                            ? 'Membership action completed.'
                            : 'Membership action failed.',
                      );
                    },
                  ),
                  _ActionIcon(
                    icon: Icons.person_remove_outlined,
                    tooltip: 'Remove membership',
                    onPressed: () async {
                      final confirmed = await showAppConfirmationDialog(
                        context: context,
                        title: 'Confirmation Required',
                        message: 'Remove this membership from the tenant?',
                        confirmLabel: 'Remove',
                      );
                      if (confirmed != true) {
                        return;
                      }

                      final success = await ref
                          .read(tenantAdminControllerProvider.notifier)
                          .removeMembership(
                            TenantMembershipActionInput(
                              tenantId: tenant.id,
                              membershipId: membership.id,
                              rowVersion: membership.rowVersion,
                            ),
                          );
                      final snackBar = ref.read(snackBarDispatcherProvider);
                      final navigator = ref.read(appNavigatorProvider);
                      snackBar.show(
                        navigator,
                        success
                            ? 'Membership removed.'
                            : 'Membership removal failed.',
                      );
                    },
                  ),
                ],
              ),
            );
          })
          .toList(growable: false),
    );
  }
}

class _TenantDetailList extends StatelessWidget {
  const _TenantDetailList({
    required this.emptyMessage,
    required this.onCreate,
    required this.createLabel,
    required this.children,
  });

  final String emptyMessage;
  final VoidCallback onCreate;
  final String createLabel;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
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
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
    );
  }
}

bool _isActiveStatus(String status) {
  final normalized = status.toLowerCase().trim();
  return normalized == 'active' ||
      normalized == 'enabled' ||
      normalized == 'reactivated';
}

String _tenantSelectorLabel(TenantEntity tenant) {
  return '${tenant.name} (${tenant.slug}) - ${tenant.status}';
}

String _tenantMembershipUserTitle(TenantMembershipEntity membership) {
  final userName = membership.userName?.trim();
  if (userName != null && userName.isNotEmpty) {
    return userName;
  }

  return membership.userId;
}

String _tenantMembershipSubtitle(TenantMembershipEntity membership) {
  final details = <String>[];
  final email = membership.userEmail?.trim();
  if (email != null && email.isNotEmpty) {
    details.add(email);
  }
  details.add(membership.roleInTenant);
  details.add(membership.status);
  return details.join('  |  ');
}

String _tenantMembershipUserContext(TenantMembershipEntity membership) {
  final title = _tenantMembershipUserTitle(membership);
  final email = membership.userEmail?.trim();
  if (email == null || email.isEmpty) {
    return title;
  }

  return '$title  |  $email';
}

Future<void> _showDomainDialog(
  BuildContext context,
  WidgetRef ref, {
  required TenantEntity tenant,
  TenantDomainEntity? existing,
}) async {
  final domainController = TextEditingController(text: existing?.domain);
  var isPrimary = existing?.isPrimary ?? false;
  final formKey = GlobalKey<FormState>();
  final controller = ref.read(tenantAdminControllerProvider.notifier);
  final navigator = ref.read(appNavigatorProvider);
  final snackBar = ref.read(snackBarDispatcherProvider);

  await showDialog<void>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        child: SizedBox(
          width: _formDialogPanelWidth,
          child: AppFormPanel(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    existing == null ? 'Add Domain' : 'Edit Domain',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: domainController,
                    decoration: appFormInputDecoration(
                      labelText: 'Domain',
                      helpText: acpFieldHelpText(
                        key: 'Domain',
                        label: 'Domain',
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Field cannot be empty.';
                      }

                      return null;
                    },
                  ),
                  CheckboxListTile(
                    value: isPrimary,
                    title: appFieldLabelWithHelp(
                      labelText: 'Primary domain',
                      helpText: acpFieldHelpText(
                        key: 'IsPrimary',
                        label: 'Primary Domain',
                        kind: AcpFieldKind.boolean,
                      ),
                    ),
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setState(() {
                        isPrimary = value ?? false;
                      });
                    },
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          final isValid =
                              formKey.currentState?.validate() ?? false;
                          if (!isValid) {
                            return;
                          }

                          final success = existing == null
                              ? await controller.createDomain(
                                  CreateTenantDomainInput(
                                    tenantId: tenant.id,
                                    domain: domainController.text.trim(),
                                    isPrimary: isPrimary,
                                  ),
                                )
                              : await controller.updateDomain(
                                  UpdateTenantDomainInput(
                                    tenantId: tenant.id,
                                    domainId: existing.id,
                                    domain: domainController.text.trim(),
                                    isPrimary: isPrimary,
                                    rowVersion: existing.rowVersion,
                                  ),
                                );
                          snackBar.show(
                            navigator,
                            success
                                ? 'Domain saved successfully.'
                                : 'Domain save failed.',
                          );
                          if (success && context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(existing == null ? 'Add Domain' : 'Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showInvitationDialog(
  BuildContext context,
  WidgetRef ref, {
  required TenantEntity tenant,
}) async {
  final emailController = TextEditingController();
  final roleController = TextEditingController(text: 'member');
  final formKey = GlobalKey<FormState>();
  final controller = ref.read(tenantAdminControllerProvider.notifier);
  final navigator = ref.read(appNavigatorProvider);
  final snackBar = ref.read(snackBarDispatcherProvider);

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
                Text(
                  'Create Invitation',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailController,
                  decoration: appFormInputDecoration(
                    labelText: 'Email',
                    helpText: acpFieldHelpText(key: 'Email', label: 'Email'),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Field cannot be empty.';
                    }

                    if (!value.contains('@')) {
                      return 'Email address must be valid';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: roleController,
                  decoration: appFormInputDecoration(
                    labelText: 'Role In Tenant',
                    helpText: acpFieldHelpText(
                      key: 'RoleInTenant',
                      label: 'Role In Tenant',
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Field cannot be empty.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () async {
                        final isValid =
                            formKey.currentState?.validate() ?? false;
                        if (!isValid) {
                          return;
                        }

                        final success = await controller.createInvitation(
                          CreateTenantInvitationInput(
                            tenantId: tenant.id,
                            email: emailController.text.trim(),
                            roleInTenant: roleController.text.trim(),
                          ),
                        );
                        snackBar.show(
                          navigator,
                          success
                              ? 'Invitation created.'
                              : 'Invitation creation failed.',
                        );
                        if (success && context.mounted) {
                          Navigator.of(context).pop();
                        }
                      },
                      child: const Text('Create Invitation'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<void> _showMembershipDialog(
  BuildContext context, {
  required TenantEntity tenant,
  required List<TenantMembershipEntity> memberships,
  TenantMembershipEntity? existing,
}) async {
  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: SizedBox(
        width: _formDialogPanelWidth,
        child: _TenantMembershipDialog(
          tenant: tenant,
          memberships: memberships,
          existing: existing,
        ),
      ),
    ),
  );
}

class _TenantMembershipDialog extends ConsumerStatefulWidget {
  const _TenantMembershipDialog({
    required this.tenant,
    required this.memberships,
    this.existing,
  });

  final TenantEntity tenant;
  final List<TenantMembershipEntity> memberships;
  final TenantMembershipEntity? existing;

  @override
  ConsumerState<_TenantMembershipDialog> createState() =>
      _TenantMembershipDialogState();
}

class _TenantMembershipDialogState
    extends ConsumerState<_TenantMembershipDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final GlobalKey<FormFieldState<UserEntity>> _userFieldKey =
      GlobalKey<FormFieldState<UserEntity>>();
  final TextEditingController _userSearchController = TextEditingController();

  Timer? _searchDebounce;
  int _searchGeneration = 0;
  List<UserEntity> _userResults = const <UserEntity>[];
  UserEntity? _selectedUser;
  String? _searchError;
  late String _selectedRole;
  bool _isSearching = false;
  bool _hasSearched = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _selectedRole = _initialMembershipRole(widget.existing?.roleInTenant);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _userSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPanel(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _isEditing ? 'Edit Membership Role' : 'Add Membership',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            _isEditing ? _buildReadonlyUserField() : _buildUserPicker(),
            const SizedBox(height: 8),
            _buildRoleDropdown(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _submit,
                  child: Text(_isEditing ? 'Save' : 'Add Membership'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReadonlyUserField() {
    final membership = widget.existing!;
    return TextFormField(
      key: const Key('tenant-membership-user-readonly-field'),
      initialValue: _tenantMembershipUserContext(membership),
      enabled: false,
      decoration: appFormInputDecoration(
        labelText: 'User',
        helpText: acpFieldHelpText(key: 'User', label: 'User'),
      ),
    );
  }

  Widget _buildUserPicker() {
    return FormField<UserEntity>(
      key: _userFieldKey,
      validator: (_) => _selectedUser == null ? 'Select a user.' : null,
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const Key('tenant-membership-user-search-field'),
              controller: _userSearchController,
              decoration: appFormInputDecoration(
                labelText: 'User',
                hintText: 'Username, name, or email',
                suffixIcon: const Icon(Icons.person_search_outlined),
                helpText: acpFieldHelpText(key: 'User', label: 'User'),
              ),
              onChanged: _queueUserSearch,
            ),
            if (fieldState.errorText != null) ...[
              const SizedBox(height: 6),
              Text(
                fieldState.errorText!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppUiPalette.danger),
              ),
            ],
            if (_selectedUser != null) ...[
              const SizedBox(height: 8),
              _SelectedUserTile(user: _selectedUser!),
            ],
            if (_isSearching) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_searchError != null && _searchError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                _searchError!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppUiPalette.danger),
              ),
            ],
            if (_hasSearched && !_isSearching && _searchError == null) ...[
              const SizedBox(height: 8),
              _buildUserResults(),
            ],
          ],
        );
      },
    );
  }

  Widget _buildUserResults() {
    if (_userResults.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No users found.'),
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
          itemCount: _userResults.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = _userResults[index];
            final isExistingMember = _isExistingMember(user);
            final isSelected = _selectedUser?.id == user.id;
            return ListTile(
              key: Key('tenant-membership-user-option-${user.id}'),
              enabled: !isExistingMember,
              selected: isSelected,
              leading: Icon(
                isExistingMember
                    ? Icons.person_off_outlined
                    : Icons.person_outline,
              ),
              title: Text(user.userName),
              subtitle: Text(
                isExistingMember
                    ? 'Already a tenant member'
                    : _userSubtitle(user),
              ),
              onTap: isExistingMember ? null : () => _selectUser(user),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    final options = _membershipRoleOptionsFor(_selectedRole);
    return DropdownButtonFormField<String>(
      key: const Key('tenant-membership-role-dropdown'),
      initialValue: _selectedRole,
      isExpanded: true,
      decoration: appFormInputDecoration(
        labelText: 'Role In Tenant',
        helpText: acpFieldHelpText(
          key: 'RoleInTenant',
          label: 'Role In Tenant',
        ),
      ),
      items: options
          .map(
            (option) => DropdownMenuItem<String>(
              value: option.value,
              child: Text(option.label),
            ),
          )
          .toList(growable: false),
      onChanged: (value) {
        if (value == null) {
          return;
        }

        setState(() {
          _selectedRole = value;
        });
      },
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Field cannot be empty.';
        }

        return null;
      },
    );
  }

  void _queueUserSearch(String value) {
    _searchDebounce?.cancel();
    final term = value.trim();
    if (term.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _searchError = null;
        _userResults = const <UserEntity>[];
      });
      return;
    }

    if (term.length < 2) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _searchError = null;
        _userResults = const <UserEntity>[];
      });
      return;
    }

    _searchDebounce = Timer(
      _membershipSearchDebounceDuration,
      () => _searchUsers(term),
    );
  }

  Future<void> _searchUsers(String term) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });

    final response = await ref
        .read(userAdminRepositoryProvider)
        .fetchUsers(
          UserListQuery(
            pageRequest: const PageRequest(
              page: 1,
              pageSize: _membershipUserSearchPageSize,
            ),
            searchTerm: term,
          ),
        );

    if (!mounted || generation != _searchGeneration) {
      return;
    }

    if (response.isFailure) {
      setState(() {
        _isSearching = false;
        _userResults = const <UserEntity>[];
        _searchError = response.failure?.message ?? 'Could not search users.';
      });
      return;
    }

    setState(() {
      _isSearching = false;
      _userResults = response.data?.items ?? const <UserEntity>[];
      _searchError = null;
    });
  }

  void _selectUser(UserEntity user) {
    setState(() {
      _selectedUser = user;
    });
    _userFieldKey.currentState?.didChange(user);
    _userFieldKey.currentState?.validate();
  }

  bool _isExistingMember(UserEntity user) {
    return widget.memberships.any((membership) => membership.userId == user.id);
  }

  Future<void> _submit() async {
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid || (!_isEditing && _selectedUser == null)) {
      return;
    }

    final controller = ref.read(tenantAdminControllerProvider.notifier);
    final role = _selectedRole.trim();
    final success = _isEditing
        ? await controller.updateMembership(
            UpdateTenantMembershipInput(
              tenantId: widget.tenant.id,
              membershipId: widget.existing!.id,
              roleInTenant: role,
              rowVersion: widget.existing!.rowVersion,
            ),
          )
        : await controller.createMembership(
            CreateTenantMembershipInput(
              tenantId: widget.tenant.id,
              userId: _selectedUser!.id,
              roleInTenant: role,
            ),
          );

    final snackBar = ref.read(snackBarDispatcherProvider);
    final navigator = ref.read(appNavigatorProvider);
    snackBar.show(
      navigator,
      success ? 'Membership saved.' : 'Membership save failed.',
    );
    if (success && mounted) {
      Navigator.of(context).pop();
    }
  }

  String _userSubtitle(UserEntity user) {
    final fullName = '${user.person.firstName} ${user.person.lastName}'.trim();
    if (fullName.isEmpty) {
      return '${user.email}  |  ${user.id}';
    }

    return '$fullName  |  ${user.email}';
  }
}

class _SelectedUserTile extends StatelessWidget {
  const _SelectedUserTile({required this.user});

  final UserEntity user;

  @override
  Widget build(BuildContext context) {
    final fullName = '${user.person.firstName} ${user.person.lastName}'.trim();
    return Container(
      key: const Key('tenant-membership-selected-user'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppUiPalette.surfaceStrong,
        border: Border.all(color: AppUiPalette.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              fullName.isEmpty
                  ? '${user.userName}  |  ${user.email}'
                  : '${user.userName}  |  $fullName',
            ),
          ),
        ],
      ),
    );
  }
}

String _initialMembershipRole(String? rawRole) {
  final role = rawRole?.trim();
  if (role == null || role.isEmpty) {
    return _defaultTenantMembershipRole;
  }

  return role;
}

List<_TenantMembershipRoleOption> _membershipRoleOptionsFor(String role) {
  final selectedRole = role.trim();
  final hasSelectedRole = _tenantMembershipRoleOptions.any(
    (option) => option.value == selectedRole,
  );
  if (selectedRole.isEmpty || hasSelectedRole) {
    return _tenantMembershipRoleOptions;
  }

  return <_TenantMembershipRoleOption>[
    ..._tenantMembershipRoleOptions,
    _TenantMembershipRoleOption(value: selectedRole, label: selectedRole),
  ];
}

Future<void> _runInvitationAction(
  BuildContext context,
  WidgetRef ref, {
  required TenantInvitationActionInput input,
  required String actionLabel,
  required Future<bool> Function(
    TenantAdminController controller,
    TenantInvitationActionInput input,
  )
  action,
}) async {
  final controller = ref.read(tenantAdminControllerProvider.notifier);
  final success = await action(controller, input);
  final snackBar = ref.read(snackBarDispatcherProvider);
  final navigator = ref.read(appNavigatorProvider);
  snackBar.show(navigator, success ? actionLabel : 'Invitation action failed.');
}
