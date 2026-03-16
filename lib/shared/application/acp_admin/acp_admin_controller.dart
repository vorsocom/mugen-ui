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
  });

  final List<AcpRow> rows;
  final int total;
  final int page;
  final int pageSize;
  final String searchTerm;
  final bool isLoading;
  final AcpOptionalScopeSelection optionalScopeSelection;

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

  AcpResourceDescriptor descriptorForKey(String key) {
    return _descriptorsByKey[key]!;
  }

  AcpResourceState resourceStateFor(String key) {
    return state.resourceStates[key]!;
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
  }

  Future<void> refresh() async {
    if (hasTenantScopedResources && state.tenants.isEmpty) {
      await loadInitialData();
      return;
    }

    await loadActiveResource();
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

    state = state.copyWith(selectedTenantId: tenantId, clearError: true);
    if (activeDescriptor.scopeMode == AcpScopeMode.none) {
      return;
    }
    if (activeDescriptor.scopeMode == AcpScopeMode.optional &&
        resourceStateFor(activeDescriptor.key).optionalScopeSelection ==
            AcpOptionalScopeSelection.global) {
      return;
    }

    await loadActiveResource();
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
  }

  void setSearchTerm(String value) {
    final descriptor = activeDescriptor;
    final resourceState = resourceStateFor(descriptor.key);
    _replaceResourceState(
      descriptor.key,
      resourceState.copyWith(searchTerm: value, page: 1),
    );
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
    return _finishObjectMutation(
      result,
      descriptor: descriptor,
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not create ${descriptor.title.toLowerCase()}.',
    );
  }

  Future<Result<Object?>> updateRow({
    required String rowId,
    required Map<String, dynamic> values,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
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
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not update ${descriptor.title.toLowerCase()}.',
    );
  }

  Future<Result<void>> deleteRow({
    required String rowId,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
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
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not delete ${descriptor.title.toLowerCase()}.',
    );
  }

  Future<Result<void>> restoreRow({
    required String rowId,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
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
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage: 'Could not restore ${descriptor.title.toLowerCase()}.',
    );
  }

  Future<Result<Object?>> runCollectionAction({
    required AcpActionDescriptor action,
    required Map<String, dynamic> values,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
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
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage:
          'Could not run ${action.label.toLowerCase()} for ${descriptor.title.toLowerCase()}.',
    );
  }

  Future<Result<Object?>> runEntityAction({
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    int? rowVersion,
  }) async {
    final descriptor = activeDescriptor;
    final tenantId = _tenantIdFor(descriptor);
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
      conflictMessage:
          '${descriptor.title} changed on the server. Reloading list.',
      fallbackMessage:
          'Could not run ${action.label.toLowerCase()} for ${descriptor.title.toLowerCase()}.',
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
    required String conflictMessage,
    required String fallbackMessage,
  }) async {
    state = state.copyWith(isMutating: false);
    if (result.isSuccess) {
      await loadActiveResource();
      return result;
    }

    await _handleMutationFailure(
      result.failure!,
      descriptor: descriptor,
      conflictMessage: conflictMessage,
      fallbackMessage: fallbackMessage,
    );
    return result;
  }

  Future<Result<void>> _finishVoidMutation(
    Result<void> result, {
    required AcpResourceDescriptor descriptor,
    required String conflictMessage,
    required String fallbackMessage,
  }) async {
    state = state.copyWith(isMutating: false);
    if (result.isSuccess) {
      await loadActiveResource();
      return result;
    }

    await _handleMutationFailure(
      result.failure!,
      descriptor: descriptor,
      conflictMessage: conflictMessage,
      fallbackMessage: fallbackMessage,
    );
    return result;
  }

  Future<void> _handleMutationFailure(
    Failure failure, {
    required AcpResourceDescriptor descriptor,
    required String conflictMessage,
    required String fallbackMessage,
  }) async {
    if (failure is ApiFailure && failure.statusCode == 409) {
      await _loadResource(descriptor);
      state = state.copyWith(errorMessage: conflictMessage);
      return;
    }

    _applyFailure(failure, fallback: fallbackMessage);
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

  String? _tenantIdFor(AcpResourceDescriptor descriptor) {
    final resourceState = resourceStateFor(descriptor.key);
    if (!_usesTenantScope(
      descriptor: descriptor,
      resourceState: resourceState,
    )) {
      return null;
    }

    final tenantId = state.selectedTenantId?.trim();
    if (tenantId == null || tenantId.isEmpty) {
      return null;
    }

    return tenantId;
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
