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
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

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
    final navigator = ref.read(appNavigatorProvider);
    final snackBar = ref.read(snackBarDispatcherProvider);

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
        SizedBox(
          height: 240,
          child: AppFormPanel(
            margin: EdgeInsets.zero,
            child: state.tenants.isEmpty
                ? const Center(child: Text('No tenants found.'))
                : ListView.separated(
                    itemCount: state.tenants.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final tenant = state.tenants[index];
                      final isSelected = tenant.id == state.selectedTenantId;
                      final isActive = _isActiveStatus(tenant.status);
                      return ListTile(
                        selected: isSelected,
                        title: Text(tenant.name),
                        subtitle: Text('${tenant.slug}  |  ${tenant.status}'),
                        onTap: () => controller.selectTenant(tenant.id),
                        trailing: Wrap(
                          spacing: 4,
                          children: [
                            _ActionIcon(
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit tenant',
                              onPressed: () =>
                                  _showTenantDialog(existingTenant: tenant),
                            ),
                            _ActionIcon(
                              icon: isActive
                                  ? Icons.pause_circle_outline
                                  : Icons.play_circle_outline,
                              tooltip: isActive
                                  ? 'Deactivate tenant'
                                  : 'Reactivate tenant',
                              onPressed: () async {
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
                                snackBar.show(
                                  navigator,
                                  success
                                      ? 'Tenant update completed.'
                                      : 'Tenant update failed.',
                                );
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
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
                          ChoiceChip(
                            key: const Key('tenant-management-tab-domains'),
                            label: const Text('Domains'),
                            selected: state.activeTab == TenantAdminTab.domains,
                            onSelected: (_) =>
                                controller.setActiveTab(TenantAdminTab.domains),
                          ),
                          ChoiceChip(
                            key: const Key('tenant-management-tab-invitations'),
                            label: const Text('Invitations'),
                            selected:
                                state.activeTab == TenantAdminTab.invitations,
                            onSelected: (_) => controller.setActiveTab(
                              TenantAdminTab.invitations,
                            ),
                          ),
                          ChoiceChip(
                            key: const Key('tenant-management-tab-memberships'),
                            label: const Text('Memberships'),
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
                  decoration: appFormInputDecoration(labelText: 'Name'),
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
                  decoration: appFormInputDecoration(labelText: 'Slug'),
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
                      child: Text(isEditing ? 'Save Changes' : 'Create Tenant'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
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
        unawaited(_showMembershipDialog(context, ref, tenant: tenant));
      },
      createLabel: 'Add Membership',
      children: memberships
          .map((membership) {
            final normalizedStatus = membership.status.toLowerCase();
            final isSuspended = normalizedStatus.contains('suspend');
            return ListTile(
              title: Text(membership.userId),
              subtitle: Text(
                '${membership.roleInTenant}  |  ${membership.status}',
              ),
              trailing: Wrap(
                spacing: 4,
                children: [
                  _ActionIcon(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit membership role',
                    onPressed: () => _showMembershipDialog(
                      context,
                      ref,
                      tenant: tenant,
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
                  decoration: appFormInputDecoration(labelText: 'Domain'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Field cannot be empty.';
                    }

                    return null;
                  },
                ),
                CheckboxListTile(
                  value: isPrimary,
                  title: const Text('Primary domain'),
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
      child: AppFormPanel(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Create Invitation',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: emailController,
                decoration: appFormInputDecoration(labelText: 'Email'),
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
                decoration: appFormInputDecoration(labelText: 'Role In Tenant'),
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
                      final isValid = formKey.currentState?.validate() ?? false;
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
  );
}

Future<void> _showMembershipDialog(
  BuildContext context,
  WidgetRef ref, {
  required TenantEntity tenant,
  TenantMembershipEntity? existing,
}) async {
  final userIdController = TextEditingController(text: existing?.userId);
  final roleController = TextEditingController(
    text: existing?.roleInTenant ?? 'member',
  );
  final formKey = GlobalKey<FormState>();
  final controller = ref.read(tenantAdminControllerProvider.notifier);
  final navigator = ref.read(appNavigatorProvider);
  final snackBar = ref.read(snackBarDispatcherProvider);

  await showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      child: AppFormPanel(
        child: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existing == null ? 'Add Membership' : 'Edit Membership Role',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: userIdController,
                enabled: existing == null,
                decoration: appFormInputDecoration(labelText: 'User Id'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Field cannot be empty.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: roleController,
                decoration: appFormInputDecoration(labelText: 'Role In Tenant'),
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
                      final isValid = formKey.currentState?.validate() ?? false;
                      if (!isValid) {
                        return;
                      }

                      final success = existing == null
                          ? await controller.createMembership(
                              CreateTenantMembershipInput(
                                tenantId: tenant.id,
                                userId: userIdController.text.trim(),
                                roleInTenant: roleController.text.trim(),
                              ),
                            )
                          : await controller.updateMembership(
                              UpdateTenantMembershipInput(
                                tenantId: tenant.id,
                                membershipId: existing.id,
                                roleInTenant: roleController.text.trim(),
                                rowVersion: existing.rowVersion,
                              ),
                            );
                      snackBar.show(
                        navigator,
                        success
                            ? 'Membership saved.'
                            : 'Membership save failed.',
                      );
                      if (success && context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Text(existing == null ? 'Add Membership' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
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
