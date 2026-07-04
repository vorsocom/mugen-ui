// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/features/audit_admin/presentation/providers/audit_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _formDialogPanelWidth = 560;
const List<String> _auditLifecyclePhases = <String>[
  'seal_backlog',
  'redact_due',
  'tombstone_expired',
  'purge_due',
];

class AuditManagementPanel extends ConsumerStatefulWidget {
  const AuditManagementPanel({super.key}); // coverage:ignore-line

  @override
  ConsumerState<AuditManagementPanel> createState() =>
      _AuditManagementPanelState();
}

class _AuditManagementPanelState extends ConsumerState<AuditManagementPanel> {
  Timer? _searchDebounce;
  static const Duration _searchDebounceDuration = Duration(milliseconds: 300);

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() {
      ref.read(auditAdminControllerProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(auditAdminControllerProvider);
    final controller = ref.read(auditAdminControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AdminPageHeader(
          title: 'Audit Events',
          subtitle:
              'Inspect immutable audit trails, verify chain integrity, and manage retention actions.',
        ),
        _buildToolbar(context, state, controller),
        _buildSetActionRow(context, state),
        if (state.isLoadingEvents || state.isLoadingTenants || state.isMutating)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: LinearProgressIndicator(minHeight: 2),
          ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        _AuditSummaryStrip(state: state),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: AdminSurface(
            padding: EdgeInsets.zero,
            child: _AuditEventTable(
              state: state,
              controller: controller,
              onSelectEvent: controller.selectEvent,
              onPlaceLegalHold: _showPlaceLegalHoldDialog,
              onReleaseLegalHold: _showReleaseLegalHoldDialog,
              onRedact: _showRedactDialog,
              onTombstone: _showTombstoneDialog,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 2,
          child: AdminSurface(
            child: _AuditEventDetail(event: state.selectedEvent),
          ),
        ),
      ],
    );
  }

  Widget _buildToolbar(
    BuildContext context,
    AuditAdminState state,
    AuditAdminController controller,
  ) {
    return AdminToolbar(
      children: [
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<AuditAdminScopeMode>(
            key: const Key('audit-management-scope-selector'),
            initialValue: state.scopeMode,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Scope'),
            items: const [
              DropdownMenuItem(
                value: AuditAdminScopeMode.global,
                child: Text('Global'),
              ),
              DropdownMenuItem(
                value: AuditAdminScopeMode.tenant,
                child: Text('Tenant'),
              ),
            ],
            onChanged: (value) async {
              if (value == null) {
                return;
              }

              await controller.setScopeMode(value);
            },
          ),
        ),
        if (state.scopeMode == AuditAdminScopeMode.tenant)
          SizedBox(
            width: 320,
            child: AppSearchableSelectField<AuditTenantOptionEntity>(
              fieldKey: const Key('audit-management-tenant-selector'),
              optionKeyPrefix: 'audit-management-tenant-option',
              labelText: 'Tenant',
              hintText: 'Search tenants',
              options: state.tenants,
              selectedOptionKey: state.selectedTenantId,
              optionKey: (tenant) => tenant.id,
              optionTitle: (tenant) => tenant.label,
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
        SizedBox(
          width: 320,
          child: TextFormField(
            key: const Key('audit-management-search-field'),
            initialValue: state.searchTerm,
            decoration: const InputDecoration(
              hintText: 'Entity, operation, action, source',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(_searchDebounceDuration, () async {
                controller.setSearchTerm(value.trim());
                await controller.loadEvents();
              });
            },
          ),
        ),
        TextButton.icon(
          key: const Key('audit-management-refresh-button'),
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }

  Widget _buildSetActionRow(BuildContext context, AuditAdminState state) {
    final tenantMissing =
        state.scopeMode == AuditAdminScopeMode.tenant &&
        (state.selectedTenantId == null || state.selectedTenantId!.isEmpty);

    return AdminToolbar(
      children: [
        FilledButton.icon(
          key: const Key('audit-management-run-lifecycle-button'),
          onPressed: tenantMissing ? null : _showRunLifecycleDialog,
          icon: const Icon(Icons.playlist_play),
          label: const Text('Run Lifecycle'),
        ),
        OutlinedButton.icon(
          key: const Key('audit-management-verify-chain-button'),
          onPressed: tenantMissing ? null : _showVerifyChainDialog,
          icon: const Icon(Icons.verified_outlined),
          label: const Text('Verify Chain'),
        ),
        OutlinedButton.icon(
          key: const Key('audit-management-seal-backlog-button'),
          onPressed: tenantMissing ? null : _showSealBacklogDialog,
          icon: const Icon(Icons.lock_clock_outlined),
          label: const Text('Seal Backlog'),
        ),
      ],
    );
  }

  Future<void> _showPlaceLegalHoldDialog(AuditEventEntity event) async {
    final reasonController = TextEditingController();
    final untilController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    final controller = ref.read(auditAdminControllerProvider.notifier);

    await showDialog<void>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Place Legal Hold',
        formKey: formKey,
        fields: [
          TextFormField(
            controller: reasonController,
            decoration: appFormInputDecoration(labelText: 'Reason'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: untilController,
            decoration: appFormInputDecoration(
              labelText: 'Legal Hold Until (optional)',
              hintText: '2026-03-01T00:00:00Z',
            ),
            validator: _optionalDateValidator,
          ),
        ],
        submitLabel: 'Place Hold',
        onSubmit: () async {
          final valid = formKey.currentState?.validate() ?? false;
          if (!valid) {
            return;
          }

          final confirmed = await _confirmMutatingAction(
            message: 'Apply legal hold for this audit event?',
          );
          if (confirmed != true) {
            return;
          }

          final success = await controller.placeLegalHold(
            AuditPlaceLegalHoldInput(
              eventId: event.id,
              rowVersion: event.rowVersion,
              reason: reasonController.text.trim(),
              legalHoldUntil: _parseOptionalDate(untilController.text),
              scopeMode: _scopeMode(),
              tenantId: _selectedTenantId(),
            ),
          );

          _showActionResult(
            successMessage: 'Legal hold updated.',
            failureMessage: 'Legal hold update failed.',
            success: success,
          );

          if (success && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showReleaseLegalHoldDialog(AuditEventEntity event) async {
    await _showReasonOnlyActionDialog(
      title: 'Release Legal Hold',
      submitLabel: 'Release Hold',
      confirmation: 'Release legal hold for this audit event?',
      onSubmit: (reason) {
        return ref
            .read(auditAdminControllerProvider.notifier)
            .releaseLegalHold(
              AuditReleaseLegalHoldInput(
                eventId: event.id,
                rowVersion: event.rowVersion,
                reason: reason,
                scopeMode: _scopeMode(),
                tenantId: _selectedTenantId(),
              ),
            );
      },
      successMessage: 'Legal hold released.',
      failureMessage: 'Legal hold release failed.',
    );
  }

  Future<void> _showRedactDialog(AuditEventEntity event) async {
    await _showReasonOnlyActionDialog(
      title: 'Redact Event',
      submitLabel: 'Redact',
      confirmation: 'Redact this audit event snapshots?',
      onSubmit: (reason) {
        return ref
            .read(auditAdminControllerProvider.notifier)
            .redactEvent(
              AuditRedactInput(
                eventId: event.id,
                rowVersion: event.rowVersion,
                reason: reason,
                scopeMode: _scopeMode(),
                tenantId: _selectedTenantId(),
              ),
            );
      },
      successMessage: 'Audit event redacted.',
      failureMessage: 'Audit event redaction failed.',
    );
  }

  Future<void> _showTombstoneDialog(AuditEventEntity event) async {
    final reasonController = TextEditingController();
    final purgeDaysController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Tombstone Event',
        formKey: formKey,
        fields: [
          TextFormField(
            controller: reasonController,
            decoration: appFormInputDecoration(labelText: 'Reason'),
            validator: _requiredValidator,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: purgeDaysController,
            decoration: appFormInputDecoration(
              labelText: 'Purge After Days (optional)',
            ),
            keyboardType: TextInputType.number,
            validator: _optionalNonNegativeIntValidator,
          ),
        ],
        submitLabel: 'Tombstone',
        onSubmit: () async {
          final valid = formKey.currentState?.validate() ?? false;
          if (!valid) {
            return;
          }

          final confirmed = await _confirmMutatingAction(
            message: 'Tombstone this audit event?',
          );
          if (confirmed != true) {
            return;
          }

          final success = await ref
              .read(auditAdminControllerProvider.notifier)
              .tombstoneEvent(
                AuditTombstoneInput(
                  eventId: event.id,
                  rowVersion: event.rowVersion,
                  reason: reasonController.text.trim(),
                  purgeAfterDays: _parseOptionalInt(purgeDaysController.text),
                  scopeMode: _scopeMode(),
                  tenantId: _selectedTenantId(),
                ),
              );

          _showActionResult(
            successMessage: 'Audit event tombstoned.',
            failureMessage: 'Audit event tombstone failed.',
            success: success,
          );

          if (success && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showRunLifecycleDialog() async {
    final batchSizeController = TextEditingController();
    final maxBatchesController = TextEditingController();
    final selectedPhases = <String>{};
    final nowOverrideController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var dryRun = true;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _ActionDialog(
              title: 'Run Lifecycle',
              formKey: formKey,
              fields: [
                SwitchListTile(
                  key: const Key('audit-run-lifecycle-dry-run-switch'),
                  contentPadding: EdgeInsets.zero,
                  value: dryRun,
                  title: const Text('Dry run'),
                  subtitle: const Text('Default is enabled for safety.'),
                  onChanged: (value) {
                    setStateDialog(() {
                      dryRun = value;
                    });
                  },
                ),
                if (!dryRun)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Warning: dry run is disabled. This will mutate audit records.',
                      key: const Key('audit-run-lifecycle-mutation-warning'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppUiPalette.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                TextFormField(
                  controller: batchSizeController,
                  decoration: appFormInputDecoration(
                    labelText: 'Batch Size (optional)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalPositiveIntValidator,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: maxBatchesController,
                  decoration: appFormInputDecoration(
                    labelText: 'Max Batches (optional)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalPositiveIntValidator,
                ),
                const SizedBox(height: 8),
                _AuditLifecyclePhaseSelector(
                  selectedPhases: selectedPhases,
                  onChanged: (phase, selected) {
                    setStateDialog(() {
                      if (selected) {
                        selectedPhases.add(phase);
                      } else {
                        selectedPhases.remove(phase);
                      }
                    });
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: nowOverrideController,
                  decoration: appFormInputDecoration(
                    labelText: 'Now Override (optional)',
                    hintText: '2026-03-01T00:00:00Z',
                  ),
                  validator: _optionalDateValidator,
                ),
              ],
              submitLabel: 'Run',
              onSubmit: () async {
                final valid = formKey.currentState?.validate() ?? false;
                if (!valid) {
                  return;
                }

                if (!dryRun) {
                  final guardrailWarning = await showAppConfirmationDialog(
                    context: dialogContext,
                    title: 'Mutation Warning',
                    message:
                        'Dry run is disabled. This lifecycle run will mutate records.',
                    confirmLabel: 'Proceed',
                    confirmButtonKey: const Key(
                      'audit-run-lifecycle-mutation-warning-confirm',
                    ),
                  );
                  if (guardrailWarning != true) {
                    return;
                  }
                }

                final confirmed = await _confirmMutatingAction(
                  message: dryRun
                      ? 'Run lifecycle in dry-run mode?'
                      : 'Run lifecycle with mutations enabled?',
                );
                if (confirmed != true) {
                  return;
                }

                final phases = selectedPhases.toList(growable: false);
                final success = await ref
                    .read(auditAdminControllerProvider.notifier)
                    .runLifecycle(
                      AuditRunLifecycleInput(
                        scopeMode: _scopeMode(),
                        tenantId: _selectedTenantId(),
                        batchSize: _parseOptionalInt(batchSizeController.text),
                        maxBatches: _parseOptionalInt(
                          maxBatchesController.text,
                        ),
                        dryRun: dryRun,
                        nowOverride: _parseOptionalDate(
                          nowOverrideController.text,
                        ),
                        phases: phases.isEmpty ? null : phases,
                      ),
                    );

                _showActionResult(
                  successMessage: 'Lifecycle run completed.',
                  failureMessage: 'Lifecycle run failed.',
                  success: success,
                );

                if (success && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showVerifyChainDialog() async {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final maxRowsController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var requireClean = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return _ActionDialog(
              title: 'Verify Chain',
              formKey: formKey,
              fields: [
                TextFormField(
                  controller: fromController,
                  decoration: appFormInputDecoration(
                    labelText: 'From Occurred At (optional)',
                    hintText: '2026-03-01T00:00:00Z',
                  ),
                  validator: _optionalDateValidator,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: toController,
                  decoration: appFormInputDecoration(
                    labelText: 'To Occurred At (optional)',
                    hintText: '2026-03-10T00:00:00Z',
                  ),
                  validator: _optionalDateValidator,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: maxRowsController,
                  decoration: appFormInputDecoration(
                    labelText: 'Max Rows (optional)',
                  ),
                  keyboardType: TextInputType.number,
                  validator: _optionalPositiveIntValidator,
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: requireClean,
                  title: const Text('Require clean chain'),
                  subtitle: const Text(
                    'When enabled, mismatches return a conflict.',
                  ),
                  onChanged: (value) {
                    setStateDialog(() {
                      requireClean = value;
                    });
                  },
                ),
              ],
              submitLabel: 'Verify',
              onSubmit: () async {
                final valid = formKey.currentState?.validate() ?? false;
                if (!valid) {
                  return;
                }

                final success = await ref
                    .read(auditAdminControllerProvider.notifier)
                    .verifyChain(
                      AuditVerifyChainInput(
                        scopeMode: _scopeMode(),
                        tenantId: _selectedTenantId(),
                        fromOccurredAt: _parseOptionalDate(fromController.text),
                        toOccurredAt: _parseOptionalDate(toController.text),
                        maxRows: _parseOptionalInt(maxRowsController.text),
                        requireClean: requireClean,
                      ),
                    );

                _showActionResult(
                  successMessage: 'Chain verification completed.',
                  failureMessage: 'Chain verification failed.',
                  success: success,
                );

                if (success && dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showSealBacklogDialog() async {
    final batchSizeController = TextEditingController();
    final maxBatchesController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => _ActionDialog(
        title: 'Seal Backlog',
        formKey: formKey,
        fields: [
          TextFormField(
            controller: batchSizeController,
            decoration: appFormInputDecoration(labelText: 'Batch Size'),
            keyboardType: TextInputType.number,
            validator: _optionalPositiveIntValidator,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: maxBatchesController,
            decoration: appFormInputDecoration(labelText: 'Max Batches'),
            keyboardType: TextInputType.number,
            validator: _optionalPositiveIntValidator,
          ),
        ],
        submitLabel: 'Seal',
        onSubmit: () async {
          final valid = formKey.currentState?.validate() ?? false;
          if (!valid) {
            return;
          }

          final confirmed = await _confirmMutatingAction(
            message: 'Seal currently unsealed audit rows?',
          );
          if (confirmed != true) {
            return;
          }

          final success = await ref
              .read(auditAdminControllerProvider.notifier)
              .sealBacklog(
                AuditSealBacklogInput(
                  scopeMode: _scopeMode(),
                  tenantId: _selectedTenantId(),
                  batchSize: _parseOptionalInt(batchSizeController.text),
                  maxBatches: _parseOptionalInt(maxBatchesController.text),
                ),
              );

          _showActionResult(
            successMessage: 'Seal backlog completed.',
            failureMessage: 'Seal backlog failed.',
            success: success,
          );

          if (success && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<void> _showReasonOnlyActionDialog({
    required String title,
    required String submitLabel,
    required String confirmation,
    required Future<bool> Function(String reason) onSubmit,
    required String successMessage,
    required String failureMessage,
  }) async {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (_) => _ActionDialog(
        title: title,
        formKey: formKey,
        fields: [
          TextFormField(
            controller: reasonController,
            decoration: appFormInputDecoration(labelText: 'Reason'),
            validator: _requiredValidator,
          ),
        ],
        submitLabel: submitLabel,
        onSubmit: () async {
          final valid = formKey.currentState?.validate() ?? false;
          if (!valid) {
            return;
          }

          final confirmed = await _confirmMutatingAction(message: confirmation);
          if (confirmed != true) {
            return;
          }

          final success = await onSubmit(reasonController.text.trim());
          _showActionResult(
            successMessage: successMessage,
            failureMessage: failureMessage,
            success: success,
          );

          if (success && mounted) {
            Navigator.of(context).pop();
          }
        },
      ),
    );
  }

  Future<bool?> _confirmMutatingAction({required String message}) {
    return showAppConfirmationDialog(
      context: context,
      title: 'Confirmation Required',
      message: message,
      confirmLabel: 'Continue',
    );
  }

  void _showActionResult({
    required String successMessage,
    required String failureMessage,
    required bool success,
  }) {
    final navigator = ref.read(appNavigatorProvider);
    final snackBar = ref.read(snackBarDispatcherProvider);
    snackBar.show(navigator, success ? successMessage : failureMessage);
  }

  AuditAdminScopeMode _scopeMode() {
    return ref.read(auditAdminControllerProvider).scopeMode;
  }

  String? _selectedTenantId() {
    return ref.read(auditAdminControllerProvider).selectedTenantId;
  }
}

class _AuditEventTable extends StatelessWidget {
  const _AuditEventTable({
    required this.state,
    required this.controller,
    required this.onSelectEvent,
    required this.onPlaceLegalHold,
    required this.onReleaseLegalHold,
    required this.onRedact,
    required this.onTombstone,
  });

  final AuditAdminState state;
  final AuditAdminController controller;
  final ValueChanged<String> onSelectEvent;
  final ValueChanged<AuditEventEntity> onPlaceLegalHold;
  final ValueChanged<AuditEventEntity> onReleaseLegalHold;
  final ValueChanged<AuditEventEntity> onRedact;
  final ValueChanged<AuditEventEntity> onTombstone;

  @override
  Widget build(BuildContext context) {
    return AdminDataGrid<AuditEventEntity>(
      rows: state.events,
      columns: [
        AdminGridColumn<AuditEventEntity>(
          key: 'occurred',
          label: 'Occurred',
          flex: 2,
          cell: (_, event) => AdminCellText(_shortTimestamp(event.occurredAt)),
        ),
        AdminGridColumn<AuditEventEntity>(
          key: 'operation',
          label: 'Operation',
          flex: 2,
          cell: (_, event) => AdminCellText(_operationLabel(event)),
        ),
        AdminGridColumn<AuditEventEntity>(
          key: 'entity',
          label: 'Entity',
          flex: 2,
          cell: (_, event) =>
              AdminCellText('${event.entitySet}/${event.entity}', maxLines: 2),
        ),
        AdminGridColumn<AuditEventEntity>(
          key: 'outcome',
          label: 'Outcome',
          width: 120,
          cell: (_, event) => AdminStatusChip(label: event.outcome),
        ),
        AdminGridColumn<AuditEventEntity>(
          key: 'tenant',
          label: 'Tenant',
          flex: 2,
          cell: (_, event) => AdminCellText(event.tenantId ?? 'global'),
        ),
        AdminGridColumn<AuditEventEntity>(
          key: 'state',
          label: 'State',
          flex: 2,
          cell: (_, event) => _AuditStateChips(event: event),
        ),
      ],
      actionsWidth: 192,
      actionsBuilder: (_, event) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AdminIconButton(
              icon: Icons.gavel_outlined,
              tooltip: 'Place legal hold',
              onPressed: event.hasLegalHold
                  ? null
                  : () => onPlaceLegalHold(event),
            ),
            AdminIconButton(
              icon: Icons.lock_open_outlined,
              tooltip: 'Release legal hold',
              onPressed: !event.hasLegalHold
                  ? null
                  : () => onReleaseLegalHold(event),
            ),
            AdminIconButton(
              icon: Icons.visibility_off_outlined,
              tooltip: 'Redact event',
              onPressed: event.isRedacted ? null : () => onRedact(event),
            ),
            AdminIconButton(
              icon: Icons.delete_sweep_outlined,
              tooltip: 'Tombstone event',
              destructive: true,
              onPressed: event.isTombstoned ? null : () => onTombstone(event),
            ),
          ],
        );
      },
      rowKey: (event) => 'audit-event-row-${event.id}',
      onRowSelected: (event) => onSelectEvent(event.id),
      isRowSelected: (event) => event.id == state.selectedEventId,
      isLoading:
          state.isLoadingEvents || state.isLoadingTenants || state.isMutating,
      hasActiveFilter: state.searchTerm.trim().isNotEmpty,
      emptyState: AdminEmptyStateData(
        title: 'No audit events yet.',
        message:
            'Audit events appear here after governed actions are recorded for the selected scope.',
        secondaryAction: TextButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      filteredEmptyState: const AdminEmptyStateData(
        title: 'No matching audit events.',
        message: 'Clear the search or adjust scope filters.',
      ),
      minWidth: 1120,
      footer: AdminGridFooter(
        state: AdminPaginationState(
          visibleCount: state.events.length,
          totalCount: state.total,
          page: state.page,
          pages: state.pages,
          pageSize: state.pageSize,
          pageSizes: const <int>[15, 25, 50],
          onPageSizeChanged: (value) async {
            controller.setRowsPerPage(value);
            await controller.loadEvents();
          },
          onFirstPage: state.page <= 1
              ? null
              : () async {
                  controller.setPage(1);
                  await controller.loadEvents();
                },
          onPreviousPage: state.page <= 1
              ? null
              : () async {
                  controller.setPage(state.page - 1);
                  await controller.loadEvents();
                },
          onNextPage: state.page >= state.pages
              ? null
              : () async {
                  controller.setPage(state.page + 1);
                  await controller.loadEvents();
                },
          onLastPage: state.page >= state.pages
              ? null
              : () async {
                  controller.setPage(state.pages);
                  await controller.loadEvents();
                },
        ),
      ),
    );
  }

  String _operationLabel(AuditEventEntity event) {
    if (event.actionName == null || event.actionName!.isEmpty) {
      return event.operation;
    }

    return '${event.operation}:${event.actionName}';
  }

  String _shortTimestamp(DateTime value) {
    final utc = value.toUtc();
    return utc.toIso8601String().replaceFirst('.000', '');
  }
}

class _AuditStateChips extends StatelessWidget {
  const _AuditStateChips({required this.event});

  final AuditEventEntity event;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      AdminStatusChip(
        label: event.sealedAt == null ? 'unsealed' : 'sealed',
        kind: event.sealedAt == null
            ? AdminStatusKind.warning
            : AdminStatusKind.success,
      ),
      if (event.hasLegalHold)
        AdminStatusChip(label: 'legal hold', kind: AdminStatusKind.warning),
      if (event.isRedacted)
        AdminStatusChip(label: 'redacted', kind: AdminStatusKind.danger),
      if (event.isTombstoned)
        AdminStatusChip(label: 'tombstoned', kind: AdminStatusKind.danger),
    ];

    return Wrap(spacing: 4, runSpacing: 4, children: chips);
  }
}

class _AuditSummaryStrip extends StatelessWidget {
  const _AuditSummaryStrip({required this.state});

  final AuditAdminState state;

  @override
  Widget build(BuildContext context) {
    final summaryWidgets = <Widget>[];

    final lifecycle = state.latestLifecycleSummary;
    if (lifecycle != null) {
      summaryWidgets.add(
        _SummaryChip(
          label:
              'Lifecycle: dryRun=${lifecycle.dryRun} total=${lifecycle.totalProcessed}',
        ),
      );
    }

    final chain = state.latestChainSummary;
    if (chain != null) {
      summaryWidgets.add(
        _SummaryChip(
          label:
              'Verify: valid=${chain.isValid} mismatches=${chain.mismatchCount}',
        ),
      );
    }

    final seal = state.latestSealSummary;
    if (seal != null) {
      summaryWidgets.add(
        _SummaryChip(
          label:
              'Seal: rowsSealed=${seal.rowsSealed} remaining=${seal.remainingCount}',
        ),
      );
    }

    if (summaryWidgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(spacing: 8, runSpacing: 8, children: summaryWidgets);
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppUiPalette.border),
        color: AppUiPalette.surfaceMuted,
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

class _AuditEventDetail extends StatelessWidget {
  const _AuditEventDetail({required this.event});

  final AuditEventEntity? event;

  @override
  Widget build(BuildContext context) {
    if (event == null) {
      return const AdminEmptyState(
        data: AdminEmptyStateData(
          title: 'No audit event selected.',
          message:
              'Select an audit event to inspect integrity, retention, and payload details.',
        ),
      );
    }

    final selected = event!;
    return SingleChildScrollView(
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Event ${selected.id}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                AdminStatusChip(label: selected.outcome),
                if (selected.sealedAt != null)
                  AdminStatusChip(
                    label: 'sealed',
                    kind: AdminStatusKind.success,
                  ),
                if (selected.hasLegalHold)
                  AdminStatusChip(
                    label: 'legal hold',
                    kind: AdminStatusKind.warning,
                  ),
                if (selected.isRedacted)
                  AdminStatusChip(
                    label: 'redacted',
                    kind: AdminStatusKind.danger,
                  ),
                if (selected.isTombstoned)
                  AdminStatusChip(
                    label: 'tombstoned',
                    kind: AdminStatusKind.danger,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _DetailGrid(
              children: [
                _DetailRow(
                  label: 'Event ID',
                  value: selected.id,
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Scope Key',
                  value: selected.scopeKey,
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Scope Seq',
                  value: '${selected.scopeSeq ?? '-'}',
                ),
                _DetailRow(
                  label: 'Tenant',
                  value: selected.tenantId ?? 'global',
                ),
                _DetailRow(label: 'Actor', value: selected.actorId ?? '-'),
                _DetailRow(
                  label: 'Entity ID',
                  value: selected.entityId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Request ID',
                  value: selected.requestId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Correlation ID',
                  value: selected.correlationId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Source Plugin',
                  value: selected.sourcePlugin,
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DetailGrid(
              children: [
                _DetailRow(
                  label: 'Prev Hash',
                  value: selected.prevEntryHash ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Entry Hash',
                  value: selected.entryHash ?? '-',
                  copyable: true,
                ),
                _DetailRow(label: 'Hash Alg', value: selected.hashAlg),
                _DetailRow(
                  label: 'Hash Key',
                  value: selected.hashKeyId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Before Hash',
                  value: selected.beforeSnapshotHash ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'After Hash',
                  value: selected.afterSnapshotHash ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Sealed At',
                  value: _formatDate(selected.sealedAt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _DetailGrid(
              children: [
                _DetailRow(
                  label: 'Retention Until',
                  value: _formatDate(selected.retentionUntil),
                ),
                _DetailRow(
                  label: 'Redaction Due',
                  value: _formatDate(selected.redactionDueAt),
                ),
                _DetailRow(
                  label: 'Redacted At',
                  value: _formatDate(selected.redactedAt),
                ),
                _DetailRow(
                  label: 'Redaction Reason',
                  value: selected.redactionReason ?? '-',
                ),
                _DetailRow(
                  label: 'Legal Hold At',
                  value: _formatDate(selected.legalHoldAt),
                ),
                _DetailRow(
                  label: 'Legal Hold Until',
                  value: _formatDate(selected.legalHoldUntil),
                ),
                _DetailRow(
                  label: 'Legal Hold By',
                  value: selected.legalHoldByUserId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Legal Hold Reason',
                  value: selected.legalHoldReason ?? '-',
                ),
                _DetailRow(
                  label: 'Hold Released At',
                  value: _formatDate(selected.legalHoldReleasedAt),
                ),
                _DetailRow(
                  label: 'Hold Released By',
                  value: selected.legalHoldReleasedByUserId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Hold Release Reason',
                  value: selected.legalHoldReleaseReason ?? '-',
                ),
                _DetailRow(
                  label: 'Tombstoned At',
                  value: _formatDate(selected.tombstonedAt),
                ),
                _DetailRow(
                  label: 'Tombstoned By',
                  value: selected.tombstonedByUserId ?? '-',
                  copyable: true,
                ),
                _DetailRow(
                  label: 'Tombstone Reason',
                  value: selected.tombstoneReason ?? '-',
                ),
                _DetailRow(
                  label: 'Purge Due',
                  value: _formatDate(selected.purgeDueAt),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _JsonBlock(
              title: 'Before Snapshot',
              value: selected.beforeSnapshot,
            ),
            const SizedBox(height: 8),
            _JsonBlock(title: 'After Snapshot', value: selected.afterSnapshot),
            const SizedBox(height: 8),
            _JsonBlock(title: 'Meta', value: selected.meta),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime? value) {
    if (value == null) {
      return '-';
    }

    return value.toUtc().toIso8601String();
  }
}

class _DetailGrid extends StatelessWidget {
  const _DetailGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      children: [
        for (final child in children) SizedBox(width: 360, child: child),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) {
    final canCopy = copyable && value.trim().isNotEmpty && value != '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (copyable)
              AdminIconButton(
                icon: Icons.copy,
                tooltip: 'Copy $label',
                onPressed: canCopy
                    ? () => Clipboard.setData(ClipboardData(text: value))
                    : null,
              ),
          ],
        ),
        Tooltip(
          message: value,
          child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}

class _JsonBlock extends StatelessWidget {
  const _JsonBlock({required this.title, required this.value});

  final String title;
  final Map<String, dynamic>? value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: AppUiPalette.surfaceMuted,
            border: Border.all(color: AppUiPalette.border),
          ),
          child: Text(
            value == null
                ? '-'
                : const JsonEncoder.withIndent('  ').convert(value),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _AuditLifecyclePhaseSelector extends StatelessWidget {
  const _AuditLifecyclePhaseSelector({
    required this.selectedPhases,
    required this.onChanged,
  });

  final Set<String> selectedPhases;
  final void Function(String phase, bool selected) onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppUiPalette.border),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Phases (optional)',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          for (final phase in _auditLifecyclePhases)
            CheckboxListTile(
              key: Key('audit-run-lifecycle-phase-$phase'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              value: selectedPhases.contains(phase),
              title: Text(phase),
              onChanged: (value) => onChanged(phase, value ?? false),
            ),
        ],
      ),
    );
  }
}

class _ActionDialog extends StatelessWidget {
  const _ActionDialog({
    required this.title,
    required this.formKey,
    required this.fields,
    required this.submitLabel,
    required this.onSubmit,
  });

  final String title;
  final GlobalKey<FormState> formKey;
  final List<Widget> fields;
  final String submitLabel;
  final Future<void> Function() onSubmit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: SizedBox(
        width: _formDialogPanelWidth,
        child: AppFormPanel(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...fields,
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(onPressed: onSubmit, child: Text(submitLabel)),
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

String? _requiredValidator(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Field cannot be empty.';
  }

  return null;
}

String? _optionalDateValidator(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  if (DateTime.tryParse(raw) == null) {
    return 'Invalid date/time format.';
  }

  return null;
}

String? _optionalNonNegativeIntValidator(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  final parsed = int.tryParse(raw);
  if (parsed == null || parsed < 0) {
    return 'Enter a non-negative integer.';
  }

  return null;
}

String? _optionalPositiveIntValidator(String? value) {
  final raw = value?.trim() ?? '';
  if (raw.isEmpty) {
    return null;
  }

  final parsed = int.tryParse(raw);
  if (parsed == null || parsed <= 0) {
    return 'Enter a positive integer.';
  }

  return null;
}

DateTime? _parseOptionalDate(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return DateTime.tryParse(trimmed)?.toUtc();
}

int? _parseOptionalInt(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return int.tryParse(trimmed);
}
