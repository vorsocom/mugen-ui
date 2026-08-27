import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

enum AcpOptionalScopeSelection { global, tenant }

class AcpResourceState {
  const AcpResourceState({
    required this.rows,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.searchTerm,
    required this.isLoading,
    required this.optionalScopeSelection,
    required this.deletedView,
    this.tabCount,
  });

  final List<AcpRow> rows;
  final int total;
  final int page;
  final int pageSize;
  final String searchTerm;
  final bool isLoading;
  final AcpOptionalScopeSelection optionalScopeSelection;
  final AcpDeletedView deletedView;
  final int? tabCount;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    final computed = (total / pageSize).ceil();
    return computed <= 0 ? 1 : computed;
  }

  AcpResourceState copyWith({
    List<AcpRow>? rows,
    int? total,
    int? page,
    int? pageSize,
    String? searchTerm,
    bool? isLoading,
    AcpOptionalScopeSelection? optionalScopeSelection,
    AcpDeletedView? deletedView,
    int? tabCount,
    bool clearTabCount = false,
  }) {
    return AcpResourceState(
      rows: rows ?? this.rows,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      searchTerm: searchTerm ?? this.searchTerm,
      isLoading: isLoading ?? this.isLoading,
      optionalScopeSelection:
          optionalScopeSelection ?? this.optionalScopeSelection,
      deletedView: deletedView ?? this.deletedView,
      tabCount: clearTabCount ? null : (tabCount ?? this.tabCount),
    );
  }
}

class AcpAdminState {
  const AcpAdminState({
    required this.tenants,
    required this.selectedTenantId,
    required this.activeResourceKey,
    required this.resourceStates,
    required this.isLoadingTenants,
    required this.isMutating,
    this.errorMessage,
  });

  final List<AcpTenantOption> tenants;
  final String? selectedTenantId;
  final String activeResourceKey;
  final Map<String, AcpResourceState> resourceStates;
  final bool isLoadingTenants;
  final bool isMutating;
  final String? errorMessage;

  AcpTenantOption? get selectedTenant {
    final tenantId = selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return null;
    }

    for (final tenant in tenants) {
      if (tenant.id == tenantId) {
        return tenant;
      }
    }

    return null;
  }

  AcpResourceState get activeResourceState {
    return resourceStates[activeResourceKey]!;
  }

  AcpAdminState copyWith({
    List<AcpTenantOption>? tenants,
    String? selectedTenantId,
    bool clearSelectedTenant = false,
    String? activeResourceKey,
    Map<String, AcpResourceState>? resourceStates,
    bool? isLoadingTenants,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AcpAdminState(
      tenants: tenants ?? this.tenants,
      selectedTenantId: clearSelectedTenant
          ? null
          : (selectedTenantId ?? this.selectedTenantId),
      activeResourceKey: activeResourceKey ?? this.activeResourceKey,
      resourceStates: resourceStates ?? this.resourceStates,
      isLoadingTenants: isLoadingTenants ?? this.isLoadingTenants,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class AcpAdminController extends StateNotifier<AcpAdminState> {
  AcpAdminController({
    required this.repository,
    required List<AcpResourceDescriptor> descriptors,
    required this.onSessionExpired,
  }) : descriptors = List<AcpResourceDescriptor>.unmodifiable(descriptors),
       _descriptorsByKey = <String, AcpResourceDescriptor>{
         for (final descriptor in descriptors) descriptor.key: descriptor,
       },
       super(
         AcpAdminState(
           tenants: const <AcpTenantOption>[],
           selectedTenantId: null,
           activeResourceKey: descriptors.first.key,
           resourceStates: <String, AcpResourceState>{
             for (final descriptor in descriptors)
               descriptor.key: AcpResourceState(
                 rows: const <AcpRow>[],
                 total: 0,
                 page: 1,
                 pageSize: descriptor.pageSize,
                 searchTerm: '',
                 isLoading: false,
                 optionalScopeSelection: AcpOptionalScopeSelection.global,
                 deletedView: descriptor.deletedViews.first,
                 tabCount: null,
               ),
           },
           isLoadingTenants: false,
           isMutating: false,
         ),
       );

  final AcpAdminRepository repository;
  final List<AcpResourceDescriptor> descriptors;
  final Map<String, AcpResourceDescriptor> _descriptorsByKey;
  final void Function() onSessionExpired;

  bool get hasTenantScopedResources {
    return descriptors.any(
      (descriptor) => descriptor.scopeMode != AcpScopeMode.none,
    );
  }

  AcpResourceDescriptor get activeDescriptor {
    return descriptorForKey(state.activeResourceKey);
  }

  String? get errorMessage => state.errorMessage;

  AcpResourceDescriptor descriptorForKey(String key) {
    return _descriptorsByKey[key]!;
  }

  AcpResourceState resourceStateFor(String key) {
    return state.resourceStates[key]!;
  }

  AcpRow? rowById(String rowId) {
    for (final row in state.activeResourceState.rows) {
      if (row.id == rowId) {
        return row;
      }
    }
    return null;
  }

  bool usesTenantScope(AcpResourceDescriptor descriptor) {
    final resourceState = resourceStateFor(descriptor.key);
    return _usesTenantScope(
      descriptor: descriptor,
      resourceState: resourceState,
    );
  }

  Future<void> loadInitialData() async {
    if (!hasTenantScopedResources) {
      await loadActiveResource();
      await refreshResourceCounts();
      return;
    }

    state = state.copyWith(isLoadingTenants: true, clearError: true);
    final tenantsResult = await repository.fetchTenants();
    if (tenantsResult.isFailure) {
      state = state.copyWith(isLoadingTenants: false);
      _applyFailure(
        tenantsResult.failure!,
        fallback: 'Could not load tenants.',
      );
      await loadActiveResource();
      return;
    }

    final tenants = tenantsResult.data ?? const <AcpTenantOption>[];
    state = state.copyWith(
      tenants: tenants,
      selectedTenantId: _resolveSelectedTenantId(
        availableTenants: tenants,
        previousSelectedTenantId: state.selectedTenantId,
      ),
      isLoadingTenants: false,
      clearError: true,
    );

    await loadActiveResource();
    await refreshResourceCounts();
  }

  Future<void> refresh() async {
    if (hasTenantScopedResources && state.tenants.isEmpty) {
      await loadInitialData();
      return;
    }

    await loadActiveResource();
    await refreshResourceCounts();
  }

  Future<void> loadActiveResource() async {
    await _loadResource(activeDescriptor);
  }

  Future<void> selectResource(String resourceKey) async {
    if (resourceKey == state.activeResourceKey) {
      return;
    }

    state = state.copyWith(activeResourceKey: resourceKey, clearError: true);
    await _loadResource(descriptorForKey(resourceKey));
  }

  Future<void> selectTenant(String tenantId) async {
    if (tenantId == state.selectedTenantId) {
      return;
    }

    final clearedStates = <String, AcpResourceState>{...state.resourceStates};
    for (final descriptor in descriptors) {
      final resourceState = resourceStateFor(descriptor.key);
      final usesTenant =
          descriptor.scopeMode == AcpScopeMode.required ||
          (descriptor.scopeMode == AcpScopeMode.optional &&
              resourceState.optionalScopeSelection ==
                  AcpOptionalScopeSelection.tenant);
      if (!usesTenant) {
        continue;
      }
      clearedStates[descriptor.key] = resourceState.copyWith(
        rows: const <AcpRow>[],
        total: 0,
        page: 1,
        tabCount: 0,
      );
    }
    state = state.copyWith(
      selectedTenantId: tenantId,
      resourceStates: clearedStates,
      clearError: true,
    );
    if (activeDescriptor.scopeMode == AcpScopeMode.none) {
      await refreshResourceCounts();
      return;
    }
    if (activeDescriptor.scopeMode == AcpScopeMode.optional &&
        resourceStateFor(activeDescriptor.key).optionalScopeSelection ==
            AcpOptionalScopeSelection.global) {
      await refreshResourceCounts();
      return;
    }

    await loadActiveResource();
    await refreshResourceCounts();
  }

  Future<void> setOptionalScopeSelection(
    AcpOptionalScopeSelection selection,
  ) async {
    final descriptor = activeDescriptor;
    if (descriptor.scopeMode != AcpScopeMode.optional) {
      return;
    }

    final resourceState = resourceStateFor(descriptor.key);
    if (resourceState.optionalScopeSelection == selection) {
      return;
    }

    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(optionalScopeSelection: selection, page: 1),
    );
    await loadActiveResource();
    await refreshResourceCounts();
  }

  void setSearchTerm(String value) {
    final descriptor = activeDescriptor;
    final resourceState = resourceStateFor(descriptor.key);
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(searchTerm: value, page: 1),
    );
  }

  Future<void> setDeletedView(AcpDeletedView value) async {
    final descriptor = activeDescriptor;
    if (!descriptor.deletedViews.contains(value)) {
      return;
    }
    final resourceState = resourceStateFor(descriptor.key);
    if (resourceState.deletedView == value) {
      return;
    }
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(deletedView: value, page: 1),
    );
    await loadActiveResource();
  }

  Future<void> setPage(int page) async {
    final descriptor = activeDescriptor;
    final resourceState = resourceStateFor(descriptor.key);
    var safePage = page;
    if (safePage < 1) {
      safePage = 1;
    }

    final maxPage = resourceState.pages;
    if (safePage > maxPage) {
      safePage = maxPage;
    }

    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(page: safePage),
    );
    await loadActiveResource();
  }

  Future<void> refreshResourceCounts() async {
    for (final descriptor in descriptors) {
      final resourceState = resourceStateFor(descriptor.key);
      final tenantId = _tenantIdFor(descriptor);
      if (descriptor.scopeMode == AcpScopeMode.required &&
          (tenantId == null || tenantId.isEmpty)) {
        _replaceResourceState(
          descriptor.key,
          resourceState.copyWith(tabCount: 0),
        );
        continue;
      }

      final result = await repository.listRows(
        descriptor: descriptor,
        pageRequest: const PageRequest(page: 1, pageSize: 1),
        tenantId: tenantId,
        deletedView: resourceState.deletedView,
      );
      if (result.isFailure) {
        continue;
      }

      _replaceResourceState(
        descriptor.key,
        resourceStateFor(
          descriptor.key,
        ).copyWith(tabCount: result.data?.total ?? 0),
      );
    }
  }

  Future<void> setRowsPerPage(int rowsPerPage) async {
    final descriptor = activeDescriptor;
    final resourceState = resourceStateFor(descriptor.key);
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(pageSize: rowsPerPage, page: 1),
    );
    await loadActiveResource();
  }

  Future<Result<Object?>> createRow(Map<String, dynamic> values) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.createRow(
      descriptor: descriptor,
      values: values,
      tenantId: tenantId,
    );
    String? createdRowId;
    if (result.isSuccess) {
      final createdRow = _objectAsRow(result.data);
      createdRowId = createdRow?.id;
    }
    return _finishObjectMutation(
      result,
      descriptor: descriptor,
      rowId: createdRowId,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not create ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: descriptor.refreshResourceKeys,
    );
  }

  Future<Result<Object?>> updateRow({
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(
      descriptor,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.updateRow(
      descriptor: descriptor,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    return _finishObjectMutation(
      result,
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not update ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: descriptor.refreshResourceKeys,
    );
  }

  Future<Result<void>> deleteRow({
    required String rowId,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(
      descriptor,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.deleteRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    return _finishVoidMutation(
      result,
      descriptor: descriptor,
      rowId: null,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not delete ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: descriptor.refreshResourceKeys,
    );
  }

  Future<Result<void>> restoreRow({
    required String rowId,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(
      descriptor,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.restoreRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    return _finishVoidMutation(
      result,
      descriptor: descriptor,
      rowId: null,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not restore ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: descriptor.refreshResourceKeys,
    );
  }

  Future<Result<Object?>> runCollectionAction({
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(
      descriptor,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.runCollectionAction(
      descriptor: descriptor,
      action: action,
      values: values,
      tenantId: tenantId,
    );
    return _finishObjectMutation(
      result,
      descriptor: descriptor,
      rowId: null,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage:
          'Could not run ${action.label.toLowerCase()} for ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: <String>{
        ...descriptor.refreshResourceKeys,
        ...action.refreshResourceKeys,
      }.toList(growable: false),
    );
  }

  Future<Result<Object?>> runEntityAction({
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(
      descriptor,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
    );
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await repository.runEntityAction(
      descriptor: descriptor,
      action: action,
      rowId: rowId,
      values: values,
      tenantId: tenantId,
      rowVersion: rowVersion,
    );
    return _finishObjectMutation(
      result,
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage:
          'Could not run ${action.label.toLowerCase()} for ${descriptor.title.toLowerCase()}.',
      refreshResourceKeys: <String>{
        ...descriptor.refreshResourceKeys,
        ...action.refreshResourceKeys,
      }.toList(growable: false),
    );
  }

  Future<void> _loadResource(AcpResourceDescriptor descriptor) async {
    final resourceState = resourceStateFor(descriptor.key);
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(isLoading: true),
    );
    state = state.copyWith(clearError: true);

    final tenantId = _tenantIdFor(descriptor);
    if (descriptor.scopeMode == AcpScopeMode.required &&
        (tenantId == null || tenantId.isEmpty)) {
      _replaceResourceState(
        descriptor.key,
        resourceState.copyWith(
          rows: const <AcpRow>[],
          total: 0,
          isLoading: false,
        ),
      );
      state = state.copyWith(
        errorMessage:
            'Select a tenant to view ${descriptor.title.toLowerCase()}.',
      );
      return;
    }

    final result = await repository.listRows(
      descriptor: descriptor,
      pageRequest: PageRequest(
        page: resourceState.page,
        pageSize: resourceState.pageSize,
      ),
      tenantId: tenantId,
      searchTerm: resourceState.searchTerm,
      deletedView: resourceState.deletedView,
    );

    if (result.isFailure) {
      _replaceResourceState(
        descriptor.key,
        resourceState.copyWith(isLoading: false),
      );
      _applyFailure(
        result.failure!,
        fallback: 'Could not load ${descriptor.title.toLowerCase()}.',
      );
      return;
    }

    final page = result.data!;
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(
        rows: page.items,
        total: page.total,
        page: page.page,
        pageSize: page.pageSize,
        isLoading: false,
      ),
    );
  }

  Future<Result<Object?>> _finishObjectMutation(
    Result<Object?> result, {
    required AcpResourceDescriptor descriptor,
    required String? rowId,
    required String? tenantId,
    required String conflictMessage,
    required String fallbackMessage,
    List<String> refreshResourceKeys = const <String>[],
  }) async {
    state = state.copyWith(isMutating: false);
    if (result.isSuccess) {
      await _refreshAffectedRow(
        descriptor: descriptor,
        rowId: rowId,
        tenantId: tenantId,
      );
      await _refreshRelatedResources(
        refreshResourceKeys,
        excluding: descriptor.key,
      );
      await refreshResourceCounts();
      return result;
    }

    await _handleMutationFailure(
      result.failure!,
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      conflictMessage: conflictMessage,
      fallbackMessage: fallbackMessage,
    );
    return result;
  }

  Future<Result<void>> _finishVoidMutation(
    Result<void> result, {
    required AcpResourceDescriptor descriptor,
    required String? rowId,
    required String? tenantId,
    required String conflictMessage,
    required String fallbackMessage,
    List<String> refreshResourceKeys = const <String>[],
  }) async {
    state = state.copyWith(isMutating: false);
    if (result.isSuccess) {
      await loadActiveResource();
      await _refreshRelatedResources(
        refreshResourceKeys,
        excluding: descriptor.key,
      );
      await refreshResourceCounts();
      return result;
    }

    await _handleMutationFailure(
      result.failure!,
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
      conflictMessage: conflictMessage,
      fallbackMessage: fallbackMessage,
    );
    return result;
  }

  Future<void> _refreshRelatedResources(
    List<String> resourceKeys, {
    required String excluding,
  }) async {
    for (final key in resourceKeys.toSet()) {
      if (key == excluding || !_descriptorsByKey.containsKey(key)) {
        continue;
      }
      await _loadResource(descriptorForKey(key));
    }
  }

  Future<void> _handleMutationFailure(
    Failure failure, {
    required AcpResourceDescriptor descriptor,
    required String? rowId,
    required String? tenantId,
    required String conflictMessage,
    required String fallbackMessage,
  }) async {
    if (failure is ConflictFailure ||
        (failure is ApiFailure && failure.statusCode == 409)) {
      await _refreshAffectedRow(
        descriptor: descriptor,
        rowId: rowId,
        tenantId: tenantId,
      );
      final message = switch (failure) {
        ConflictFailure(kind: ConflictKind.staleRowVersion) =>
          'Stale RowVersion. The latest row was refreshed; review your retained input and retry. ${failure.message}',
        ConflictFailure() => 'Conflict. ${failure.message}',
        _ => conflictMessage,
      };
      state = state.copyWith(errorMessage: message);
      return;
    }

    _applyFailure(failure, fallback: fallbackMessage);
  }

  Future<void> _refreshAffectedRow({
    required AcpResourceDescriptor descriptor,
    required String? rowId,
    required String? tenantId,
  }) async {
    if (rowId == null || rowId.isEmpty) {
      await _loadResource(descriptor);
      return;
    }

    final result = await repository.fetchRow(
      descriptor: descriptor,
      rowId: rowId,
      tenantId: tenantId,
    );
    if (result.isFailure) {
      await _loadResource(descriptor);
      return;
    }

    final resourceState = resourceStateFor(descriptor.key);
    final refreshedRow = result.data!;
    final rows = <AcpRow>[
      for (final row in resourceState.rows)
        if (row.id == rowId) refreshedRow else row,
    ];
    if (!resourceState.rows.any((row) => row.id == rowId)) {
      rows.insert(0, refreshedRow);
    }
    _replaceResourceState(descriptor.key, resourceState.copyWith(rows: rows));
  }

  AcpRow? _objectAsRow(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }
    return null;
  }

  void _applyFailure(Failure failure, {required String fallback}) {
    if (failure is SessionExpiredFailure || failure is UnauthorizedFailure) {
      onSessionExpired();
    }

    final message = failure.message.trim().isEmpty ? fallback : failure.message;
    state = state.copyWith(errorMessage: message);
  }

  void _replaceResourceState(String key, AcpResourceState resourceState) {
    state = state.copyWith(
      resourceStates: <String, AcpResourceState>{
        ...state.resourceStates,
        key: resourceState,
      },
    );
  }

  String? _tenantIdFor(
    AcpResourceDescriptor descriptor, {
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
  }) {
    if (useTenantIdOverride) {
      return descriptor.scopeMode == AcpScopeMode.none
          ? null
          : _normalizedTenantId(tenantIdOverride);
    }

    final resourceState = resourceStateFor(descriptor.key);
    if (!_usesTenantScope(
      descriptor: descriptor,
      resourceState: resourceState,
    )) {
      return null;
    }

    return _normalizedTenantId(state.selectedTenantId);
  }

  String? _normalizedTenantId(String? tenantId) {
    final trimmedTenantId = tenantId?.trim();
    return trimmedTenantId == null || trimmedTenantId.isEmpty
        ? null
        : trimmedTenantId;
  }

  bool _usesTenantScope({
    required AcpResourceDescriptor descriptor,
    required AcpResourceState resourceState,
  }) {
    switch (descriptor.scopeMode) {
      case AcpScopeMode.none:
        return false;
      case AcpScopeMode.required:
        return true;
      case AcpScopeMode.optional:
        return resourceState.optionalScopeSelection ==
            AcpOptionalScopeSelection.tenant;
    }
  }

  String? _resolveSelectedTenantId({
    required List<AcpTenantOption> availableTenants,
    String? previousSelectedTenantId,
  }) {
    if (availableTenants.isEmpty) {
      return null;
    }

    final previousId = previousSelectedTenantId?.trim();
    if (previousId != null && previousId.isNotEmpty) {
      for (final tenant in availableTenants) {
        if (tenant.id == previousId) {
          return previousId;
        }
      }
    }

    for (final tenant in availableTenants) {
      final normalizedName = tenant.name.trim().toLowerCase();
      final normalizedSlug = tenant.slug?.trim().toLowerCase();
      if (normalizedName == 'global' || normalizedSlug == 'global') {
        return tenant.id;
      }
    }

    return availableTenants.first.id;
  }
}
