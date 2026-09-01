// coverage:ignore-file

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_field_help.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_money_codec.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_reference_display.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_json_codec.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_json_editor_field.dart';
import 'package:mugen_ui/shared/presentation/admin/admin_components.dart';
import 'package:mugen_ui/shared/presentation/forms/app_searchable_select_field.dart';
import 'package:mugen_ui/shared/presentation/forms/app_temporal_form_fields.dart';
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
      List<String> extraFilters,
      Map<String, dynamic> context,
    );
typedef _AcpReferenceLookup =
    Future<Result<AcpRow>> Function(
      AcpFieldReferenceDescriptor reference,
      String value,
      List<String> extraFilters,
      Map<String, dynamic> context,
    );
typedef _AcpFormSubmit =
    Future<Result<Object?>> Function(Map<String, dynamic> payload);
typedef AcpWorkspaceNavigation =
    Future<void> Function(AcpWorkspaceTarget target);

class AcpAdminPanel<T extends AcpAdminController>
    extends ConsumerStatefulWidget {
  const AcpAdminPanel({
    required this.controllerProvider,
    super.key,
    this.title,
    this.description,
    this.mutationsEnabled = true,
    this.initialResourceKey,
    this.initialTenantId,
    this.initialRowId,
    this.initialFilterValues = const <String, String>{},
    this.onNavigate,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final String? title;
  final String? description;
  final bool mutationsEnabled;
  final String? initialResourceKey;
  final String? initialTenantId;
  final String? initialRowId;
  final Map<String, String> initialFilterValues;
  final AcpWorkspaceNavigation? onNavigate;

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
      final controller = ref.read(widget.controllerProvider.notifier);
      await controller.loadInitialData();
      final tenantId = widget.initialTenantId?.trim();
      if (tenantId != null && tenantId.isNotEmpty) {
        await controller.selectTenant(tenantId);
      }
      final resourceKey = widget.initialResourceKey?.trim();
      if (resourceKey != null &&
          resourceKey.isNotEmpty &&
          controller.descriptors.any((item) => item.key == resourceKey)) {
        await controller.selectResource(resourceKey);
      }
      if (widget.initialFilterValues.isNotEmpty) {
        for (final entry in widget.initialFilterValues.entries) {
          controller.setFilterValue(entry.key, entry.value);
        }
        await controller.loadActiveResource();
      }
      final rowId = widget.initialRowId?.trim();
      if (!mounted || rowId == null || rowId.isEmpty) {
        return;
      }
      final descriptor = controller.activeDescriptor;
      final tenantScope = controller.usesTenantScope(descriptor)
          ? ref.read(widget.controllerProvider).selectedTenantId
          : null;
      final result = await controller.repository.fetchRow(
        descriptor: descriptor,
        rowId: rowId,
        tenantId: tenantScope,
      );
      if (!mounted || result.isFailure) {
        return;
      }
      setState(() {
        _selectedRow = result.data;
        _selectedResourceKey = descriptor.key;
      });
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
    _syncSelectedRow(resourceKey: state.activeResourceKey);
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
          primaryAction: widget.mutationsEnabled && descriptor.allowCreate
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
          mutationsEnabled: widget.mutationsEnabled,
        ),
        if (state.errorMessage != null && state.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppErrorAlert(message: state.errorMessage!),
          ),
        if (resourceState.referenceWarning != null &&
            resourceState.referenceWarning!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppWarningAlert(
              key: const Key('acp-admin-reference-warning'),
              message: resourceState.referenceWarning!,
            ),
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
                  onOpenReference: (row, column) async {
                    final targetResourceKey =
                        column.reference?.targetResourceKey;
                    final targetRouteId = column.reference?.targetRouteId;
                    final targetId = row[column.key]?.toString().trim() ?? '';
                    if (targetResourceKey == null || targetId.isEmpty) {
                      return;
                    }
                    if (targetRouteId != null && widget.onNavigate != null) {
                      await widget.onNavigate!(
                        AcpWorkspaceTarget(
                          routeId: targetRouteId,
                          resourceKey: targetResourceKey,
                          tenantId: row.tenantId ?? state.selectedTenantId,
                          rowId: targetId,
                        ),
                      );
                      return;
                    }
                    await controller.selectResource(targetResourceKey);
                    final result = await controller.fetchRowForMutation(
                      targetId,
                    );
                    if (!mounted || result.isFailure) {
                      return;
                    }
                    setState(() {
                      _selectedRow = result.data;
                      _selectedResourceKey = targetResourceKey;
                    });
                  },
                  mutationsEnabled: widget.mutationsEnabled,
                ),
              );
              final drawer = _selectedRow == null
                  ? null
                  : _AcpRowDetailDrawer(
                      descriptor: descriptor,
                      row: _selectedRow!,
                      onNavigate: (navigation) => _openDetailNavigation(
                        controller: controller,
                        state: state,
                        row: _selectedRow!,
                        navigation: navigation,
                      ),
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

  void _syncSelectedRow({required String resourceKey}) {
    if (_selectedResourceKey != resourceKey) {
      _selectedResourceKey = resourceKey;
      _selectedRow = null;
    }
  }

  Future<void> _openDetailNavigation({
    required T controller,
    required AcpAdminState state,
    required AcpRow row,
    required AcpNavigationDescriptor navigation,
  }) async {
    final value = row[navigation.sourceField]?.toString().trim() ?? '';
    if (value.isEmpty) {
      return;
    }
    final filterKey = navigation.targetFilterKey;
    final target = AcpWorkspaceTarget(
      routeId: navigation.targetRouteId ?? '',
      resourceKey: navigation.targetResourceKey,
      tenantId: row.tenantId ?? state.selectedTenantId,
      rowId: filterKey == null ? value : null,
      filterValues: filterKey == null
          ? const <String, String>{}
          : <String, String>{filterKey: value},
    );
    if (navigation.targetRouteId != null && widget.onNavigate != null) {
      await widget.onNavigate!(target);
      return;
    }
    await controller.selectResource(navigation.targetResourceKey);
    if (filterKey != null) {
      controller.setFilterValue(filterKey, value);
      await controller.loadActiveResource();
      if (mounted) {
        setState(() {
          _selectedRow = null;
        });
      }
      return;
    }
    final result = await controller.fetchRowForMutation(value);
    if (!mounted || result.isFailure) {
      return;
    }
    setState(() {
      _selectedRow = result.data;
      _selectedResourceKey = navigation.targetResourceKey;
    });
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
          .where(
            (descriptor) =>
                state.resourceStates[descriptor.key]?.isAvailable == true,
          )
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
  final Map<String, Timer> _filterDebounces = <String, Timer>{};

  @override
  void dispose() {
    _searchDebounce?.cancel();
    for (final timer in _filterDebounces.values) {
      timer.cancel();
    }
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
        if (descriptor.deletedViews.length > 1)
          SizedBox(
            width: 200,
            child: DropdownButtonFormField<AcpDeletedView>(
              key: Key('acp-admin-deleted-view-${descriptor.key}'),
              initialValue: resourceState.deletedView,
              decoration: appFormInputDecoration(
                labelText: 'Lifecycle',
                helpText:
                    'Choose active, archived, or all records for this resource.',
              ),
              items: [
                for (final view in descriptor.deletedViews)
                  DropdownMenuItem<AcpDeletedView>(
                    value: view,
                    child: Text(switch (view) {
                      AcpDeletedView.active => 'Active',
                      AcpDeletedView.all => 'All',
                      AcpDeletedView.archived => 'Archived',
                    }),
                  ),
              ],
              onChanged: (value) {
                if (value != null) {
                  unawaited(controller.setDeletedView(value));
                }
              },
            ),
          ),
        if (descriptor.scopeMode == AcpScopeMode.optional)
          SizedBox(
            width: 220,
            child: DropdownButtonFormField<AcpOptionalScopeSelection>(
              key: const Key('acp-admin-scope-selector'),
              initialValue: resourceState.optionalScopeSelection,
              isExpanded: true,
              decoration: appFormInputDecoration(
                labelText: 'Scope',
                helpText: acpFieldHelpText(
                  key: 'Scope',
                  label: 'Scope',
                  resourceKey: 'AcpAdmin',
                ),
              ),
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
              helpText: acpFieldHelpText(
                key: 'Tenant',
                label: 'Tenant',
                resourceKey: 'AcpAdmin',
              ),
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
                helpText: acpFieldHelpText(
                  key: 'Search',
                  label: 'Search',
                  resourceKey: 'AcpAdmin',
                ),
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
        for (final filter in descriptor.filters)
          SizedBox(
            width: filter.reference == null ? 220 : 320,
            child: filter.reference != null
                ? _AcpToolbarReferenceFilter<T>(
                    key: ValueKey<String>(
                      'acp-admin-filter-${descriptor.key}-${filter.key}',
                    ),
                    controllerProvider: controllerProvider,
                    filter: filter,
                    value: resourceState.filterValues[filter.key] ?? '',
                  )
                : filter.options.isNotEmpty
                ? DropdownButtonFormField<String>(
                    key: ValueKey<String>(
                      'acp-admin-filter-${descriptor.key}-${filter.key}',
                    ),
                    initialValue: resourceState.filterValues[filter.key],
                    isExpanded: true,
                    decoration: appFormInputDecoration(
                      labelText: filter.label,
                      hintText: filter.hintText,
                      helpText: 'Filter ${filter.label.toLowerCase()} exactly.',
                    ),
                    items: <DropdownMenuItem<String>>[
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('All'),
                      ),
                      for (final option in filter.options)
                        DropdownMenuItem<String>(
                          value: option,
                          child: Text(filter.optionLabels[option] ?? option),
                        ),
                    ],
                    onChanged: (value) async {
                      controller.setFilterValue(filter.key, value ?? '');
                      await controller.loadActiveResource();
                    },
                  )
                : TextFormField(
                    key: ValueKey<String>(
                      'acp-admin-filter-${descriptor.key}-${filter.key}',
                    ),
                    initialValue: resourceState.filterValues[filter.key] ?? '',
                    decoration: appFormInputDecoration(
                      labelText: filter.label,
                      hintText: filter.hintText,
                      helpText: 'Filter ${filter.label.toLowerCase()} exactly.',
                    ),
                    onChanged: (value) {
                      _filterDebounces[filter.key]?.cancel();
                      _filterDebounces[filter.key] = Timer(
                        _acpAdminSearchDebounce,
                        () async {
                          controller.setFilterValue(filter.key, value);
                          await controller.loadActiveResource();
                        },
                      );
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

class _AcpToolbarReferenceFilter<T extends AcpAdminController>
    extends ConsumerStatefulWidget {
  const _AcpToolbarReferenceFilter({
    required this.controllerProvider,
    required this.filter,
    required this.value,
    super.key,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpFilterDescriptor filter;
  final String value;

  @override
  ConsumerState<_AcpToolbarReferenceFilter<T>> createState() =>
      _AcpToolbarReferenceFilterState<T>();
}

class _AcpToolbarReferenceFilterState<T extends AcpAdminController>
    extends ConsumerState<_AcpToolbarReferenceFilter<T>> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(covariant _AcpToolbarReferenceFilter<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && _controller.text != widget.value) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reference = widget.filter.reference!;
    return _AcpReferenceField(
      field: AcpFieldDescriptor(
        key: widget.filter.key,
        label: widget.filter.label,
        hintText: widget.filter.hintText,
        reference: reference,
      ),
      controller: _controller,
      search: _referenceSearchFor(
        ref: ref,
        controllerProvider: widget.controllerProvider,
      ),
      lookup: _referenceLookupFor(
        ref: ref,
        controllerProvider: widget.controllerProvider,
      ),
      helpText: 'Filter ${widget.filter.label.toLowerCase()} exactly.',
      helpKey: Key('acp-admin-filter-help-${widget.filter.key}'),
      validator: (_) => null,
      extraFilters: () => reference.extraFilters,
      context: () => const <String, dynamic>{},
      onSelectionChanged: (row) async {
        final value = row?[reference.valueField]?.toString().trim() ?? '';
        final controller = ref.read(widget.controllerProvider.notifier);
        controller.setFilterValue(widget.filter.key, value);
        await controller.loadActiveResource();
      },
    );
  }
}

class _ActionRow<T extends AcpAdminController> extends ConsumerWidget {
  const _ActionRow({
    required this.controllerProvider,
    required this.descriptor,
    required this.tenantMissing,
    required this.mutationsEnabled,
    this.showCreate = true,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final bool tenantMissing;
  final bool showCreate;
  final bool mutationsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!mutationsEnabled) {
      return const SizedBox.shrink();
    }
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
    required this.onOpenReference,
    required this.mutationsEnabled,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpResourceState resourceState;
  final bool isBusy;
  final AcpRow? selectedRow;
  final ValueChanged<AcpRow> onViewRow;
  final Future<void> Function(AcpRow row, AcpColumnDescriptor column)
  onOpenReference;
  final bool mutationsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(controllerProvider.notifier);
    final tenantMissing =
        descriptor.scopeMode == AcpScopeMode.required &&
        (ref.watch(controllerProvider).selectedTenantId == null ||
            ref.watch(controllerProvider).selectedTenantId!.isEmpty);
    final createAction = mutationsEnabled && descriptor.allowCreate
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
            cell: (_, row) {
              final value = _formatCellValue(row: row, column: column);
              final cell = column.presentation == AcpColumnPresentation.status
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: AdminStatusChip(label: value),
                    )
                  : AdminCellText(value, maxLines: 2);
              if (column.reference == null) {
                return cell;
              }
              if (column.reference?.targetResourceKey != null &&
                  row[column.key]?.toString().trim().isNotEmpty == true) {
                return Semantics(
                  label: '${column.label}: $value',
                  button: true,
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: () => onOpenReference(row, column),
                    child: cell,
                  ),
                );
              }
              return Semantics(
                label: '${column.label}: $value',
                excludeSemantics: true,
                child: cell,
              );
            },
          ),
      ],
      actionsBuilder: (context, row) => SizedBox(
        width: actionColumnWidth,
        child: _RowActions<T>(
          controllerProvider: controllerProvider,
          descriptor: descriptor,
          row: row,
          onViewRow: onViewRow,
          mutationsEnabled: mutationsEnabled,
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
      hasActiveFilter:
          resourceState.searchTerm.trim().isNotEmpty ||
          resourceState.filterValues.values.any(
            (value) => value.trim().isNotEmpty,
          ) ||
          resourceState.deletedView != AcpDeletedView.active,
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

  String _formatCellValue({
    required AcpRow row,
    required AcpColumnDescriptor column,
  }) {
    if (column.reference != null) {
      return acpReferenceDisplayValue(row: row, column: column);
    }
    final value = column.valueBuilder?.call(row) ?? row[column.key];
    if (value == null) {
      return '';
    }
    if (column.money && value is int) {
      final minorUnit = switch (row[column.minorUnitKey]) {
        final int value when value >= 0 && value <= 4 => value,
        final Object value => switch (int.tryParse(value.toString())) {
          final int parsed when parsed >= 0 && parsed <= 4 => parsed,
          _ => null,
        },
        _ => null,
      };
      final currency = row[column.currencyCodeKey]?.toString().trim() ?? '';
      if (minorUnit == null) {
        final prefix = currency.isEmpty ? '' : '$currency ';
        return '$prefix$value minor units (currency precision unavailable)';
      }
      final formatted = AcpMoneyCodec.formatMinorUnits(
        value,
        minorUnit: minorUnit,
      );
      return currency.isEmpty ? formatted : '$currency $formatted';
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
    required this.mutationsEnabled,
  });

  final StateNotifierProvider<T, AcpAdminState> controllerProvider;
  final AcpResourceDescriptor descriptor;
  final AcpRow row;
  final ValueChanged<AcpRow> onViewRow;
  final bool mutationsEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rowId = row.id;
    final rowButtonActions = mutationsEnabled
        ? <_RowMenuAction>[
            for (final action in descriptor.collectionActions)
              if (action.showInRowMenu &&
                  action.showAsRowButton &&
                  action.isVisibleFor(row))
                _RowMenuAction.collection(
                  action: action,
                  initialValues: _collectionActionInitialValues(
                    action: action,
                    row: row,
                  ),
                ),
          ]
        : const <_RowMenuAction>[];
    final rowMenuActions = mutationsEnabled
        ? <_RowMenuAction>[
            for (final action in descriptor.collectionActions)
              if (action.showInRowMenu &&
                  !action.showAsRowButton &&
                  action.isVisibleFor(row))
                _RowMenuAction.collection(
                  action: action,
                  initialValues: _collectionActionInitialValues(
                    action: action,
                    row: row,
                  ),
                ),
            if (rowId != null)
              for (final action in descriptor.entityActions)
                if (action.isVisibleFor(row) &&
                    !(action.name == 'archive' && row['DeletedAt'] != null))
                  _RowMenuAction.entity(action: action),
          ]
        : const <_RowMenuAction>[];

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
            if (mutationsEnabled && descriptor.canUpdate(row) && rowId != null)
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
            if (mutationsEnabled && descriptor.allowDelete && rowId != null)
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
            if (mutationsEnabled &&
                descriptor.allowRestore &&
                rowId != null &&
                row['DeletedAt'] != null)
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
  Result<Object?>? mutationResult;
  String? createdRowId;
  int? createdRowVersion;
  var createdWithoutIdentifier = false;
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
    payloadValidator: descriptor.payloadValidator,
    resourceKey: descriptor.key,
    entitySet: descriptor.entitySet,
    onSubmit: (payload) async {
      final split = _splitCreatePayload(
        payload: payload,
        fields: descriptor.createFields,
      );
      final controller = ref.read(controllerProvider.notifier);
      if (createdWithoutIdentifier) {
        return const Result<Object?>.failure(
          UnexpectedFailure(
            'The row was created, but the server did not return its identifier. '
            'Close this form, refresh, and edit the new row to apply the remaining fields.',
          ),
        );
      }
      if (createdRowId == null) {
        final createResult = await controller.createRow(
          split.initialValues,
          deferRefresh: split.postCreateValues.isNotEmpty,
        );
        mutationResult = createResult;
        if (createResult.isFailure || split.postCreateValues.isEmpty) {
          return _formMutationResult(controller, createResult);
        }
        final created = createResult.data;
        if (created is Map) {
          final row = Map<String, dynamic>.from(created);
          createdRowId = row.id;
          createdRowVersion = row.rowVersion;
        }
        if (createdRowId == null) {
          createdWithoutIdentifier = true;
          mutationResult = const Result<Object?>.failure(
            UnexpectedFailure(
              'The row was created, but the server did not return its identifier. '
              'Close this form, refresh, and edit the new row to apply the remaining fields.',
            ),
          );
          return mutationResult!;
        }
      }

      if (createdRowVersion == null) {
        final refreshResult = await controller.fetchRowForMutation(
          createdRowId!,
        );
        createdRowVersion = refreshResult.data?.rowVersion;
        if (refreshResult.isFailure || createdRowVersion == null) {
          final detail = refreshResult.failure?.message.trim() ?? '';
          mutationResult = Result<Object?>.failure(
            UnexpectedFailure(
              'The row was created, but its current RowVersion could not be loaded. '
              'Your input is retained; retry to fetch the created row and apply '
              'the remaining fields without creating another row.'
              '${detail.isEmpty ? '' : ' $detail'}',
            ),
          );
          return mutationResult!;
        }
      }

      final updateResult = await controller.updateRow(
        rowId: createdRowId!,
        values: split.postCreateValues,
        rowVersion: createdRowVersion,
      );
      if (updateResult.isFailure && _isConflictFailure(updateResult.failure)) {
        createdRowVersion = controller.rowById(createdRowId!)?.rowVersion;
      }
      mutationResult = updateResult;
      return _formMutationResult(controller, updateResult);
    },
  );
  if (payload == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: mutationResult!,
    successMessage: 'Created successfully.',
  );
}

bool _isConflictFailure(Failure? failure) {
  return failure is ConflictFailure ||
      (failure is ApiFailure && failure.statusCode == 409);
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

  Result<Object?>? mutationResult;
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
    payloadValidator: descriptor.payloadValidator,
    resourceKey: descriptor.key,
    entitySet: descriptor.entitySet,
    initialValues: row,
    onSubmit: (payload) async {
      final controller = ref.read(controllerProvider.notifier);
      final latestRow = controller.rowById(rowId) ?? row;
      final result = await controller.updateRow(
        rowId: rowId,
        values: payload,
        tenantIdOverride: row.tenantId,
        useTenantIdOverride: _usesRowTenantScope(
          descriptor: descriptor,
          row: row,
        ),
        rowVersion: latestRow.rowVersion,
      );
      mutationResult = result;
      return _formMutationResult(controller, result);
    },
  );
  if (payload == null) {
    return;
  }
  if (!context.mounted) {
    return;
  }
  await _handleObjectMutationResult(
    context: context,
    ref: ref,
    result: mutationResult!,
    successMessage: 'Updated successfully.',
  );
}

Result<Object?> _formMutationResult(
  AcpAdminController controller,
  Result<Object?> result,
) {
  if (result.isSuccess) {
    return result;
  }
  return Result<Object?>.failure(
    UnexpectedFailure(
      controller.errorMessage ??
          result.failure?.message ??
          'The operation could not be completed.',
    ),
  );
}

class _CreatePayloadSplit {
  const _CreatePayloadSplit({
    required this.initialValues,
    required this.postCreateValues,
  });

  final Map<String, dynamic> initialValues;
  final Map<String, dynamic> postCreateValues;
}

_CreatePayloadSplit _splitCreatePayload({
  required Map<String, dynamic> payload,
  required List<AcpFieldDescriptor> fields,
}) {
  final postCreateKeys = fields
      .where((field) => field.applyAfterCreate)
      .map((field) => field.payloadContainerKey ?? field.key)
      .toSet();
  return _CreatePayloadSplit(
    initialValues: <String, dynamic>{
      for (final entry in payload.entries)
        if (!postCreateKeys.contains(entry.key)) entry.key: entry.value,
    },
    postCreateValues: <String, dynamic>{
      for (final entry in payload.entries)
        if (postCreateKeys.contains(entry.key)) entry.key: entry.value,
    },
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
  if (action.fields.isNotEmpty) {
    Result<Object?>? mutationResult;
    final payload = await _showDynamicFormDialog(
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
      payloadValidator: action.payloadValidator,
      resourceKey: descriptor.key,
      entitySet: descriptor.entitySet,
      actionName: action.name,
      initialValues: initialValues,
      confirmMessage: action.confirmationFor(scopeRow),
      confirmIcon: action.icon,
      onSubmit: (payload) async {
        final controller = ref.read(controllerProvider.notifier);
        final result = await controller.runCollectionAction(
          action: action,
          values: payload,
          tenantIdOverride: scopeRow?.tenantId,
          useTenantIdOverride: _usesRowTenantScope(
            descriptor: descriptor,
            row: scopeRow,
          ),
        );
        mutationResult = result;
        return _formMutationResult(controller, result);
      },
    );
    if (payload == null || !context.mounted) {
      return;
    }
    await _handleObjectMutationResult(
      context: context,
      ref: ref,
      result: mutationResult!,
      successMessage: action.successMessageFor(mutationResult!.data),
      showResult: true,
    );
    return;
  }

  final confirmMessage = action.confirmationFor(scopeRow);
  if (confirmMessage != null) {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: confirmMessage,
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
        values: const <String, dynamic>{},
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
    successMessage: action.successMessageFor(result.data),
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

  if (action.fields.isNotEmpty) {
    Result<Object?>? mutationResult;
    final payload = await _showDynamicFormDialog(
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
      payloadValidator: action.payloadValidator,
      resourceKey: descriptor.key,
      entitySet: descriptor.entitySet,
      actionName: action.name,
      initialValues: row,
      confirmMessage: action.confirmationFor(row),
      confirmIcon: action.icon,
      onSubmit: (payload) async {
        final controller = ref.read(controllerProvider.notifier);
        final latestRow = controller.rowById(rowId) ?? row;
        final result = await controller.runEntityAction(
          action: action,
          rowId: rowId,
          values: payload,
          tenantIdOverride: row.tenantId,
          useTenantIdOverride: _usesRowTenantScope(
            descriptor: descriptor,
            row: row,
          ),
          rowVersion: action.includeRowVersion ? latestRow.rowVersion : null,
        );
        mutationResult = result;
        return _formMutationResult(controller, result);
      },
    );
    if (payload == null || !context.mounted) {
      return;
    }
    await _handleObjectMutationResult(
      context: context,
      ref: ref,
      result: mutationResult!,
      successMessage: action.successMessageFor(mutationResult!.data),
      showResult: true,
    );
    return;
  }

  final confirmMessage = action.confirmationFor(row);
  if (confirmMessage != null) {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: action.label,
      message: confirmMessage,
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
        values: const <String, dynamic>{},
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
    successMessage: action.successMessageFor(result.data),
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
  _AcpFormSubmit? onSubmit,
  AcpPayloadValidator? payloadValidator,
  String? confirmMessage,
  IconData? confirmIcon,
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
      onSubmit: onSubmit,
      payloadValidator: payloadValidator,
      confirmMessage: confirmMessage,
      confirmIcon: confirmIcon,
    ),
  );
}

_AcpReferenceSearch _referenceSearchFor<T extends AcpAdminController>({
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  String? tenantIdOverride,
  bool useTenantIdOverride = false,
}) {
  return (reference, searchTerm, dynamicFilters, context) {
    final state = ref.read(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final tenantId = _referenceTenantIdFor(
      reference: reference,
      state: state,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
      useSelectedTenantScope: controller.usesTenantScope(
        controller.activeDescriptor,
      ),
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
        expansions: reference.expansions,
        referenceContext: context,
      ),
      pageRequest: PageRequest(page: 1, pageSize: reference.pageSize),
      tenantId: tenantId,
      searchTerm: searchTerm,
      extraFilters: <String>[...reference.extraFilters, ...dynamicFilters],
    );
  };
}

_AcpReferenceLookup _referenceLookupFor<T extends AcpAdminController>({
  required WidgetRef ref,
  required StateNotifierProvider<T, AcpAdminState> controllerProvider,
  String? tenantIdOverride,
  bool useTenantIdOverride = false,
}) {
  return (reference, value, dynamicFilters, context) async {
    final state = ref.read(controllerProvider);
    final controller = ref.read(controllerProvider.notifier);
    final tenantId = _referenceTenantIdFor(
      reference: reference,
      state: state,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
      useSelectedTenantScope: controller.usesTenantScope(
        controller.activeDescriptor,
      ),
    );

    final descriptor = AcpResourceDescriptor(
      key: 'reference-${reference.entitySet}',
      title: reference.title,
      entitySet: reference.entitySet,
      scopeMode: reference.scopeMode,
      columns: const <AcpColumnDescriptor>[],
      defaultOrderBy: reference.defaultOrderBy,
      expansions: reference.expansions,
      referenceContext: context,
    );
    if (reference.valueField == reference.idField &&
        (reference.retainHistoricalSelection ||
            (reference.extraFilters.isEmpty && dynamicFilters.isEmpty))) {
      return controller.repository.fetchRow(
        descriptor: descriptor,
        rowId: value,
        tenantId: tenantId,
      );
    }

    final result = await controller.repository.listRows(
      descriptor: descriptor,
      pageRequest: const PageRequest(page: 1, pageSize: 1),
      tenantId: tenantId,
      extraFilters: <String>[
        ...reference.extraFilters,
        ...dynamicFilters,
        "${reference.valueField} eq '${_escapeODataString(value)}'",
      ],
    );
    if (result.isFailure) {
      return Result<AcpRow>.failure(result.failure!);
    }
    final rows = result.data?.items ?? const <AcpRow>[];
    if (rows.isEmpty) {
      return Result<AcpRow>.failure(
        UnexpectedFailure('${reference.title} reference was not found.'),
      );
    }
    return Result<AcpRow>.success(rows.first);
  };
}

String _escapeODataString(String value) => value.replaceAll("'", "''");

List<String> _decodeStringList(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return const <String>[];
  }
  try {
    final decoded = jsonDecode(trimmed);
    if (decoded is List) {
      return decoded
          .map((value) => value.toString().trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
  } catch (_) {
    // A comma-separated operator entry is also supported.
  }
  return trimmed
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);
}

List<int>? _decodeIntegerList(String raw) {
  final values = _decodeStringList(raw);
  final parsed = <int>[];
  for (final value in values) {
    final integer = int.tryParse(value);
    if (integer == null) {
      return null;
    }
    parsed.add(integer);
  }
  return parsed;
}

DateTime? _decodeDateTime(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  return DateTime.tryParse(trimmed)?.toUtc();
}

TimeOfDay? _decodeTimeOfDay(String raw) {
  final match = RegExp(
    r'^(?<hour>[01]\d|2[0-3]):(?<minute>[0-5]\d)(?::[0-5]\d(?:\.\d{1,6})?)?$',
  ).firstMatch(raw.trim());
  if (match == null) {
    return null;
  }
  return TimeOfDay(
    hour: int.parse(match.namedGroup('hour')!),
    minute: int.parse(match.namedGroup('minute')!),
  );
}

List<DateTime>? _decodeDateList(String raw) {
  final values = _decodeStringList(raw);
  final byDate = <String, DateTime>{};
  for (final value in values) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime.utc(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    byDate[value] = date;
  }
  final dates = byDate.values.toList()..sort();
  return dates;
}

String _formatDateOnly(DateTime value) {
  final utc = value.toUtc();
  String twoDigits(int part) => part.toString().padLeft(2, '0');
  return '${utc.year.toString().padLeft(4, '0')}-${twoDigits(utc.month)}-${twoDigits(utc.day)}';
}

String _formatTimeOfDay(TimeOfDay value) =>
    '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

String? _referenceTenantIdFor({
  required AcpFieldReferenceDescriptor reference,
  required AcpAdminState state,
  required String? tenantIdOverride,
  required bool useTenantIdOverride,
  required bool useSelectedTenantScope,
}) {
  if (reference.scopeMode == AcpScopeMode.none) {
    return null;
  }

  if (!useTenantIdOverride &&
      reference.scopeMode == AcpScopeMode.optional &&
      !useSelectedTenantScope) {
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
    required this.onNavigate,
  });

  final AcpResourceDescriptor descriptor;
  final AcpRow row;
  final VoidCallback onClose;
  final Future<void> Function(AcpNavigationDescriptor navigation) onNavigate;

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
            if (descriptor.detailSections.isEmpty)
              for (final entry in row.entries)
                _AcpDetailField(label: entry.key, value: entry.value)
            else
              for (final section in descriptor.detailSections) ...[
                Text(
                  section.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final field in section.fields)
                  _AcpDetailField(
                    label: field.label,
                    value: row[field.key],
                    presentation: field.presentation,
                  ),
                for (final link in section.links)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      key: Key(
                        'acp-detail-link-${descriptor.key}-${link.targetResourceKey}',
                      ),
                      onPressed:
                          (row[link.sourceField]?.toString().trim() ?? '')
                              .isEmpty
                          ? null
                          : () => onNavigate(link),
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: Text(link.label),
                    ),
                  ),
                const SizedBox(height: 12),
              ],
          ],
        ),
      ),
    );
  }
}

class _AcpDetailField extends StatelessWidget {
  const _AcpDetailField({
    required this.label,
    required this.value,
    this.presentation = AcpColumnPresentation.text,
  });

  final String label;
  final Object? value;
  final AcpColumnPresentation presentation;

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
            child: presentation == AcpColumnPresentation.status
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: AdminStatusChip(label: text),
                  )
                : Text(text, maxLines: 8, overflow: TextOverflow.ellipsis),
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
    required this.extraFilters,
    required this.context,
    required this.onSelectionChanged,
    super.key,
  });

  final AcpFieldDescriptor field;
  final TextEditingController controller;
  final _AcpReferenceSearch search;
  final _AcpReferenceLookup lookup;
  final String helpText;
  final Key helpKey;
  final FormFieldValidator<String> validator;
  final List<String> Function() extraFilters;
  final Map<String, dynamic> Function() context;
  final ValueChanged<AcpRow?> onSelectionChanged;

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
            final disabledReasonField = _reference.disabledReasonField;
            final disabledReason = disabledReasonField == null
                ? ''
                : row[disabledReasonField]?.toString().trim() ?? '';
            return ListTile(
              key: Key('acp-reference-option-${widget.field.key}-$value'),
              enabled: value.isNotEmpty && disabledReason.isEmpty,
              selected: isSelected,
              leading: Icon(
                isSelected ? Icons.check_circle_outline : Icons.link_outlined,
              ),
              title: Text(_referenceTitle(row)),
              subtitle: Text(
                disabledReason.isEmpty
                    ? _referenceSubtitle(row)
                    : '${_referenceSubtitle(row)}  |  $disabledReason',
              ),
              onTap: value.isEmpty || disabledReason.isNotEmpty
                  ? null
                  : () => _selectRow(row, fieldState),
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

    final response = await widget.search(
      _reference,
      term,
      widget.extraFilters(),
      widget.context(),
    );
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

    final response = await widget.lookup(
      _reference,
      selectedValue,
      widget.extraFilters(),
      widget.context(),
    );
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
    widget.onSelectionChanged(selectedRow);
  }

  void _selectRow(AcpRow row, FormFieldState<String> fieldState) {
    final value = _referenceValue(row);
    setState(() {
      _selectedRow = row;
      widget.controller.text = value;
    });
    fieldState.didChange(value);
    fieldState.validate();
    widget.onSelectionChanged(row);
  }

  void _clearSelection(FormFieldState<String> fieldState) {
    setState(() {
      _selectedRow = null;
      widget.controller.clear();
    });
    fieldState.didChange('');
    fieldState.validate();
    widget.onSelectionChanged(null);
  }

  String _referenceValue(AcpRow row) {
    return row[_reference.valueField]?.toString().trim() ?? '';
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

class _AcpMultiReferenceField extends StatefulWidget {
  const _AcpMultiReferenceField({
    required this.field,
    required this.controller,
    required this.search,
    required this.extraFilters,
    required this.context,
    required this.helpText,
    required this.helpKey,
    required this.validator,
    super.key,
  });

  final AcpFieldDescriptor field;
  final TextEditingController controller;
  final _AcpReferenceSearch search;
  final List<String> Function() extraFilters;
  final Map<String, dynamic> Function() context;
  final String helpText;
  final Key helpKey;
  final FormFieldValidator<String> validator;

  @override
  State<_AcpMultiReferenceField> createState() =>
      _AcpMultiReferenceFieldState();
}

class _AcpMultiReferenceFieldState extends State<_AcpMultiReferenceField> {
  late final TextEditingController _searchController;
  late final List<String> _selectedValues;
  Timer? _searchDebounce;
  int _searchGeneration = 0;
  bool _isSearching = false;
  bool _hasSearched = false;
  String? _searchError;
  List<AcpRow> _results = const <AcpRow>[];

  AcpFieldReferenceDescriptor get _reference => widget.field.reference!;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedValues = _decodeStringList(widget.controller.text).toList();
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
                hintText: widget.field.hintText ?? 'Search and select records',
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
            if (_selectedValues.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final value in _selectedValues)
                    InputChip(
                      key: Key(
                        'acp-reference-selected-${widget.field.key}-$value',
                      ),
                      label: Text(value),
                      onDeleted: widget.field.readOnly
                          ? null
                          : () => _toggleValue(value, fieldState),
                    ),
                ],
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

  Widget _buildResults(FormFieldState<String> fieldState) {
    if (_results.isEmpty) {
      return const Text('No matching records found.');
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
            final value = row[_reference.valueField]?.toString().trim() ?? '';
            final selected = _selectedValues.contains(value);
            return CheckboxListTile(
              key: Key('acp-reference-option-${widget.field.key}-$value'),
              value: selected,
              title: Text(_referenceRowTitle(row)),
              subtitle: Text(value),
              onChanged: value.isEmpty || widget.field.readOnly
                  ? null
                  : (_) => _toggleValue(value, fieldState),
            );
          },
        ),
      ),
    );
  }

  String _referenceRowTitle(AcpRow row) {
    for (final field in _reference.titleFields) {
      final value = row[field]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return row[_reference.valueField]?.toString() ?? 'Untitled reference';
  }

  void _toggleValue(String value, FormFieldState<String> fieldState) {
    setState(() {
      if (_selectedValues.contains(value)) {
        _selectedValues.remove(value);
      } else {
        _selectedValues.add(value);
      }
      widget.controller.text = jsonEncode(_selectedValues);
    });
    fieldState.didChange(widget.controller.text);
    fieldState.validate();
  }

  void _queueSearch(String value) {
    _searchDebounce?.cancel();
    final term = value.trim();
    if (term.length < 2) {
      setState(() {
        _isSearching = false;
        _hasSearched = term.isNotEmpty;
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
    final response = await widget.search(
      _reference,
      term,
      widget.extraFilters(),
      widget.context(),
    );
    if (!mounted || generation != _searchGeneration) {
      return;
    }
    setState(() {
      _isSearching = false;
      _results = response.data?.items ?? const <AcpRow>[];
      _searchError = response.failure?.message;
    });
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
    required this.onSubmit,
    required this.payloadValidator,
    required this.confirmMessage,
    required this.confirmIcon,
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
  final _AcpFormSubmit? onSubmit;
  final AcpPayloadValidator? payloadValidator;
  final String? confirmMessage;
  final IconData? confirmIcon;

  @override
  State<_AcpDynamicFormDialog> createState() => _AcpDynamicFormDialogState();
}

class _AcpDynamicFormDialogState extends State<_AcpDynamicFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _textControllers;
  late final Map<String, TextEditingController> _optionEntryControllers;
  late final Map<String, bool> _boolValues;
  late final Map<String, int> _initialMoneyValues;
  String? _formErrorText;
  bool _isSubmitting = false;
  bool _isConfirming = false;

  @override
  void initState() {
    super.initState();
    _initialMoneyValues = <String, int>{
      for (final field in widget.fields)
        if (field.kind == AcpFieldKind.money &&
            _initialFieldValue(field) is int)
          field.key: _initialFieldValue(field)! as int,
    };
    _textControllers = <String, TextEditingController>{
      for (final field in widget.fields)
        if (field.kind != AcpFieldKind.boolean)
          field.key: TextEditingController(
            text: _initialTextValue(field, _initialFieldValue(field)),
          ),
    };
    _optionEntryControllers = <String, TextEditingController>{
      for (final field in widget.fields)
        if (field.multiSelectOptions) field.key: TextEditingController(),
    };
    _boolValues = <String, bool>{
      for (final field in widget.fields)
        if (field.kind == AcpFieldKind.boolean)
          field.key: _initialBoolValue(_initialFieldValue(field)),
    };
    _reformatInitialMoneyFields();
  }

  @override
  void dispose() {
    for (final controller in _textControllers.values) {
      controller.dispose();
    }
    for (final controller in _optionEntryControllers.values) {
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
                  .where((field) => !field.hidden && _isFieldVisible(field))
                  .map((field) => _buildField(context, field))
                  .expand((widget) => [widget, const SizedBox(height: 10)])
                  .toList(growable: false),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting || _isConfirming
              ? null
              : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isSubmitting || _isConfirming ? null : _submit,
          child: _isSubmitting
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isConfirming ? 'Confirm in dialog' : widget.submitLabel),
        ),
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
    if (field.kind == AcpFieldKind.computed) {
      final values = <String, String>{
        for (final item in widget.fields)
          item.key: _currentFieldValue(item.key) ?? '',
      };
      return Container(
        key: Key('acp-dynamic-field-${field.key}'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppUiPalette.surfaceStrong,
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(field.label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(field.computedValueBuilder?.call(values) ?? ''),
          ],
        ),
      );
    }
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
                    _clearNewlyHiddenFields();
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
      List<String> extraFilters() => _referenceFilters(field.reference!);
      Map<String, dynamic> referenceContext() =>
          _referenceContext(field.reference!);
      if (field.reference!.multiSelect) {
        return _AcpMultiReferenceField(
          key: Key('acp-dynamic-field-${field.key}'),
          field: field,
          controller: controller,
          search: widget.referenceSearch!,
          extraFilters: extraFilters,
          context: referenceContext,
          helpText: helpText,
          helpKey: helpKey,
          validator: (value) => _validateField(field, value ?? ''),
        );
      }
      return _AcpReferenceField(
        key: Key('acp-dynamic-field-${field.key}'),
        field: field,
        controller: controller,
        search: widget.referenceSearch!,
        lookup: widget.referenceLookup!,
        helpText: helpText,
        helpKey: helpKey,
        validator: (value) => _validateField(field, value ?? ''),
        extraFilters: extraFilters,
        context: referenceContext,
        onSelectionChanged: (row) => _applyReferenceSelection(field, row),
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

    if (field.kind == AcpFieldKind.dateTime) {
      return AppDateTimeFormField(
        key: Key('acp-dynamic-field-${field.key}'),
        labelText: field.label,
        hintText: field.hintText ?? 'Select a UTC date and time',
        helpText: helpText,
        helpKey: helpKey,
        pickerButtonKey: Key('acp-dynamic-field-${field.key}-picker'),
        clearButtonKey: Key('acp-dynamic-field-${field.key}-clear'),
        value: _decodeDateTime(controller.text),
        diagnosticValue: controller.text,
        required: _isRequired(field),
        enabled: !field.readOnly,
        readOnly: field.readOnly,
        validator: (_) => _validateField(field, controller.text),
        onChanged: (value) {
          setState(() {
            controller.text = value?.toUtc().toIso8601String() ?? '';
            _clearNewlyHiddenFields();
          });
        },
      );
    }

    if (field.kind == AcpFieldKind.timeOfDay) {
      return AppTimeOfDayFormField(
        key: Key('acp-dynamic-field-${field.key}'),
        labelText: field.label,
        hintText: field.hintText ?? 'Select a time',
        helpText: helpText,
        helpKey: helpKey,
        pickerButtonKey: Key('acp-dynamic-field-${field.key}-picker'),
        clearButtonKey: Key('acp-dynamic-field-${field.key}-clear'),
        value: _decodeTimeOfDay(controller.text),
        diagnosticValue: controller.text,
        required: _isRequired(field),
        enabled: !field.readOnly,
        readOnly: field.readOnly,
        validator: (_) => _validateField(field, controller.text),
        onChanged: (value) {
          setState(() {
            controller.text = value == null ? '' : _formatTimeOfDay(value);
            _clearNewlyHiddenFields();
          });
        },
      );
    }

    if (field.kind == AcpFieldKind.dateList) {
      return AppDateListFormField(
        key: Key('acp-dynamic-field-${field.key}'),
        labelText: field.label,
        hintText: field.hintText ?? 'Add one or more dates',
        helpText: helpText,
        helpKey: helpKey,
        pickerButtonKey: Key('acp-dynamic-field-${field.key}-picker'),
        clearButtonKey: Key('acp-dynamic-field-${field.key}-clear'),
        values: _decodeDateList(controller.text) ?? const <DateTime>[],
        diagnosticValue: controller.text,
        required: _isRequired(field),
        enabled: !field.readOnly,
        readOnly: field.readOnly,
        validator: (_) => _validateField(field, controller.text),
        onChanged: (values) {
          setState(() {
            controller.text = values.isEmpty
                ? ''
                : jsonEncode(values.map(_formatDateOnly).toList());
            _clearNewlyHiddenFields();
          });
        },
      );
    }

    final optionValues = _optionValuesFor(field);
    if (field.multiSelectOptions) {
      return _buildMultiOptionField(
        field: field,
        controller: controller,
        options: optionValues,
        helpText: helpText,
        helpKey: helpKey,
      );
    }

    if (field.searchableOptions || field.optionsBuilder != null) {
      return _buildSearchableOptionField(
        field: field,
        controller: controller,
        options: optionValues,
        helpText: helpText,
        helpKey: helpKey,
      );
    }

    if (optionValues.isNotEmpty) {
      final options = _dropdownOptionsFor(controller.text, optionValues);
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
                child: Text(
                  _optionLabel(field, option),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        onChanged: field.readOnly
            ? null
            : (value) {
                setState(() {
                  controller.text = value ?? '';
                  _clearNewlyHiddenFields();
                });
              },
        validator: (value) => _validateField(field, value ?? ''),
      );
    }

    final isMultiline =
        field.kind == AcpFieldKind.multiline ||
        field.kind == AcpFieldKind.stringList ||
        field.kind == AcpFieldKind.integerList;

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
      onChanged: (_) => setState(_clearNewlyHiddenFields),
    );
  }

  Widget _buildSearchableOptionField({
    required AcpFieldDescriptor field,
    required TextEditingController controller,
    required List<String> options,
    required String helpText,
    required Key helpKey,
  }) {
    return Autocomplete<String>(
      key: Key('acp-dynamic-field-${field.key}'),
      initialValue: TextEditingValue(
        text: options.contains(controller.text)
            ? _optionLabel(field, controller.text)
            : controller.text,
      ),
      displayStringForOption: (option) => _optionLabel(field, option),
      optionsBuilder: (value) {
        final query = value.text.trim().toLowerCase();
        if (query.isEmpty) {
          return options;
        }
        return options.where((option) {
          final label = _optionLabel(field, option).toLowerCase();
          return option.toLowerCase().contains(query) || label.contains(query);
        });
      },
      onSelected: (option) {
        setState(() {
          controller.text = option;
          _clearNewlyHiddenFields();
        });
      },
      fieldViewBuilder: (context, textController, focusNode, onFieldSubmitted) {
        return TextFormField(
          key: Key('acp-searchable-option-${field.key}'),
          controller: textController,
          focusNode: focusNode,
          readOnly: field.readOnly,
          decoration: appFormInputDecoration(
            labelText: field.label,
            hintText: field.hintText,
            suffixIcon: const Icon(Icons.manage_search_outlined),
            helpText: helpText,
            helpKey: helpKey,
            errorMaxLines: 4,
          ),
          validator: (value) => _validateField(
            field,
            _optionValueForInput(field, value ?? '', options),
          ),
          onChanged: (value) {
            controller.text = _optionValueForInput(field, value, options);
            setState(_clearNewlyHiddenFields);
          },
          onFieldSubmitted: (_) => onFieldSubmitted(),
        );
      },
    );
  }

  Widget _buildMultiOptionField({
    required AcpFieldDescriptor field,
    required TextEditingController controller,
    required List<String> options,
    required String helpText,
    required Key helpKey,
  }) {
    return FormField<String>(
      key: Key('acp-dynamic-field-${field.key}'),
      initialValue: controller.text,
      validator: (value) => _validateField(field, value ?? ''),
      builder: (fieldState) {
        final selected = _decodeStringList(controller.text).toSet();
        void update(String option, bool include) {
          setState(() {
            if (include) {
              selected.add(option);
            } else {
              selected.remove(option);
            }
            controller.text = jsonEncode(selected.toList(growable: false));
          });
          fieldState.didChange(controller.text);
          fieldState.validate();
        }

        void addCustom() {
          final entryController = _optionEntryControllers[field.key]!;
          final value = entryController.text.trim();
          if (value.isEmpty) {
            return;
          }
          update(value, true);
          entryController.clear();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            appFieldLabelWithHelp(
              labelText: field.label,
              helpText: helpText,
              helpKey: helpKey,
            ),
            if (field.hintText != null) ...[
              const SizedBox(height: 4),
              Text(field.hintText!),
            ],
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in options)
                  FilterChip(
                    key: Key('acp-option-${field.key}-$option'),
                    label: Text(_optionLabel(field, option)),
                    selected: selected.contains(option),
                    onSelected: field.readOnly
                        ? null
                        : (value) => update(option, value),
                  ),
                for (final value in selected.where(
                  (value) => !options.contains(value),
                ))
                  InputChip(
                    key: Key('acp-custom-option-${field.key}-$value'),
                    label: Text(value),
                    onDeleted: field.readOnly
                        ? null
                        : () => update(value, false),
                  ),
              ],
            ),
            if (field.allowCustomOption && !field.readOnly) ...[
              const SizedBox(height: 8),
              TextFormField(
                key: Key('acp-custom-option-entry-${field.key}'),
                controller: _optionEntryControllers[field.key],
                decoration: appFormInputDecoration(
                  labelText: 'Add custom ${field.label.toLowerCase()}',
                  helpText:
                      'Enter an additional value when it is not listed above.',
                  suffixIcon: IconButton(
                    tooltip: 'Add custom ${field.label.toLowerCase()}',
                    onPressed: addCustom,
                    icon: const Icon(Icons.add),
                  ),
                ),
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => addCustom(),
              ),
            ],
            if (fieldState.errorText != null) ...[
              const SizedBox(height: 6),
              AppErrorAlert(message: fieldState.errorText!),
            ],
          ],
        );
      },
    );
  }

  void _applyReferenceSelection(AcpFieldDescriptor field, AcpRow? row) {
    final reference = field.reference;
    if (reference == null) {
      return;
    }
    setState(() {
      for (final entry in reference.copyFieldsFromSelection.entries) {
        final target = _textControllers[entry.value];
        if (target == null) {
          continue;
        }
        target.text = row?[entry.key]?.toString() ?? '';
      }
      _reformatInitialMoneyFields();
      _clearNewlyHiddenFields();
    });
  }

  Map<String, dynamic> _referenceContext(
    AcpFieldReferenceDescriptor reference,
  ) {
    return <String, dynamic>{
      for (final entry in reference.contextFieldsFromForm.entries)
        if ((_currentFieldValue(entry.value) ?? '').trim().isNotEmpty)
          entry.key: _currentFieldValue(entry.value)!.trim(),
    };
  }

  void _reformatInitialMoneyFields() {
    for (final entry in _initialMoneyValues.entries) {
      final field = widget.fields.firstWhere((item) => item.key == entry.key);
      final controller = _textControllers[entry.key];
      if (controller == null) {
        continue;
      }
      final minorUnit = _resolvedMinorUnitFor(field);
      if (minorUnit == null) {
        controller.clear();
        continue;
      }
      controller.text = AcpMoneyCodec.formatMinorUnits(
        entry.value,
        minorUnit: minorUnit,
      );
    }
  }

  void _clearNewlyHiddenFields() {
    for (final field in widget.fields) {
      if (!field.clearWhenHidden || _isFieldVisible(field)) {
        continue;
      }
      _textControllers[field.key]?.clear();
      if (_boolValues.containsKey(field.key)) {
        _boolValues[field.key] = false;
      }
    }
  }

  Object? _initialFieldValue(AcpFieldDescriptor field) {
    if (widget.initialValues.containsKey(field.key)) {
      return _withoutExcludedJsonKeys(
        widget.initialValues[field.key],
        field.excludedJsonKeys,
      );
    }
    final containerKey = field.payloadContainerKey;
    final mapKey = field.payloadMapKey;
    if (containerKey != null && mapKey != null) {
      final container = widget.initialValues[containerKey];
      if (container is Map) {
        return container[mapKey];
      }
    }
    return field.initialValueFactory?.call() ?? field.initialValue;
  }

  Object? _withoutExcludedJsonKeys(Object? value, List<String> excludedKeys) {
    if (value is! Map || excludedKeys.isEmpty) {
      return value;
    }
    return <String, dynamic>{
      for (final entry in value.entries)
        if (!excludedKeys.contains(entry.key.toString()))
          entry.key.toString(): entry.value,
    };
  }

  bool _isFieldVisible(AcpFieldDescriptor field) {
    for (final entry in field.visibleWhenEquals.entries) {
      final actual = _currentFieldValue(entry.key);
      if (!entry.value.any(
        (expected) =>
            actual?.trim().toLowerCase() ==
            expected.toString().trim().toLowerCase(),
      )) {
        return false;
      }
    }
    return true;
  }

  List<String> _referenceFilters(AcpFieldReferenceDescriptor reference) {
    final filters = <String>[];
    for (final entry in reference.filterFieldsFromForm.entries) {
      final value = _currentFieldValue(entry.value)?.trim();
      if (value == null || value.isEmpty) {
        continue;
      }
      filters.add("${entry.key} eq '${_escapeODataString(value)}'");
    }
    return filters;
  }

  String? _validateField(AcpFieldDescriptor field, String value) {
    final trimmed = value.trim();
    if (_isRequired(field) && trimmed.isEmpty) {
      return '${field.label} is required.';
    }
    if (trimmed.isEmpty) {
      return null;
    }
    final options = _optionValuesFor(field);
    if (field.searchableOptions &&
        !field.allowCustomOption &&
        options.isNotEmpty &&
        !options.contains(trimmed)) {
      return 'Select a valid ${field.label.toLowerCase()}.';
    }

    switch (field.kind) {
      case AcpFieldKind.integer:
        final parsed = int.tryParse(trimmed);
        if (parsed == null) {
          return 'Enter a whole number.';
        }
        if (field.minimumValue != null && parsed < field.minimumValue!) {
          return 'Enter a value of at least ${field.minimumValue}.';
        }
        if (field.maximumValue != null && parsed > field.maximumValue!) {
          return 'Enter a value no greater than ${field.maximumValue}.';
        }
        return null;
      case AcpFieldKind.money:
        final minorUnit = _resolvedMinorUnitFor(field);
        if (minorUnit == null) {
          return 'Currency precision is unavailable. Select a currency before entering an amount.';
        }
        return AcpMoneyCodec.parseMajorUnits(
          trimmed,
          minorUnit: minorUnit,
        ).failure?.message;
      case AcpFieldKind.computed:
        return null;
      case AcpFieldKind.integerList:
        final parsed = _decodeIntegerList(trimmed);
        if (parsed == null) {
          return 'Enter comma-separated whole numbers or a JSON array.';
        }
        if (field.minimumValue case final minimum?) {
          if (parsed.any((value) => value < minimum)) {
            return 'Enter values of at least $minimum.';
          }
        }
        if (field.maximumValue case final maximum?) {
          if (parsed.any((value) => value > maximum)) {
            return 'Enter values no greater than $maximum.';
          }
        }
        return null;
      case AcpFieldKind.stringList:
        if (_decodeStringList(trimmed).isEmpty) {
          return 'Enter at least one value.';
        }
        return null;
      case AcpFieldKind.json:
        final result = AcpJsonCodec.parse(trimmed);
        return result.isFailure ? result.failure!.message : null;
      case AcpFieldKind.dateTime:
        if (DateTime.tryParse(trimmed) == null ||
            !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(trimmed)) {
          return 'Enter an ISO-8601 date/time value with a timezone.';
        }
        return null;
      case AcpFieldKind.timeOfDay:
        if (!RegExp(
          r'^(?:[01]\d|2[0-3]):[0-5]\d(?::[0-5]\d(?:\.\d{1,6})?)?$',
        ).hasMatch(trimmed)) {
          return 'Enter a 24-hour time as HH:mm or HH:mm:ss.';
        }
        return null;
      case AcpFieldKind.dateList:
        final dates = _decodeDateList(trimmed);
        if (dates == null) {
          return 'Select valid calendar dates.';
        }
        if (_isRequired(field) && dates.isEmpty) {
          return '${field.label} is required.';
        }
        return null;
      case AcpFieldKind.text:
      case AcpFieldKind.multiline:
      case AcpFieldKind.boolean:
        return null;
    }
  }

  int? _resolvedMinorUnitFor(AcpFieldDescriptor field) {
    final key = field.minorUnitFieldKey;
    if (key == null) {
      return field.defaultMinorUnit;
    }
    final parsed = int.tryParse(_currentFieldValue(key)?.trim() ?? '');
    if (parsed == null || parsed < 0 || parsed > 4) {
      return null;
    }
    return parsed;
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

    AcpFieldDescriptor? matchingField;
    for (final field in widget.fields) {
      if (field.key == key) {
        matchingField = field;
        break;
      }
    }
    final initialValue = matchingField == null
        ? widget.initialValues[key]
        : _initialFieldValue(matchingField);
    return initialValue?.toString();
  }

  List<String> _optionValuesFor(AcpFieldDescriptor field) {
    final values = <String, dynamic>{...widget.initialValues};
    for (final item in widget.fields) {
      values[item.key] = _currentFieldValue(item.key);
    }
    return <String>{
      ...field.options.map((option) => option.trim()),
      ...?field.optionsBuilder?.call(values).map((option) => option.trim()),
    }.where((option) => option.isNotEmpty).toList(growable: false);
  }

  String _optionLabel(AcpFieldDescriptor field, String option) =>
      field.optionLabels[option] ?? option;

  String _optionValueForInput(
    AcpFieldDescriptor field,
    String input,
    List<String> options,
  ) {
    final normalized = input.trim();
    for (final option in options) {
      if (_optionLabel(field, option) == normalized) {
        return option;
      }
    }
    return normalized;
  }

  List<String> _dropdownOptionsFor(String value, List<String> fieldOptions) {
    final options = <String>[
      for (final option in fieldOptions)
        if (option.trim().isNotEmpty) option.trim(),
    ];
    final currentValue = value.trim();
    if (currentValue.isNotEmpty && !options.contains(currentValue)) {
      options.insert(0, currentValue);
    }

    return options.toSet().toList(growable: false);
  }

  Future<void> _submit() async {
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
      if (field.submitNullWhenHidden &&
          field.includeInPayload &&
          !_isFieldVisible(field)) {
        _storePayloadValue(payload, field, null);
      }
    }
    for (final field in widget.fields.where(_isFieldVisible)) {
      if (field.readOnly || !field.includeInPayload) {
        continue;
      }
      if (field.kind == AcpFieldKind.boolean) {
        _storePayloadValue(payload, field, _boolValues[field.key] ?? false);
        continue;
      }

      final raw = _textControllers[field.key]!.text;
      final trimmed = raw.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      switch (field.kind) {
        case AcpFieldKind.integer:
          _storePayloadValue(payload, field, int.parse(trimmed));
          break;
        case AcpFieldKind.money:
          final minorUnit = _resolvedMinorUnitFor(field);
          if (minorUnit == null) {
            setState(() {
              _formErrorText =
                  'Currency precision is unavailable. Select a currency before entering an amount.';
            });
            return;
          }
          _storePayloadValue(
            payload,
            field,
            AcpMoneyCodec.parseMajorUnits(trimmed, minorUnit: minorUnit).data!,
          );
          break;
        case AcpFieldKind.computed:
          break;
        case AcpFieldKind.integerList:
          _storePayloadValue(payload, field, _decodeIntegerList(trimmed)!);
          break;
        case AcpFieldKind.stringList:
          _storePayloadValue(payload, field, _decodeStringList(trimmed));
          break;
        case AcpFieldKind.dateList:
          _storePayloadValue(
            payload,
            field,
            _decodeDateList(trimmed)!.map(_formatDateOnly).toList(),
          );
          break;
        case AcpFieldKind.json:
          _storePayloadValue(payload, field, AcpJsonCodec.parse(trimmed).data);
          break;
        case AcpFieldKind.dateTime:
          _storePayloadValue(
            payload,
            field,
            DateTime.parse(trimmed).toUtc().toIso8601String(),
          );
          break;
        case AcpFieldKind.timeOfDay:
        case AcpFieldKind.text:
        case AcpFieldKind.multiline:
          _storePayloadValue(payload, field, raw);
          break;
        case AcpFieldKind.boolean:
          break;
      }
    }

    final payloadError = widget.payloadValidator?.call(payload);
    if (payloadError != null && payloadError.trim().isNotEmpty) {
      setState(() {
        _formErrorText = payloadError;
      });
      return;
    }

    if (widget.confirmMessage != null) {
      setState(() {
        _isConfirming = true;
      });
      final confirmed = await showAppConfirmationDialog(
        context: context,
        title: widget.submitLabel,
        message: widget.confirmMessage!,
        confirmLabel: widget.submitLabel,
        icon: widget.confirmIcon ?? Icons.play_circle_outline,
      );
      if (confirmed != true || !mounted) {
        if (mounted) {
          setState(() {
            _isConfirming = false;
          });
        }
        return;
      }
    }

    final onSubmit = widget.onSubmit;
    if (onSubmit == null) {
      Navigator.of(context).pop(payload);
      return;
    }
    setState(() {
      _isConfirming = false;
      _isSubmitting = true;
      _formErrorText = null;
    });
    final result = await onSubmit(payload);
    if (!mounted) {
      return;
    }
    if (result.isFailure) {
      setState(() {
        _isSubmitting = false;
        _formErrorText = result.failure?.message ?? 'The operation failed.';
      });
      return;
    }
    Navigator.of(context).pop(payload);
  }

  void _storePayloadValue(
    Map<String, dynamic> payload,
    AcpFieldDescriptor field,
    Object? value,
  ) {
    final storedValue = _withoutExcludedJsonKeys(value, field.excludedJsonKeys);
    final containerKey = field.payloadContainerKey;
    final mapKey = field.payloadMapKey;
    if (containerKey == null || mapKey == null) {
      payload[field.key] = storedValue;
      return;
    }
    final container = switch (payload[containerKey]) {
      final Map existing => Map<String, dynamic>.from(existing),
      _ => <String, dynamic>{},
    };
    container[mapKey] = storedValue;
    payload[containerKey] = container;
  }

  String _validationErrorSummary() {
    final errors = <String>[];
    for (final field in widget.fields.where(_isFieldVisible)) {
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
      case AcpFieldKind.timeOfDay:
        return value.toString();
      case AcpFieldKind.dateList:
        if (value is List) {
          return jsonEncode(value);
        }
        return value.toString();
      case AcpFieldKind.integerList:
      case AcpFieldKind.stringList:
        if (value is List) {
          return jsonEncode(value);
        }
        return value.toString();
      case AcpFieldKind.integer:
      case AcpFieldKind.money:
      case AcpFieldKind.computed:
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
