// coverage:ignore-file

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_json_codec.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_field.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _acpAdminTableMinWidth = 1120;
const double _acpAdminActionColumnMinWidth = 192;
const double _acpAdminActionButtonWidth = 48;
const double _acpAdminActionCellPaddingAllowance = 32;
const Duration _acpAdminSearchDebounce = Duration(milliseconds: 300);

typedef _AcpReferenceSearch =
    Future<Result<AcpRowPage>> Function(
      AcpFieldReferenceDescriptor reference,
      String searchTerm,
    );
typedef _AcpReferenceLookup =
    Future<Result<AcpRow>> Function(
      AcpFieldReferenceDescriptor reference,
      String rowId,
    );

class AcpAdminPanel<T extends AcpAdminController>
    extends ConsumerStatefulWidget {
  const AcpAdminPanel({
    required this.controllerProvider,
    super.key,
    this.title,
    this.description,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final String? title;
  final String? description;

  @override
  ConsumerState<AcpAdminPanel<T>> createState() => _AcpAdminPanelState<T>();
}

class _AcpAdminPanelState<T extends AcpAdminController>
    extends ConsumerState<AcpAdminPanel<T>> {
  AcpRow? _selectedRow;
  String? _selectedResourceKey;

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
    _syncSelectedRow(
      resourceKey: state.activeResourceKey,
      rows: resourceState.rows,
    );
    final pageTitle = widget.title?.trim().isNotEmpty == true
        ? widget.title!.trim()
        : descriptor.title;
    final pageDescription = widget.description?.trim().isNotEmpty == true
        ? widget.description!.trim()
        : (descriptor.description?.trim().isNotEmpty == true
              ? descriptor.description!.trim()
              : 'Manage ${descriptor.title.toLowerCase()} records.');
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
        AdminPageHeader(
          title: pageTitle,
          subtitle: pageDescription,
          primaryAction: descriptor.allowCreate
              ? FilledButton.icon(
                  key: const Key('acp-admin-create-button'),
                  onPressed: tenantMissing
                      ? null
                      : () => _showCreateDialog(
                          context: context,
                          ref: ref,
                          controllerProvider: widget.controllerProvider,
                          descriptor: descriptor,
                        ),
                  icon: const Icon(Icons.add),
                  label: const Text('New Row'),
                )
              : null,
        ),
        _ResourceSelector(
          descriptors: controller.descriptors,
          state: state,
          activeResourceKey: state.activeResourceKey,
          onSelect: controller.selectResource,
        ),
        _ToolbarRow<T>(
          controllerProvider: widget.controllerProvider,
          descriptor: descriptor,
          resourceState: resourceState,
        ),
        _ActionRow<T>(
          controllerProvider: widget.controllerProvider,
          descriptor: descriptor,
          tenantMissing: tenantMissing,
          showCreate: false,
        ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showDrawer =
                  _selectedRow != null && constraints.maxWidth >= 980;
              final grid = AdminSurface(
                padding: EdgeInsets.zero,
                child: _ResourceTable<T>(
                  controllerProvider: widget.controllerProvider,
                  descriptor: descriptor,
                  resourceState: resourceState,
                  isBusy:
                      state.isLoadingTenants ||
                      resourceState.isLoading ||
                      state.isMutating,
                  selectedRow: _selectedRow,
                  onViewRow: (row) {
                    setState(() {
                      _selectedRow = row;
                      _selectedResourceKey = state.activeResourceKey;
                    });
                  },
                ),
              );
              final drawer = _selectedRow == null
                  ? null
                  : _AcpRowDetailDrawer(
                      descriptor: descriptor,
                      row: _selectedRow!,
                      onClose: () {
                        setState(() {
                          _selectedRow = null;
                        });
                      },
                    );

              if (_selectedRow != null && constraints.maxWidth < 980) {
                return Stack(
                  children: [
                    Positioned.fill(child: grid),
                    Positioned.fill(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: SizedBox(
                          width: math.min(420, constraints.maxWidth),
                          child: drawer!,
                        ),
                      ),
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: grid),
                  if (showDrawer) ...[
                    const SizedBox(width: 12),
                    SizedBox(width: 420, child: drawer!),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  void _syncSelectedRow({
    required String resourceKey,
    required List<AcpRow> rows,
  }) {
    if (_selectedResourceKey != resourceKey) {
      _selectedResourceKey = resourceKey;
      _selectedRow = null;
      return;
    }

    final selectedId = _selectedRow?.id;
    if (selectedId == null) {
      return;
    }

    final stillVisible = rows.any((row) => row.id == selectedId);
    if (!stillVisible) {
      _selectedRow = null;
    }
  }
}

class _ResourceSelector extends StatelessWidget {
  const _ResourceSelector({
    required this.descriptors,
    required this.state,
    required this.activeResourceKey,
    required this.onSelect,
  });

  final List<AcpResourceDescriptor> descriptors;
  final AcpAdminState state;
  final String activeResourceKey;
  final Future<void> Function(String key) onSelect;

  @override
  Widget build(BuildContext context) {
    return AdminTabs(
      items: descriptors
          .map((descriptor) {
            final resourceState = state.resourceStates[descriptor.key];
            return AdminTabItem(
              key: Key('acp-admin-tab-${descriptor.key}'),
              label: descriptor.title,
              count: resourceState?.tabCount,
              tooltip: descriptor.description,
              selected: descriptor.key == activeResourceKey,
              onSelected: () => onSelect(descriptor.key),
            );
          })
          .toList(growable: false),
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

    return AdminToolbar(
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
            child: AppSearchableSelectField<AcpTenantOption>(
              fieldKey: const Key('acp-admin-tenant-selector'),
              optionKeyPrefix: 'acp-admin-tenant-option',
              labelText: 'Tenant',
              hintText: 'Search tenants',
              options: state.tenants,
              selectedOptionKey: state.selectedTenantId,
              optionKey: (tenant) => tenant.id,
              optionTitle: (tenant) => tenant.label,
              optionSubtitle: (tenant) => tenant.id,
              optionSearchText: (tenant) =>
                  '${tenant.label} ${tenant.id} ${tenant.slug ?? ''}',
              emptyMessage: 'No matching tenants found.',
              enabled: state.tenants.isNotEmpty,
              onSelected: (tenant) {
                unawaited(controller.selectTenant(tenant.id));
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
    this.showCreate = true,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final bool tenantMissing;
  final bool showCreate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolbarActions = descriptor.collectionActions
        .where((action) => action.showInToolbar)
        .toList(growable: false);

    if ((!descriptor.allowCreate || !showCreate) && toolbarActions.isEmpty) {
      return const SizedBox.shrink();
    }

    return AdminToolbar(
      children: [
        if (descriptor.allowCreate && showCreate)
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
        for (final action in toolbarActions)
          TextButton.icon(
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
    required this.isBusy,
    required this.selectedRow,
    required this.onViewRow,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpResourceState resourceState;
  final bool isBusy;
  final AcpRow? selectedRow;
  final ValueChanged<AcpRow> onViewRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(controllerProvider.notifier);
    final tenantMissing =
        descriptor.scopeMode == AcpScopeMode.required &&
        (ref.watch(controllerProvider).selectedTenantId == null ||
            ref.watch(controllerProvider).selectedTenantId!.isEmpty);
    final createAction = descriptor.allowCreate
        ? FilledButton.icon(
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
          )
        : null;
    final actionColumnWidth = _actionColumnWidthFor(descriptor);

    return AdminDataGrid<AcpRow>(
      rows: resourceState.rows,
      columns: [
        for (final column in descriptor.columns)
          AdminGridColumn<AcpRow>(
            key: column.key,
            label: column.label,
            flex: column.flex,
            cell: (_, row) =>
                AdminCellText(_formatCellValue(row[column.key]), maxLines: 2),
          ),
      ],
      actionsBuilder: (context, row) => SizedBox(
        width: actionColumnWidth,
        child: _RowActions<T>(
          controllerProvider: controllerProvider,
          descriptor: descriptor,
          row: row,
          onViewRow: onViewRow,
        ),
      ),
      actionsWidth: actionColumnWidth,
      rowKey: (row) => row.id ?? row.hashCode.toString(),
      onRowSelected: onViewRow,
      isRowSelected: (row) {
        final selectedId = selectedRow?.id;
        final rowId = row.id;
        return selectedId != null && rowId != null && selectedId == rowId;
      },
      isLoading: isBusy,
      hasActiveFilter: resourceState.searchTerm.trim().isNotEmpty,
      emptyState: AdminEmptyStateData(
        title: _emptyTitle(descriptor),
        message: _emptyMessage(descriptor),
        primaryAction: createAction,
        secondaryAction: TextButton.icon(
          onPressed: controller.refresh,
          icon: const Icon(Icons.refresh),
          label: const Text('Refresh'),
        ),
      ),
      filteredEmptyState: const AdminEmptyStateData(
        title: 'No matching records.',
        message: 'Clear the search or adjust filters.',
      ),
      minWidth: _acpAdminTableMinWidth,
      footer: _ResourcePaginator<T>(
        controllerProvider: controllerProvider,
        resourceState: resourceState,
      ),
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

String _emptyTitle(AcpResourceDescriptor descriptor) {
  final noun = descriptor.title.toLowerCase();
  return 'No $noun yet.';
}

String _emptyMessage(AcpResourceDescriptor descriptor) {
  final description = descriptor.description?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }
  if (descriptor.allowCreate) {
    return 'Create a row to start managing this resource.';
  }
  return descriptor.emptyMessage;
}

double _actionColumnWidthFor(AcpResourceDescriptor descriptor) {
  var actionCount = 1;
  actionCount += descriptor.collectionActions
      .where((action) => action.showInRowMenu && action.showAsRowButton)
      .length;
  if (descriptor.allowUpdate) {
    actionCount++;
  }
  if (descriptor.allowDelete) {
    actionCount++;
  }
  if (descriptor.allowRestore) {
    actionCount++;
  }
  final hasMenuActions =
      descriptor.collectionActions.any(
        (action) => action.showInRowMenu && !action.showAsRowButton,
      ) ||
      descriptor.entityActions.isNotEmpty;
  if (hasMenuActions) {
    actionCount++;
  }

  return math.max(
    _acpAdminActionColumnMinWidth,
    actionCount * _acpAdminActionButtonWidth +
        _acpAdminActionCellPaddingAllowance,
  );
}

class _RowActions<T extends AcpAdminController> extends ConsumerWidget {
  const _RowActions({
    required this.controllerProvider,
    required this.descriptor,
    required this.row,
    required this.onViewRow,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpRow row;
  final ValueChanged<AcpRow> onViewRow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowId = row.id;
    final rowButtonActions = <_RowMenuAction>[
      for (final action in descriptor.collectionActions)
        if (action.showInRowMenu && action.showAsRowButton)
          _RowMenuAction.collection(
            action: action,
            initialValues: _collectionActionInitialValues(
              action: action,
              row: row,
            ),
          ),
    ];
    final rowMenuActions = <_RowMenuAction>[
      for (final action in descriptor.collectionActions)
        if (action.showInRowMenu && !action.showAsRowButton)
          _RowMenuAction.collection(
            action: action,
            initialValues: _collectionActionInitialValues(
              action: action,
              row: row,
            ),
          ),
      if (rowId != null)
        for (final action in descriptor.entityActions)
          _RowMenuAction.entity(action: action),
    ];

    return Align(
      alignment: Alignment.centerRight,
      child: FittedBox(
        alignment: Alignment.centerRight,
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminIconButton(
              tooltip: 'View row',
              icon: Icons.visibility_outlined,
              onPressed: () => onViewRow(row),
            ),
            for (final action in rowButtonActions)
              AdminIconButton(
                tooltip: action.action.label,
                icon: action.action.icon ?? Icons.autorenew,
                onPressed: () => _runCollectionAction(
                  context: context,
                  ref: ref,
                  controllerProvider: controllerProvider,
                  descriptor: descriptor,
                  action: action.action,
                  initialValues: action.initialValues,
                  scopeRow: row,
                ),
              ),
            if (descriptor.allowUpdate && rowId != null)
              AdminIconButton(
                tooltip: 'Edit row',
                icon: Icons.edit_outlined,
                onPressed: () => _showUpdateDialog(
                  context: context,
                  ref: ref,
                  controllerProvider: controllerProvider,
                  descriptor: descriptor,
                  row: row,
                ),
              ),
            if (descriptor.allowDelete && rowId != null)
              AdminIconButton(
                tooltip: 'Delete row',
                icon: Icons.delete_outline,
                destructive: true,
                onPressed: () => _deleteRow(
                  context: context,
                  ref: ref,
                  controllerProvider: controllerProvider,
                  descriptor: descriptor,
                  row: row,
                ),
              ),
            if (descriptor.allowRestore && rowId != null)
              AdminIconButton(
                tooltip: 'Restore row',
                icon: Icons.restore,
                onPressed: () => _restoreRow(
                  context: context,
                  ref: ref,
                  controllerProvider: controllerProvider,
                  descriptor: descriptor,
                  row: row,
                ),
              ),
            if (rowMenuActions.isNotEmpty)
              Builder(
                builder: (buttonContext) {
                  return AdminIconButton(
                    key: const Key('acp-admin-row-more-actions'),
                    tooltip: 'More actions',
                    icon: Icons.more_horiz,
                    onPressed: () async {
                      final selectedActionName = await _showRowActionsMenu(
                        context: buttonContext,
                        actions: rowMenuActions,
                      );
                      if (selectedActionName == null ||
                          !buttonContext.mounted) {
                        return;
                      }

                      final action = rowMenuActions.firstWhere(
                        (candidate) =>
                            candidate.action.name == selectedActionName,
                      );
                      if (action.isCollectionAction) {
                        await _runCollectionAction(
                          context: buttonContext,
                          ref: ref,
                          controllerProvider: controllerProvider,
                          descriptor: descriptor,
                          action: action.action,
                          initialValues: action.initialValues,
                          scopeRow: row,
                        );
                        return;
                      }
                      await _runEntityAction(
                        context: buttonContext,
                        ref: ref,
                        controllerProvider: controllerProvider,
                        descriptor: descriptor,
                        action: action.action,
                        row: row,
                      );
                    },
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

Future<String?> _showRowActionsMenu({
  required BuildContext context,
  required List<_RowMenuAction> actions,
}) {
  final buttonBox = context.findRenderObject() as RenderBox?;
  final overlayBox =
      Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (buttonBox == null || overlayBox == null) {
    return Future<String?>.value();
  }

  final buttonRect = Rect.fromPoints(
    buttonBox.localToGlobal(Offset.zero, ancestor: overlayBox),
    buttonBox.localToGlobal(
      buttonBox.size.bottomRight(Offset.zero),
      ancestor: overlayBox,
    ),
  );

  return showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(buttonRect, Offset.zero & overlayBox.size),
    items: actions
        .map(
          (action) => PopupMenuItem<String>(
            value: action.action.name,
            child: Text(action.action.label),
          ),
        )
        .toList(growable: false),
  );
}

Map<String, dynamic> _collectionActionInitialValues({
  required AcpActionDescriptor action,
  required AcpRow row,
}) {
  if (!action.prefillFieldsFromRow) {
    return const <String, dynamic>{};
  }

  return <String, dynamic>{
    for (final field in action.fields)
      if (row.containsKey(field.key) && row[field.key] != null)
        field.key: row[field.key],
  };
}

class _ResourcePaginator<T extends AcpAdminController> extends ConsumerWidget {
  const _ResourcePaginator({
    required this.controllerProvider,
    required this.resourceState,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceState resourceState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(controllerProvider.notifier);
    return AdminGridFooter(
      state: AdminPaginationState(
        visibleCount: resourceState.rows.length,
        totalCount: resourceState.total,
        page: resourceState.page,
        pages: resourceState.pages,
        pageSize: resourceState.pageSize,
        pageSizes: const <int>[10, 15, 25, 50],
        onPageSizeChanged: (value) {
          unawaited(controller.setRowsPerPage(value));
        },
        onFirstPage: resourceState.page <= 1
            ? null
            : () => unawaited(controller.setPage(1)),
        onPreviousPage: resourceState.page <= 1
            ? null
            : () => unawaited(controller.setPage(resourceState.page - 1)),
        onNextPage: resourceState.page >= resourceState.pages
            ? null
            : () => unawaited(controller.setPage(resourceState.page + 1)),
        onLastPage: resourceState.page >= resourceState.pages
            ? null
            : () => unawaited(controller.setPage(resourceState.pages)),
      ),
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
    contextLabel: _dialogScopeLabel(
      descriptor: descriptor,
      state: ref.read(controllerProvider),
    ),
    referenceSearch: _referenceSearchFor(
      ref: ref,
      controllerProvider: controllerProvider,
    ),
    referenceLookup: _referenceLookupFor(
      ref: ref,
      controllerProvider: controllerProvider,
    ),
    submitLabel: 'Create',
    fields: descriptor.createFields,
    resourceKey: descriptor.key,
    entitySet: descriptor.entitySet,
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
    contextLabel: _dialogScopeLabel(
      descriptor: descriptor,
      state: ref.read(controllerProvider),
      row: row,
    ),
    referenceSearch: _referenceSearchFor(
      ref: ref,
      controllerProvider: controllerProvider,
      tenantIdOverride: row.tenantId,
      useTenantIdOverride: _usesRowTenantScope(
        descriptor: descriptor,
        row: row,
      ),
    ),
    referenceLookup: _referenceLookupFor(
      ref: ref,
      controllerProvider: controllerProvider,
      tenantIdOverride: row.tenantId,
      useTenantIdOverride: _usesRowTenantScope(
        descriptor: descriptor,
        row: row,
      ),
    ),
    submitLabel: 'Save',
    fields: descriptor.updateFields,
    resourceKey: descriptor.key,
    entitySet: descriptor.entitySet,
    initialValues: row,
  );
  if (payload == null) {
    return;
  }

  final useTenantIdOverride = _usesRowTenantScope(
    descriptor: descriptor,
    row: row,
  );
  final result = await ref
      .read(controllerProvider.notifier)
      .updateRow(
        rowId: rowId,
        values: payload,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: useTenantIdOverride,
        rowVersion: row.rowVersion,
      );
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

  final useTenantIdOverride = _usesRowTenantScope(
    descriptor: descriptor,
    row: row,
  );
  final result = await ref
      .read(controllerProvider.notifier)
      .deleteRow(
        rowId: rowId,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: useTenantIdOverride,
        rowVersion: row.rowVersion,
      );
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

  final useTenantIdOverride = _usesRowTenantScope(
    descriptor: descriptor,
    row: row,
  );
  final result = await ref
      .read(controllerProvider.notifier)
      .restoreRow(
        rowId: rowId,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: useTenantIdOverride,
        rowVersion: row.rowVersion,
      );
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
  Map<String, dynamic> initialValues = const <String, dynamic>{},
  AcpRow? scopeRow,
}) async {
  Map<String, dynamic>? payload = const <String, dynamic>{};
  if (action.fields.isNotEmpty) {
    payload = await _showDynamicFormDialog(
      context: context,
      title: action.label,
      contextLabel: _dialogScopeLabel(
        descriptor: descriptor,
        state: ref.read(controllerProvider),
        row: scopeRow,
      ),
      referenceSearch: _referenceSearchFor(
        ref: ref,
        controllerProvider: controllerProvider,
        tenantIdOverride: scopeRow?.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: scopeRow,
        ),
      ),
      referenceLookup: _referenceLookupFor(
        ref: ref,
        controllerProvider: controllerProvider,
        tenantIdOverride: scopeRow?.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: scopeRow,
        ),
      ),
      submitLabel: action.label,
      fields: action.fields,
      resourceKey: descriptor.key,
      entitySet: descriptor.entitySet,
      actionName: action.name,
      initialValues: initialValues,
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

  final useTenantIdOverride = _usesRowTenantScope(
    descriptor: descriptor,
    row: scopeRow,
  );
  final result = await ref
      .read(controllerProvider.notifier)
      .runCollectionAction(
        action: action,
        values: payload,
        tenantIdOverride: scopeRow?.tenantId,
        useTenantIdOverride: useTenantIdOverride,
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

class _RowMenuAction {
  const _RowMenuAction.collection({
    required this.action,
    required this.initialValues,
  }) : isCollectionAction = true;

  const _RowMenuAction.entity({required this.action})
    : isCollectionAction = false,
      initialValues = const <String, dynamic>{};

  final AcpActionDescriptor action;
  final bool isCollectionAction;
  final Map<String, dynamic> initialValues;
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
      contextLabel: _dialogScopeLabel(
        descriptor: descriptor,
        state: ref.read(controllerProvider),
        row: row,
      ),
      referenceSearch: _referenceSearchFor(
        ref: ref,
        controllerProvider: controllerProvider,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: row,
        ),
      ),
      referenceLookup: _referenceLookupFor(
        ref: ref,
        controllerProvider: controllerProvider,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: row,
        ),
      ),
      submitLabel: action.label,
      fields: action.fields,
      resourceKey: descriptor.key,
      entitySet: descriptor.entitySet,
      actionName: action.name,
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
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: row,
        ),
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
  String? resourceKey,
  String? entitySet,
  String? actionName,
  String? contextLabel,
  _AcpReferenceSearch? referenceSearch,
  _AcpReferenceLookup? referenceLookup,
  Map<String, dynamic> initialValues = const <String, dynamic>{},
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => _AcpDynamicFormDialog(
      title: title,
      contextLabel: contextLabel,
      referenceSearch: referenceSearch,
      referenceLookup: referenceLookup,
      submitLabel: submitLabel,
      fields: fields,
      resourceKey: resourceKey,
      entitySet: entitySet,
      actionName: actionName,
      initialValues: initialValues,
    ),
  );
}

_AcpReferenceSearch _referenceSearchFor<T extends AcpAdminController>({
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  String? tenantIdOverride,
  bool useTenantIdOverride = false,
}) {
  return (reference, searchTerm) {
    final state = ref.read(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final tenantId = _referenceTenantIdFor(
      reference: reference,
      state: state,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );

    return controller.repository.listRows(
      descriptor: AcpResourceDescriptor(
        key: 'reference-${reference.entitySet}',
        title: reference.title,
        entitySet: reference.entitySet,
        scopeMode: reference.scopeMode,
        columns: const <AcpColumnDescriptor>[],
        searchFields: reference.searchFields,
        defaultOrderBy: reference.defaultOrderBy,
        pageSize: reference.pageSize,
      ),
      pageRequest: PageRequest(page: 1, pageSize: reference.pageSize),
      tenantId: tenantId,
      searchTerm: searchTerm,
    );
  };
}

_AcpReferenceLookup _referenceLookupFor<T extends AcpAdminController>({
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  String? tenantIdOverride,
  bool useTenantIdOverride = false,
}) {
  return (reference, rowId) {
    final state = ref.read(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final tenantId = _referenceTenantIdFor(
      reference: reference,
      state: state,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );

    return controller.repository.fetchRow(
      descriptor: AcpResourceDescriptor(
        key: 'reference-${reference.entitySet}',
        title: reference.title,
        entitySet: reference.entitySet,
        scopeMode: reference.scopeMode,
        columns: const <AcpColumnDescriptor>[],
      ),
      rowId: rowId,
      tenantId: tenantId,
    );
  };
}

String? _referenceTenantIdFor({
  required AcpFieldReferenceDescriptor reference,
  required AcpAdminState state,
  required String? tenantIdOverride,
  required bool useTenantIdOverride,
}) {
  if (reference.scopeMode == AcpScopeMode.none) {
    return null;
  }

  final tenantId = useTenantIdOverride
      ? tenantIdOverride
      : state.selectedTenantId;
  final trimmedTenantId = tenantId?.trim();
  return trimmedTenantId == null || trimmedTenantId.isEmpty
      ? null
      : trimmedTenantId;
}

String? _dialogScopeLabel({
  required AcpResourceDescriptor descriptor,
  required AcpAdminState state,
  AcpRow? row,
}) {
  final rowScopeLabel = _rowScopeLabel(
    descriptor: descriptor,
    state: state,
    row: row,
  );
  if (rowScopeLabel != null) {
    return rowScopeLabel;
  }

  switch (descriptor.scopeMode) {
    case AcpScopeMode.none:
      return null;
    case AcpScopeMode.required:
      return _tenantScopeLabel(state);
    case AcpScopeMode.optional:
      final resourceState = state.resourceStates[descriptor.key];
      if (resourceState?.optionalScopeSelection !=
          AcpOptionalScopeSelection.tenant) {
        return 'Scope: Global';
      }
      return _tenantScopeLabel(state);
  }
}

String? _rowScopeLabel({
  required AcpResourceDescriptor descriptor,
  required AcpAdminState state,
  required AcpRow? row,
}) {
  if (!_usesRowTenantScope(descriptor: descriptor, row: row)) {
    return null;
  }

  final tenantId = row!.tenantId;
  if (tenantId == null) {
    return 'Scope: Global';
  }

  return 'Tenant: ${_tenantLabelForId(state, tenantId)}';
}

bool _usesRowTenantScope({
  required AcpResourceDescriptor descriptor,
  required AcpRow? row,
}) {
  if (descriptor.scopeMode == AcpScopeMode.none ||
      row == null ||
      !row.containsKey('TenantId')) {
    return false;
  }

  return descriptor.scopeMode == AcpScopeMode.optional || row.tenantId != null;
}

String _tenantScopeLabel(AcpAdminState state) {
  final tenant = state.selectedTenant;
  if (tenant != null) {
    return 'Tenant: ${tenant.label}';
  }

  final tenantId = state.selectedTenantId?.trim();
  if (tenantId != null && tenantId.isNotEmpty) {
    return 'Tenant: $tenantId';
  }

  return 'Tenant: Not selected';
}

String _tenantLabelForId(AcpAdminState state, String tenantId) {
  for (final tenant in state.tenants) {
    if (tenant.id == tenantId) {
      return tenant.label;
    }
  }

  return tenantId;
}

class _AcpRowDetailDrawer extends StatelessWidget {
  const _AcpRowDetailDrawer({
    required this.descriptor,
    required this.row,
    required this.onClose,
  });

  final AcpResourceDescriptor descriptor;
  final AcpRow row;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final objectId = row.id;
    return AdminDetailDrawer(
      title: descriptor.title,
      subtitle: objectId,
      onClose: onClose,
      child: SelectionArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            if (objectId != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('acp-row-copy-object-id-button'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: objectId));
                    if (!context.mounted) {
                      return;
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Object ID copied.')),
                    );
                  },
                  icon: const Icon(Icons.content_copy, size: 18),
                  label: const Text('Copy ID'),
                ),
              ),
            const SizedBox(height: 8),
            for (final entry in row.entries)
              _AcpDetailField(label: entry.key, value: entry.value),
          ],
        ),
      ),
    );
  }
}

class _AcpDetailField extends StatelessWidget {
  const _AcpDetailField({required this.label, required this.value});

  final String label;
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final text = value is Map || value is List
        ? AcpJsonCodec.prettyPrint(value)
        : (value?.toString() ?? '-');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppUiPalette.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
            decoration: BoxDecoration(
              color: AppUiPalette.surfaceMuted,
              borderRadius: BorderRadius.circular(adminCompactRadius),
              border: Border.all(color: AppUiPalette.border),
            ),
            child: Text(text, maxLines: 8, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
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
        return AppFormDialog(
          title: 'Action Result',
          maxWidth: 760,
          maxHeight: 760,
          body: SelectableText(AcpJsonCodec.prettyPrint(result.data)),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
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

class _AcpReferenceField extends StatefulWidget {
  const _AcpReferenceField({
    required this.field,
    required this.controller,
    required this.search,
    required this.lookup,
    required this.helpText,
    required this.helpKey,
    required this.validator,
    super.key,
  });

  final AcpFieldDescriptor field;
  final TextEditingController controller;
  final _AcpReferenceSearch search;
  final _AcpReferenceLookup lookup;
  final String helpText;
  final Key helpKey;
  final FormFieldValidator<String> validator;

  @override
  State<_AcpReferenceField> createState() => _AcpReferenceFieldState();
}

class _AcpReferenceFieldState extends State<_AcpReferenceField> {
  late final TextEditingController _searchController;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  AcpRow? _selectedRow;
  List<AcpRow> _results = const <AcpRow>[];

  AcpFieldReferenceDescriptor get _reference => widget.field.reference!;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hydrateSelectedReference();
    });
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: widget.controller.text,
      validator: widget.validator,
      builder: (fieldState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: Key('acp-reference-search-${widget.field.key}'),
              controller: _searchController,
              decoration: appFormInputDecoration(
                labelText: widget.field.label,
                hintText: widget.field.hintText ?? 'Search existing records',
                suffixIcon: const Icon(Icons.manage_search_outlined),
                helpText: widget.helpText,
                helpKey: widget.helpKey,
                errorMaxLines: 4,
              ),
              onChanged: _queueSearch,
            ),
            if (fieldState.errorText != null) ...[
              const SizedBox(height: 6),
              AppErrorAlert(message: fieldState.errorText!),
            ],
            if (widget.controller.text.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _SelectedReferenceTile(
                fieldKey: widget.field.key,
                label: _selectedLabel,
                onClear: () => _clearSelection(fieldState),
              ),
            ],
            if (_isSearching) ...[
              const SizedBox(height: 8),
              const LinearProgressIndicator(),
            ],
            if (_searchError != null && _searchError!.isNotEmpty) ...[
              const SizedBox(height: 8),
              AppErrorAlert(message: _searchError!),
            ],
            if (_hasSearched && !_isSearching && _searchError == null) ...[
              const SizedBox(height: 8),
              _buildResults(fieldState),
            ],
          ],
        );
      },
    );
  }

  String get _selectedLabel {
    final selectedRow = _selectedRow;
    final selectedValue = widget.controller.text.trim();
    if (selectedRow == null) {
      return selectedValue;
    }

    final title = _referenceTitle(selectedRow);
    if (title == selectedValue) {
      return selectedValue;
    }

    return '$title  |  $selectedValue';
  }

  Widget _buildResults(FormFieldState<String> fieldState) {
    if (_results.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppUiPalette.surface,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No matching records found.'),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 220),
      child: Container(
        decoration: BoxDecoration(
          color: AppUiPalette.surface,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ListView.separated(
          shrinkWrap: true,
          itemCount: _results.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final row = _results[index];
            final value = _referenceValue(row);
            final isSelected = widget.controller.text.trim() == value;
            return ListTile(
              key: Key('acp-reference-option-${widget.field.key}-$value'),
              enabled: value.isNotEmpty,
              selected: isSelected,
              leading: Icon(
                isSelected ? Icons.check_circle_outline : Icons.link_outlined,
              ),
              title: Text(_referenceTitle(row)),
              subtitle: Text(_referenceSubtitle(row)),
              onTap: value.isEmpty ? null : () => _selectRow(row, fieldState),
            );
          },
        ),
      ),
    );
  }

  void _queueSearch(String value) {
    _searchDebounce?.cancel();
    final term = value.trim();
    if (term.isEmpty) {
      setState(() {
        _isSearching = false;
        _hasSearched = false;
        _searchError = null;
        _results = const <AcpRow>[];
      });
      return;
    }

    if (term.length < 2) {
      setState(() {
        _isSearching = false;
        _hasSearched = true;
        _searchError = null;
        _results = const <AcpRow>[];
      });
      return;
    }

    _searchDebounce = Timer(
      _acpAdminSearchDebounce,
      () => _searchReferences(term),
    );
  }

  Future<void> _searchReferences(String term) async {
    final generation = ++_searchGeneration;
    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _searchError = null;
    });

    final response = await widget.search(_reference, term);
    if (!mounted || generation != _searchGeneration) {
      return;
    }

    if (response.isFailure) {
      setState(() {
        _isSearching = false;
        _results = const <AcpRow>[];
        _searchError =
            response.failure?.message ?? 'Could not search references.';
      });
      return;
    }

    setState(() {
      _isSearching = false;
      _results = response.data?.items ?? const <AcpRow>[];
      _searchError = null;
    });
  }

  Future<void> _hydrateSelectedReference() async {
    final selectedValue = widget.controller.text.trim();
    if (selectedValue.isEmpty || _selectedRow != null) {
      return;
    }

    final response = await widget.lookup(_reference, selectedValue);
    if (!mounted ||
        _selectedRow != null ||
        widget.controller.text.trim() != selectedValue ||
        response.isFailure) {
      return;
    }

    final selectedRow = response.data;
    if (selectedRow == null || _referenceValue(selectedRow) != selectedValue) {
      return;
    }

    setState(() {
      _selectedRow = selectedRow;
    });
  }

  void _selectRow(AcpRow row, FormFieldState<String> fieldState) {
    final value = _referenceValue(row);
    setState(() {
      _selectedRow = row;
      widget.controller.text = value;
    });
    fieldState.didChange(value);
    fieldState.validate();
  }

  void _clearSelection(FormFieldState<String> fieldState) {
    setState(() {
      _selectedRow = null;
      widget.controller.clear();
    });
    fieldState.didChange('');
    fieldState.validate();
  }

  String _referenceValue(AcpRow row) {
    return row[_reference.idField]?.toString().trim() ?? '';
  }

  String _referenceTitle(AcpRow row) {
    final composedTitle = _composedReferenceTitle(row);
    if (composedTitle != null) {
      return composedTitle;
    }

    for (final field in _reference.titleFields) {
      final value = row[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    final value = _referenceValue(row);
    return value.isEmpty ? 'Untitled reference' : value;
  }

  String? _composedReferenceTitle(AcpRow row) {
    return switch (_reference.entitySet) {
      'MessagingClientProfiles' => _profileReferenceTitle(
        row,
        identifierFields: const <String>['PlatformKey', 'ProfileKey'],
      ),
      'ChannelProfiles' => _profileReferenceTitle(
        row,
        identifierFields: const <String>['ChannelKey', 'ProfileKey'],
      ),
      _ => null,
    };
  }

  String? _profileReferenceTitle(
    AcpRow row, {
    required List<String> identifierFields,
  }) {
    final identifierParts = <String>[];
    for (final field in identifierFields) {
      final value = row[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        identifierParts.add(value);
      }
    }

    final identifier = identifierParts.join(' / ');
    final displayName = row['DisplayName']?.toString().trim() ?? '';
    if (identifier.isEmpty) {
      return displayName.isEmpty ? null : displayName;
    }
    if (displayName.isEmpty || displayName == identifier) {
      return identifier;
    }

    return '$displayName ($identifier)';
  }

  String _referenceSubtitle(AcpRow row) {
    final values = <String>[];
    for (final field in _reference.subtitleFields) {
      final value = row[field]?.toString().trim();
      if (value != null && value.isNotEmpty && !values.contains(value)) {
        values.add(value);
      }
    }

    return values.isEmpty ? _referenceValue(row) : values.join('  |  ');
  }
}

class _SelectedReferenceTile extends StatelessWidget {
  const _SelectedReferenceTile({
    required this.fieldKey,
    required this.label,
    required this.onClear,
  });

  final String fieldKey;
  final String label;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('acp-reference-selected-$fieldKey'),
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

class _AcpDynamicFormDialog extends StatefulWidget {
  const _AcpDynamicFormDialog({
    required this.title,
    required this.contextLabel,
    required this.referenceSearch,
    required this.referenceLookup,
    required this.submitLabel,
    required this.fields,
    required this.resourceKey,
    required this.entitySet,
    required this.actionName,
    required this.initialValues,
  });

  final String title;
  final String? contextLabel;
  final _AcpReferenceSearch? referenceSearch;
  final _AcpReferenceLookup? referenceLookup;
  final String submitLabel;
  final List<AcpFieldDescriptor> fields;
  final String? resourceKey;
  final String? entitySet;
  final String? actionName;
  final Map<String, dynamic> initialValues;

  @override
  State<_AcpDynamicFormDialog> createState() => _AcpDynamicFormDialogState();
}

class _AcpDynamicFormDialogState extends State<_AcpDynamicFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  late final Map<String, bool> _boolValues;
  String? _formErrorText;

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
    return AppFormDialog(
      title: widget.title,
      maxWidth: 720,
      maxHeight: 760,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (widget.contextLabel != null) ...[
            Container(
              decoration: BoxDecoration(
                color: AppUiPalette.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppUiPalette.success.withValues(alpha: 0.38),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  const Icon(
                    Icons.apartment_outlined,
                    size: 20,
                    color: AppUiPalette.success,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.contextLabel!,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppUiPalette.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (_formErrorText != null && _formErrorText!.isNotEmpty) ...[
            AppErrorAlert(
              key: const Key('acp-dynamic-form-error-alert'),
              copyButtonKey: const Key('acp-dynamic-form-error-copy-button'),
              message: _formErrorText!,
            ),
            const SizedBox(height: 12),
          ],
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: widget.fields
                  .map((field) => _buildField(context, field))
                  .expand((widget) => [widget, const SizedBox(height: 10)])
                  .toList(growable: false),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.submitLabel)),
      ],
    );
  }

  Widget _buildField(BuildContext context, AcpFieldDescriptor field) {
    final helpText = acpFieldHelpText(
      key: field.key,
      label: field.label,
      kind: field.kind,
      resourceKey: widget.resourceKey,
      entitySet: widget.entitySet,
      actionName: widget.actionName,
    );
    final helpKey = Key('acp-dynamic-field-help-${field.key}');
    if (field.kind == AcpFieldKind.boolean) {
      return Container(
        decoration: BoxDecoration(
          color: AppUiPalette.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppUiPalette.border),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _boolValues[field.key] ?? false,
          onChanged: field.readOnly
              ? null
              : (value) {
                  setState(() {
                    _boolValues[field.key] = value ?? false;
                  });
                },
          controlAffinity: ListTileControlAffinity.leading,
          title: appFieldLabelWithHelp(
            labelText: field.label,
            helpText: helpText,
            helpKey: helpKey,
          ),
          subtitle: field.hintText == null ? null : Text(field.hintText!),
        ),
      );
    }

    final controller = _textControllers[field.key]!;
    if (field.reference != null &&
        widget.referenceSearch != null &&
        widget.referenceLookup != null) {
      return _AcpReferenceField(
        key: Key('acp-dynamic-field-${field.key}'),
        field: field,
        controller: controller,
        search: widget.referenceSearch!,
        lookup: widget.referenceLookup!,
        helpText: helpText,
        helpKey: helpKey,
        validator: (value) => _validateField(field, value ?? ''),
      );
    }

    if (field.kind == AcpFieldKind.json) {
      return AcpJsonEditorField(
        key: Key('acp-dynamic-field-${field.key}'),
        controller: controller,
        editorKey: Key('acp-json-editor-text-${field.key}'),
        hintText: field.hintText,
        helpKey: helpKey,
        helpText: helpText,
        labelText: field.label,
        maxLines: field.maxLines ?? 10,
        minLines: field.minLines ?? 6,
        validator: (value) => _validateField(field, value ?? ''),
      );
    }

    if (field.options.isNotEmpty) {
      final options = _dropdownOptionsFor(field, controller.text);
      return DropdownButtonFormField<String>(
        key: Key('acp-dynamic-field-${field.key}'),
        initialValue: controller.text.trim().isEmpty
            ? null
            : controller.text.trim(),
        isExpanded: true,
        decoration: appFormInputDecoration(
          labelText: field.label,
          hintText: field.hintText,
          helpText: helpText,
          helpKey: helpKey,
          errorMaxLines: 4,
        ),
        items: options
            .map(
              (option) => DropdownMenuItem<String>(
                key: Key('acp-dynamic-field-${field.key}-option-$option'),
                value: option,
                child: Text(option, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(growable: false),
        onChanged: field.readOnly
            ? null
            : (value) {
                controller.text = value ?? '';
              },
        validator: (value) => _validateField(field, value ?? ''),
      );
    }

    final isMultiline = field.kind == AcpFieldKind.multiline;

    return TextFormField(
      key: Key('acp-dynamic-field-${field.key}'),
      controller: controller,
      obscureText: field.obscureText,
      readOnly: field.readOnly,
      minLines: isMultiline ? (field.minLines ?? 3) : 1,
      maxLines: isMultiline ? (field.maxLines ?? 5) : 1,
      decoration: appFormInputDecoration(
        labelText: field.label,
        hintText: field.hintText,
        helpText: helpText,
        helpKey: helpKey,
        errorMaxLines: 4,
      ),
      validator: (value) => _validateField(field, value ?? ''),
    );
  }

  String? _validateField(AcpFieldDescriptor field, String value) {
    final trimmed = value.trim();
    if (_isRequired(field) && trimmed.isEmpty) {
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

  bool _isRequired(AcpFieldDescriptor field) {
    if (field.required) {
      return true;
    }
    if (field.requiredWhenEquals.isEmpty) {
      return false;
    }

    for (final entry in field.requiredWhenEquals.entries) {
      final currentValue = _currentFieldValue(entry.key);
      if (currentValue == null) {
        return false;
      }

      final normalizedCurrentValue = currentValue.trim().toLowerCase();
      final matches = entry.value.any(
        (candidate) => normalizedCurrentValue == candidate.trim().toLowerCase(),
      );
      if (!matches) {
        return false;
      }
    }

    return true;
  }

  String? _currentFieldValue(String key) {
    final textController = _textControllers[key];
    if (textController != null) {
      return textController.text;
    }

    if (_boolValues.containsKey(key)) {
      return (_boolValues[key] ?? false).toString();
    }

    final initialValue = widget.initialValues[key];
    return initialValue?.toString();
  }

  List<String> _dropdownOptionsFor(AcpFieldDescriptor field, String value) {
    final options = <String>[
      for (final option in field.options)
        if (option.trim().isNotEmpty) option.trim(),
    ];
    final currentValue = value.trim();
    if (currentValue.isNotEmpty && !options.contains(currentValue)) {
      options.insert(0, currentValue);
    }

    return options.toSet().toList(growable: false);
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) {
      setState(() {
        _formErrorText = _validationErrorSummary();
      });
      return;
    }
    setState(() {
      _formErrorText = null;
    });

    final payload = <String, dynamic>{};
    for (final field in widget.fields) {
      if (field.readOnly) {
        continue;
      }
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

  String _validationErrorSummary() {
    final errors = <String>[];
    for (final field in widget.fields) {
      final value = field.kind == AcpFieldKind.boolean
          ? (_boolValues[field.key] ?? false).toString()
          : (_textControllers[field.key]?.text ?? '');
      final error = _validateField(field, value);
      if (error != null && error.trim().isNotEmpty) {
        errors.add('${field.label}: $error');
      }
    }

    if (errors.isEmpty) {
      return 'Review the highlighted fields.';
    }
    return errors.join('\n');
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
