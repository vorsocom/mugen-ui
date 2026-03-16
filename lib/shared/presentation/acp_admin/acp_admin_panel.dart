// coverage:ignore-file

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_json_codec.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _acpAdminTableMinWidth = 1120;
const Duration _acpAdminSearchDebounce = Duration(milliseconds: 300);

class AcpAdminPanel<T extends AcpAdminController>
    extends ConsumerStatefulWidget {
  const AcpAdminPanel({
    required this.controllerProvider,
    super.key,
    this.description,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final String? description;

  @override
  ConsumerState<AcpAdminPanel<T>> createState() => _AcpAdminPanelState<T>();
}

class _AcpAdminPanelState<T extends AcpAdminController>
    extends ConsumerState<AcpAdminPanel<T>> {
  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() async {
      await ref.read(widget.controllerProvider.notifier).loadInitialData();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.controllerProvider);
    final controller = ref.read(widget.controllerProvider.notifier);
    final descriptor = controller.activeDescriptor;
    final resourceState = state.activeResourceState;
    final showTenantSelector =
        descriptor.scopeMode == AcpScopeMode.required ||
        (descriptor.scopeMode == AcpScopeMode.optional &&
            resourceState.optionalScopeSelection ==
                AcpOptionalScopeSelection.tenant);
    final tenantMissing =
        showTenantSelector &&
        (state.selectedTenantId == null || state.selectedTenantId!.isEmpty);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFormPanel(
          margin: EdgeInsets.zero,
          child: _ResourceSelector(
            descriptors: controller.descriptors,
            activeResourceKey: state.activeResourceKey,
            onSelect: controller.selectResource,
          ),
        ),
        if (widget.description != null && widget.description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              widget.description!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
          ),
        if (descriptor.description != null &&
            descriptor.description!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              descriptor.description!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppUiPalette.textSecondary,
              ),
            ),
          ),
        const SizedBox(height: 8),
        _ToolbarRow<T>(
          controllerProvider: widget.controllerProvider,
          descriptor: descriptor,
          resourceState: resourceState,
        ),
        const SizedBox(height: 8),
        _ActionRow<T>(
          controllerProvider: widget.controllerProvider,
          descriptor: descriptor,
          tenantMissing: tenantMissing,
        ),
        if (state.isLoadingTenants ||
            resourceState.isLoading ||
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
        Expanded(
          child: AppFormPanel(
            margin: EdgeInsets.zero,
            child: _ResourceTable<T>(
              controllerProvider: widget.controllerProvider,
              descriptor: descriptor,
              resourceState: resourceState,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _ResourcePaginator<T>(
          controllerProvider: widget.controllerProvider,
          descriptor: descriptor,
          resourceState: resourceState,
        ),
      ],
    );
  }
}

class _ResourceSelector extends StatelessWidget {
  const _ResourceSelector({
    required this.descriptors,
    required this.activeResourceKey,
    required this.onSelect,
  });

  final List<AcpResourceDescriptor> descriptors;
  final String activeResourceKey;
  final Future<void> Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: descriptors
            .map(
              (descriptor) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  key: Key('acp-admin-tab-${descriptor.key}'),
                  label: Text(descriptor.title),
                  selected: descriptor.key == activeResourceKey,
                  onSelected: descriptor.key == activeResourceKey
                      ? null
                      : (_) => onSelect(descriptor.key),
                ),
              ),
            )
            .toList(growable: false),
      ),
    );
  }
}

class _ToolbarRow<T extends AcpAdminController> extends ConsumerStatefulWidget {
  const _ToolbarRow({
    required this.controllerProvider,
    required this.descriptor,
    required this.resourceState,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpResourceState resourceState;

  @override
  ConsumerState<_ToolbarRow<T>> createState() => _ToolbarRowState<T>();
}

class _ToolbarRowState<T extends AcpAdminController>
    extends ConsumerState<_ToolbarRow<T>> {
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controllerProvider = widget.controllerProvider;
    final descriptor = widget.descriptor;
    final resourceState = widget.resourceState;
    final state = ref.watch(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final showTenantSelector =
        descriptor.scopeMode == AcpScopeMode.required ||
        (descriptor.scopeMode == AcpScopeMode.optional &&
            resourceState.optionalScopeSelection ==
                AcpOptionalScopeSelection.tenant);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (descriptor.scopeMode == AcpScopeMode.optional)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<AcpOptionalScopeSelection>(
              key: const Key('acp-admin-scope-selector'),
              initialValue: resourceState.optionalScopeSelection,
              isExpanded: true,
              decoration: appFormInputDecoration(labelText: 'Scope'),
              items: const [
                DropdownMenuItem(
                  value: AcpOptionalScopeSelection.global,
                  child: Text('Global'),
                ),
                DropdownMenuItem(
                  value: AcpOptionalScopeSelection.tenant,
                  child: Text('Tenant'),
                ),
              ],
              onChanged: (value) async {
                if (value == null) {
                  return;
                }
                await controller.setOptionalScopeSelection(value);
              },
            ),
          ),
        if (showTenantSelector)
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              key: const Key('acp-admin-tenant-selector'),
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
        if (descriptor.searchFields.isNotEmpty)
          SizedBox(
            width: 320,
            child: TextFormField(
              key: ValueKey<String>('acp-admin-search-${descriptor.key}'),
              initialValue: resourceState.searchTerm,
              decoration: appFormInputDecoration(
                labelText: 'Search',
                hintText: 'Filter by key fields',
                suffixIcon: const Icon(Icons.search),
              ),
              onChanged: (value) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(_acpAdminSearchDebounce, () async {
                  controller.setSearchTerm(value.trim());
                  await controller.loadActiveResource();
                });
              },
            ),
          ),
        TextButton.icon(
          key: const Key('acp-admin-refresh-button'),
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ],
    );
  }
}

class _ActionRow<T extends AcpAdminController> extends ConsumerWidget {
  const _ActionRow({
    required this.controllerProvider,
    required this.descriptor,
    required this.tenantMissing,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final bool tenantMissing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!descriptor.allowCreate && descriptor.collectionActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (descriptor.allowCreate)
          FilledButton.icon(
            key: const Key('acp-admin-create-button'),
            onPressed: tenantMissing
                ? null
                : () => _showCreateDialog(
                    context: context,
                    ref: ref,
                    controllerProvider: controllerProvider,
                    descriptor: descriptor,
                  ),
            icon: const Icon(Icons.add),
            label: const Text('New Row'),
          ),
        for (final action in descriptor.collectionActions)
          OutlinedButton.icon(
            key: Key('acp-admin-collection-action-${action.name}'),
            onPressed: tenantMissing
                ? null
                : () => _runCollectionAction(
                    context: context,
                    ref: ref,
                    controllerProvider: controllerProvider,
                    descriptor: descriptor,
                    action: action,
                  ),
            icon: Icon(action.icon ?? Icons.play_circle_outline),
            label: Text(action.label),
          ),
      ],
    );
  }
}

class _ResourceTable<T extends AcpAdminController> extends ConsumerWidget {
  const _ResourceTable({
    required this.controllerProvider,
    required this.descriptor,
    required this.resourceState,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpResourceState resourceState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!resourceState.isLoading && resourceState.rows.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            descriptor.emptyMessage,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppUiPalette.textSecondary),
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _acpAdminTableMinWidth;
        final tableWidth = math.max(availableWidth, _acpAdminTableMinWidth);

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: SingleChildScrollView(
              child: DataTable(
                headingRowColor: const WidgetStatePropertyAll<Color?>(
                  AppUiPalette.surfaceMuted,
                ),
                columns: [
                  for (final column in descriptor.columns)
                    DataColumn(label: Text(column.label)),
                  const DataColumn(label: Text('Actions')),
                ],
                rows: resourceState.rows
                    .map(
                      (row) => DataRow(
                        cells: [
                          for (final column in descriptor.columns)
                            DataCell(
                              _TableCellText(
                                value: _formatCellValue(row[column.key]),
                              ),
                            ),
                          DataCell(
                            _RowActions<T>(
                              controllerProvider: controllerProvider,
                              descriptor: descriptor,
                              row: row,
                            ),
                          ),
                        ],
                      ),
                    )
                    .toList(growable: false),
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatCellValue(Object? value) {
    if (value == null) {
      return '';
    }
    if (value is bool) {
      return value ? 'Yes' : 'No';
    }
    if (value is List || value is Map) {
      return AcpJsonCodec.prettyPrint(value);
    }
    return value.toString();
  }
}

class _TableCellText extends StatelessWidget {
  const _TableCellText({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final trimmed = value.trim();
    final display = trimmed.length <= 72
        ? trimmed
        : '${trimmed.substring(0, 69)}...';

    return Tooltip(
      message: trimmed,
      child: SizedBox(
        width: 180,
        child: Text(display, overflow: TextOverflow.ellipsis, maxLines: 2),
      ),
    );
  }
}

class _RowActions<T extends AcpAdminController> extends ConsumerWidget {
  const _RowActions({
    required this.controllerProvider,
    required this.descriptor,
    required this.row,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpRow row;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowId = row.id;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        IconButton(
          tooltip: 'View row',
          icon: const Icon(Icons.visibility_outlined),
          onPressed: () =>
              _showRowDetailDialog(context, descriptor: descriptor, row: row),
        ),
        if (descriptor.allowUpdate && rowId != null)
          IconButton(
            tooltip: 'Edit row',
            icon: const Icon(Icons.edit_outlined),
            onPressed: () => _showUpdateDialog(
              context: context,
              ref: ref,
              controllerProvider: controllerProvider,
              descriptor: descriptor,
              row: row,
            ),
          ),
        if (descriptor.allowDelete && rowId != null)
          IconButton(
            tooltip: 'Delete row',
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _deleteRow(
              context: context,
              ref: ref,
              controllerProvider: controllerProvider,
              descriptor: descriptor,
              row: row,
            ),
          ),
        if (descriptor.allowRestore && rowId != null)
          IconButton(
            tooltip: 'Restore row',
            icon: const Icon(Icons.restore),
            onPressed: () => _restoreRow(
              context: context,
              ref: ref,
              controllerProvider: controllerProvider,
              descriptor: descriptor,
              row: row,
            ),
          ),
        if (descriptor.entityActions.isNotEmpty && rowId != null)
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: const Icon(Icons.more_horiz),
            onSelected: (actionName) {
              final action = descriptor.entityActions.firstWhere(
                (candidate) => candidate.name == actionName,
              );
              _runEntityAction(
                context: context,
                ref: ref,
                controllerProvider: controllerProvider,
                descriptor: descriptor,
                action: action,
                row: row,
              );
            },
            itemBuilder: (context) {
              return descriptor.entityActions
                  .map(
                    (action) => PopupMenuItem<String>(
                      value: action.name,
                      child: Text(action.label),
                    ),
                  )
                  .toList(growable: false);
            },
          ),
      ],
    );
  }
}

class _ResourcePaginator<T extends AcpAdminController> extends ConsumerWidget {
  const _ResourcePaginator({
    required this.controllerProvider,
    required this.descriptor,
    required this.resourceState,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpResourceState resourceState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(controllerProvider.notifier);

    return Row(
      children: [
        Text(
          '${resourceState.total} rows',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: AppUiPalette.textSecondary),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 140,
          child: DropdownButtonFormField<int>(
            key: const Key('acp-admin-page-size-selector'),
            initialValue: resourceState.pageSize,
            isExpanded: true,
            decoration: appFormInputDecoration(labelText: 'Rows'),
            items: const [10, 15, 25, 50]
                .map(
                  (value) => DropdownMenuItem<int>(
                    value: value,
                    child: Text('$value / page'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) async {
              if (value == null) {
                return;
              }
              await controller.setRowsPerPage(value);
            },
          ),
        ),
        const Spacer(),
        Text(
          'Page ${resourceState.page} of ${resourceState.pages}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 8),
        IconButton(
          tooltip: 'Previous page',
          onPressed: resourceState.page <= 1
              ? null
              : () => controller.setPage(resourceState.page - 1),
          icon: const Icon(Icons.chevron_left),
        ),
        IconButton(
          tooltip: 'Next page',
          onPressed: resourceState.page >= resourceState.pages
              ? null
              : () => controller.setPage(resourceState.page + 1),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

Future<void> _showCreateDialog<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
}) async {
  final payload = await _showDynamicFormDialog(
    context: context,
    title: 'Create ${descriptor.title}',
    submitLabel: 'Create',
    fields: descriptor.createFields,
  );
  if (payload == null) {
    return;
  }

  final result = await ref.read(controllerProvider.notifier).createRow(payload);
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: 'Created successfully.',
  );
}

Future<void> _showUpdateDialog<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
  required AcpRow row,
}) async {
  final rowId = row.id;
  if (rowId == null) {
    return;
  }

  final payload = await _showDynamicFormDialog(
    context: context,
    title: 'Update ${descriptor.title}',
    submitLabel: 'Save',
    fields: descriptor.updateFields,
    initialValues: row,
  );
  if (payload == null) {
    return;
  }

  final result = await ref
      .read(controllerProvider.notifier)
      .updateRow(rowId: rowId, values: payload, rowVersion: row.rowVersion);
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: 'Updated successfully.',
  );
}

Future<void> _deleteRow<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
  required AcpRow row,
}) async {
  final rowId = row.id;
  if (rowId == null) {
    return;
  }

  final confirmed = await showAppConfirmationDialog(
    context: context,
    title: 'Delete row',
    message: 'Delete this ${descriptor.title.toLowerCase()} row?',
    confirmLabel: 'Delete',
    icon: Icons.delete_outline,
  );
  if (confirmed != true) {
    return;
  }

  final result = await ref
      .read(controllerProvider.notifier)
      .deleteRow(rowId: rowId, rowVersion: row.rowVersion);
  if (!context.mounted) {
    return;
  }
  await _handleVoidMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: 'Deleted successfully.',
  );
}

Future<void> _restoreRow<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
  required AcpRow row,
}) async {
  final rowId = row.id;
  if (rowId == null) {
    return;
  }

  final confirmed = await showAppConfirmationDialog(
    context: context,
    title: 'Restore row',
    message: 'Restore this ${descriptor.title.toLowerCase()} row?',
    confirmLabel: 'Restore',
    icon: Icons.restore,
  );
  if (confirmed != true) {
    return;
  }

  final result = await ref
      .read(controllerProvider.notifier)
      .restoreRow(rowId: rowId, rowVersion: row.rowVersion);
  if (!context.mounted) {
    return;
  }
  await _handleVoidMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: 'Restored successfully.',
  );
}

Future<void> _runCollectionAction<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
  required AcpActionDescriptor action,
}) async {
  Map<String, dynamic>? payload = const <String, dynamic>{};
  if (action.fields.isNotEmpty) {
    payload = await _showDynamicFormDialog(
      context: context,
      title: action.label,
      submitLabel: action.label,
      fields: action.fields,
    );
  } else if (action.confirmMessage != null) {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: action.confirmMessage!,
      confirmLabel: action.label,
      icon: action.icon ?? Icons.play_circle_outline,
    );
    if (confirmed != true) {
      return;
    }
  }

  if (payload == null) {
    return;
  }

  if (action.fields.isNotEmpty && action.confirmMessage != null) {
    if (!context.mounted) {
      return;
    }
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: action.confirmMessage!,
      confirmLabel: action.label,
      icon: action.icon ?? Icons.play_circle_outline,
    );
    if (confirmed != true) {
      return;
    }
  }

  final result = await ref
      .read(controllerProvider.notifier)
      .runCollectionAction(action: action, values: payload);
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: action.successMessage ?? 'Action completed.',
    showResult: true,
  );
}

Future<void> _runEntityAction<T extends AcpAdminController>({
  required BuildContext context,
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  required AcpResourceDescriptor descriptor,
  required AcpActionDescriptor action,
  required AcpRow row,
}) async {
  final rowId = row.id;
  if (rowId == null) {
    return;
  }

  Map<String, dynamic>? payload = const <String, dynamic>{};
  if (action.fields.isNotEmpty) {
    payload = await _showDynamicFormDialog(
      context: context,
      title: action.label,
      submitLabel: action.label,
      fields: action.fields,
      initialValues: row,
    );
  } else if (action.confirmMessage != null) {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: action.confirmMessage!,
      confirmLabel: action.label,
      icon: action.icon ?? Icons.play_circle_outline,
    );
    if (confirmed != true) {
      return;
    }
  }

  if (payload == null) {
    return;
  }

  if (action.fields.isNotEmpty && action.confirmMessage != null) {
    if (!context.mounted) {
      return;
    }
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: action.confirmMessage!,
      confirmLabel: action.label,
      icon: action.icon ?? Icons.play_circle_outline,
    );
    if (confirmed != true) {
      return;
    }
  }

  final result = await ref
      .read(controllerProvider.notifier)
      .runEntityAction(
        action: action,
        rowId: rowId,
        values: payload,
        rowVersion: action.includeRowVersion ? row.rowVersion : null,
      );
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: result,
    successMessage: action.successMessage ?? 'Action completed.',
    showResult: true,
  );
}

Future<Map<String, dynamic>?> _showDynamicFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  required List<AcpFieldDescriptor> fields,
  Map<String, dynamic> initialValues = const <String, dynamic>{},
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppUiPalette.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppUiPalette.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
          child: _AcpDynamicFormDialog(
            title: title,
            submitLabel: submitLabel,
            fields: fields,
            initialValues: initialValues,
          ),
        ),
      );
    },
  );
}

Future<void> _showRowDetailDialog(
  BuildContext context, {
  required AcpResourceDescriptor descriptor,
  required AcpRow row,
}) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: AppUiPalette.surfaceMuted,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppUiPalette.border),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
          child: AppFormPanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  descriptor.title,
                  style: Theme.of(dialogContext).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: SelectableText(AcpJsonCodec.prettyPrint(row)),
                  ),
                ),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _handleObjectMutationResult({
  required BuildContext context,
  required WidgetRef ref,
  required Result<Object?> result,
  required String successMessage,
  bool showResult = false,
}) async {
  if (result.isFailure) {
    return;
  }

  ref
      .read(snackBarDispatcherProvider)
      .show(ref.read(appNavigatorProvider), successMessage);

  if (showResult && result.data != null) {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(24),
          backgroundColor: AppUiPalette.surfaceMuted,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppUiPalette.border),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760, maxHeight: 760),
            child: AppFormPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Action Result',
                    style: Theme.of(dialogContext).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: SelectableText(
                        AcpJsonCodec.prettyPrint(result.data),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Future<void> _handleVoidMutationResult({
  required BuildContext context,
  required WidgetRef ref,
  required Result<void> result,
  required String successMessage,
}) async {
  if (result.isFailure) {
    return;
  }

  ref
      .read(snackBarDispatcherProvider)
      .show(ref.read(appNavigatorProvider), successMessage);
}

class _AcpDynamicFormDialog extends StatefulWidget {
  const _AcpDynamicFormDialog({
    required this.title,
    required this.submitLabel,
    required this.fields,
    required this.initialValues,
  });

  final String title;
  final String submitLabel;
  final List<AcpFieldDescriptor> fields;
  final Map<String, dynamic> initialValues;

  @override
  State<_AcpDynamicFormDialog> createState() => _AcpDynamicFormDialogState();
}

class _AcpDynamicFormDialogState extends State<_AcpDynamicFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  late final Map<String, bool> _boolValues;

  @override
  void initState() {
    super.initState();
    _textControllers = <String, TextEditingController>{
      for (final field in widget.fields)
        if (field.kind != AcpFieldKind.boolean)
          field.key: TextEditingController(
            text: _initialTextValue(
              field,
              widget.initialValues.containsKey(field.key)
                  ? widget.initialValues[field.key]
                  : field.initialValue,
            ),
          ),
    };
    _boolValues = <String, bool>{
      for (final field in widget.fields)
        if (field.kind == AcpFieldKind.boolean)
          field.key: _initialBoolValue(
            widget.initialValues.containsKey(field.key)
                ? widget.initialValues[field.key]
                : field.initialValue,
          ),
    };
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppFormPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: widget.fields
                      .map((field) => _buildField(context, field))
                      .expand((widget) => [widget, const SizedBox(height: 10)])
                      .toList(growable: false),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildField(BuildContext context, AcpFieldDescriptor field) {
    if (field.kind == AcpFieldKind.boolean) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUiPalette.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _boolValues[field.key] ?? false,
          onChanged: (value) {
            setState(() {
              _boolValues[field.key] = value ?? false;
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
          title: Text(field.label),
          subtitle: field.hintText == null ? null : Text(field.hintText!),
        ),
      );
    }

    final controller = _textControllers[field.key]!;
    final isJson = field.kind == AcpFieldKind.json;
    final isMultiline = field.kind == AcpFieldKind.multiline || isJson;

    return TextFormField(
      controller: controller,
      obscureText: field.obscureText,
      minLines: isMultiline ? (field.minLines ?? (isJson ? 6 : 3)) : 1,
      maxLines: isMultiline ? (field.maxLines ?? (isJson ? 10 : 5)) : 1,
      decoration: appFormInputDecoration(
        labelText: field.label,
        hintText: field.hintText,
        errorMaxLines: 4,
      ),
      validator: (value) => _validateField(field, value ?? ''),
    );
  }

  String? _validateField(AcpFieldDescriptor field, String value) {
    final trimmed = value.trim();
    if (field.required && trimmed.isEmpty) {
      return '${field.label} is required.';
    }
    if (trimmed.isEmpty) {
      return null;
    }

    switch (field.kind) {
      case AcpFieldKind.integer:
        if (int.tryParse(trimmed) == null) {
          return 'Enter a whole number.';
        }
        return null;
      case AcpFieldKind.json:
        final result = AcpJsonCodec.parse(trimmed);
        return result.isFailure ? result.failure!.message : null;
      case AcpFieldKind.dateTime:
        if (DateTime.tryParse(trimmed) == null) {
          return 'Enter an ISO-8601 date/time value.';
        }
        return null;
      case AcpFieldKind.text:
      case AcpFieldKind.multiline:
      case AcpFieldKind.boolean:
        return null;
    }
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      return;
    }

    final payload = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field.kind == AcpFieldKind.boolean) {
        payload[field.key] = _boolValues[field.key] ?? false;
        continue;
      }

      final raw = _textControllers[field.key]!.text;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      switch (field.kind) {
        case AcpFieldKind.integer:
          payload[field.key] = int.parse(trimmed);
          break;
        case AcpFieldKind.json:
          payload[field.key] = AcpJsonCodec.parse(trimmed).data;
          break;
        case AcpFieldKind.dateTime:
          payload[field.key] = DateTime.parse(
            trimmed,
          ).toUtc().toIso8601String();
          break;
        case AcpFieldKind.text:
        case AcpFieldKind.multiline:
          payload[field.key] = raw;
          break;
        case AcpFieldKind.boolean:
          break;
      }
    }

    Navigator.of(context).pop(payload);
  }

  String _initialTextValue(AcpFieldDescriptor field, Object? value) {
    if (value == null) {
      return '';
    }

    switch (field.kind) {
      case AcpFieldKind.json:
        return AcpJsonCodec.prettyPrint(value);
      case AcpFieldKind.dateTime:
        return value.toString();
      case AcpFieldKind.integer:
      case AcpFieldKind.text:
      case AcpFieldKind.multiline:
      case AcpFieldKind.boolean:
        return value.toString();
    }
  }

  bool _initialBoolValue(Object? value) {
    if (value is bool) {
      return value;
    }

    final normalized = value?.toString().trim().toLowerCase();
    return normalized == 'true' || normalized == '1' || normalized == 'yes';
  }
}
