// coverage:ignore-file
import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/presentation/providers/audit_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _formDialogPanelWidth = 560;

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
        _buildToolbar(context, state, controller),
        const SizedBox(height: 8),
        _buildSetActionRow(context, state),
        if (state.isLoadingEvents || state.isLoadingTenants || state.isMutating)
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
        _AuditSummaryStrip(state: state),
        const SizedBox(height: 8),
        SizedBox(
          height: 320,
          child: AppFormPanel(
            margin: EdgeInsets.zero,
            child: _AuditEventTable(
              state: state,
              onSelectEvent: controller.selectEvent,
              onPlaceLegalHold: _showPlaceLegalHoldDialog,
              onReleaseLegalHold: _showReleaseLegalHoldDialog,
              onRedact: _showRedactDialog,
              onTombstone: _showTombstoneDialog,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _AuditPaginator(state: state),
        const SizedBox(height: 8),
        Expanded(
          child: AppFormPanel(
            margin: EdgeInsets.zero,
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
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 250,
          child: DropdownButtonFormField<AuditAdminScopeMode>(
            key: const Key('audit-management-scope-selector'),
            initialValue: state.scopeMode,
            isExpanded: true,
            decoration: appFormInputDecoration(labelText: 'Scope'),
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
            child: DropdownButtonFormField<String>(
              key: const Key('audit-management-tenant-selector'),
              initialValue: state.selectedTenantId,
              isExpanded: true,
              decoration: appFormInputDecoration(labelText: 'Tenant'),
              items: state.tenants
                  .map(
                    (tenant) => DropdownMenuItem<String>(
                      value: tenant.id,
                      child: Text(tenant.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: state.tenants.isEmpty
                  ? null
                  : (value) async {
                      if (value == null) {
                        return;
                      }

                      await controller.selectTenant(value);
                    },
            ),
          ),
        SizedBox(
          width: 320,
          child: TextFormField(
            key: const Key('audit-management-search-field'),
            initialValue: state.searchTerm,
            decoration: appFormInputDecoration(
              labelText: 'Search',
              hintText: 'Entity, operation, action, source',
              suffixIcon: const Icon(Icons.search),
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
          onPressed: () => controller.refresh(),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
    final phasesController = TextEditingController();
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
                TextFormField(
                  controller: phasesController,
                  decoration: appFormInputDecoration(
                    labelText: 'Phases (optional)',
                    hintText:
                        'seal_backlog,redact_due,tombstone_expired,purge_due',
                  ),
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

                final phases = _parsePhases(phasesController.text);
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
    required this.onSelectEvent,
    required this.onPlaceLegalHold,
    required this.onReleaseLegalHold,
    required this.onRedact,
    required this.onTombstone,
  });

  final AuditAdminState state;
  final ValueChanged<String> onSelectEvent;
  final ValueChanged<AuditEventEntity> onPlaceLegalHold;
  final ValueChanged<AuditEventEntity> onReleaseLegalHold;
  final ValueChanged<AuditEventEntity> onRedact;
  final ValueChanged<AuditEventEntity> onTombstone;

  @override
  Widget build(BuildContext context) {
    if (state.events.isEmpty) {
      return const Center(child: Text('No audit events found.'));
    }

    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: AppUiPalette.surfaceMuted,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppUiPalette.border),
          ),
          child: Row(
            children: [
              _headerCell('Occurred', flex: 2, textTheme: textTheme),
              _headerCell('Operation', flex: 2, textTheme: textTheme),
              _headerCell('Entity', flex: 2, textTheme: textTheme),
              _headerCell('Outcome', flex: 1, textTheme: textTheme),
              _headerCell('Tenant', flex: 2, textTheme: textTheme),
              _headerCell('Actions', flex: 3, textTheme: textTheme),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            itemCount: state.events.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final event = state.events[index];
              final selected = event.id == state.selectedEventId;

              return InkWell(
                key: Key('audit-event-row-${event.id}'),
                onTap: () => onSelectEvent(event.id),
                child: Container(
                  color: selected
                      ? AppUiPalette.surfaceStrong.withValues(alpha: 0.45)
                      : Colors.transparent,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Row(
                    children: [
                      _rowCell(_shortTimestamp(event.occurredAt), flex: 2),
                      _rowCell(
                        event.actionName == null || event.actionName!.isEmpty
                            ? event.operation
                            : '${event.operation}:${event.actionName}',
                        flex: 2,
                      ),
                      _rowCell('${event.entitySet}/${event.entity}', flex: 2),
                      _rowCell(event.outcome, flex: 1),
                      _rowCell(event.tenantId ?? 'global', flex: 2),
                      Expanded(
                        flex: 3,
                        child: Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: [
                            IconButton(
                              tooltip: 'Place legal hold',
                              onPressed: event.hasLegalHold
                                  ? null
                                  : () => onPlaceLegalHold(event),
                              icon: const Icon(Icons.gavel_outlined, size: 18),
                            ),
                            IconButton(
                              tooltip: 'Release legal hold',
                              onPressed: !event.hasLegalHold
                                  ? null
                                  : () => onReleaseLegalHold(event),
                              icon: const Icon(
                                Icons.lock_open_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Redact event',
                              onPressed: event.isRedacted
                                  ? null
                                  : () => onRedact(event),
                              icon: const Icon(
                                Icons.visibility_off_outlined,
                                size: 18,
                              ),
                            ),
                            IconButton(
                              tooltip: 'Tombstone event',
                              onPressed: event.isTombstoned
                                  ? null
                                  : () => onTombstone(event),
                              icon: const Icon(
                                Icons.delete_sweep_outlined,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _headerCell(
    String text, {
    required int flex,
    required TextTheme textTheme,
  }) {
    return Expanded(
      flex: flex,
      child: Text(
        text,
        style: textTheme.labelSmall?.copyWith(
          color: AppUiPalette.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _rowCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
    );
  }

  String _shortTimestamp(DateTime value) {
    final utc = value.toUtc();
    return utc.toIso8601String().replaceFirst('.000', '');
  }
}

class _AuditPaginator extends ConsumerWidget {
  const _AuditPaginator({required this.state});

  final AuditAdminState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(auditAdminControllerProvider.notifier);
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
            await controller.loadEvents();
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
                  await controller.loadEvents();
                },
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: !hasNext
              ? null
              : () async {
                  controller.setPage(state.page + 1);
                  await controller.loadEvents();
                },
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
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
      return const Center(
        child: Text('Select an audit event to inspect details.'),
      );
    }

    final selected = event!;
    return SingleChildScrollView(
      child: SelectionArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Event ${selected.id}',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            _DetailRow(label: 'Scope Key', value: selected.scopeKey),
            _DetailRow(
              label: 'Scope Seq',
              value: '${selected.scopeSeq ?? '-'}',
            ),
            _DetailRow(
              label: 'Prev Hash',
              value: selected.prevEntryHash ?? '-',
            ),
            _DetailRow(label: 'Entry Hash', value: selected.entryHash ?? '-'),
            _DetailRow(label: 'Hash Alg', value: selected.hashAlg),
            _DetailRow(label: 'Hash Key', value: selected.hashKeyId ?? '-'),
            _DetailRow(
              label: 'Before Hash',
              value: selected.beforeSnapshotHash ?? '-',
            ),
            _DetailRow(
              label: 'After Hash',
              value: selected.afterSnapshotHash ?? '-',
            ),
            _DetailRow(
              label: 'Sealed At',
              value: _formatDate(selected.sealedAt),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
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
            ),
            _DetailRow(
              label: 'Tombstone Reason',
              value: selected.tombstoneReason ?? '-',
            ),
            _DetailRow(
              label: 'Purge Due',
              value: _formatDate(selected.purgeDueAt),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
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

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 170,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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

List<String> _parsePhases(String raw) {
  final normalized = raw.trim();
  if (normalized.isEmpty) {
    return const <String>[];
  }

  return normalized
      .split(',')
      .map((phase) => phase.trim())
      .where((phase) => phase.isNotEmpty)
      .toList(growable: false);
}
