// coverage:ignore-file
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_chain_verification_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_lifecycle_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_seal_backlog_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/repositories/audit_admin_repository.dart';
import 'package:mugen_ui/features/audit_admin/infrastructure/repositories/audit_admin_repository_impl.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class AuditAdminState {
  const AuditAdminState({
    required this.scopeMode,
    required this.events,
    required this.tenants,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.searchTerm,
    required this.isLoadingEvents,
    required this.isLoadingTenants,
    required this.isMutating,
    this.selectedTenantId,
    this.selectedEventId,
    this.latestLifecycleSummary,
    this.latestChainSummary,
    this.latestSealSummary,
    this.errorMessage,
  });

  final AuditAdminScopeMode scopeMode;
  final List<AuditEventEntity> events;
  final List<AuditTenantOptionEntity> tenants;

  final int page;
  final int pageSize;
  final int total;
  final String searchTerm;

  final bool isLoadingEvents;
  final bool isLoadingTenants;
  final bool isMutating;

  final String? selectedTenantId;
  final String? selectedEventId;

  final AuditLifecycleSummaryEntity? latestLifecycleSummary;
  final AuditChainVerificationSummaryEntity? latestChainSummary;
  final AuditSealBacklogSummaryEntity? latestSealSummary;

  final String? errorMessage;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    return (total / pageSize).ceil();
  }

  AuditEventEntity? get selectedEvent {
    final selectedId = selectedEventId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    for (final event in events) {
      if (event.id == selectedId) {
        return event;
      }
    }

    return null;
  }

  AuditTenantOptionEntity? get selectedTenant {
    final selectedId = selectedTenantId;
    if (selectedId == null || selectedId.isEmpty) {
      return null;
    }

    for (final tenant in tenants) {
      if (tenant.id == selectedId) {
        return tenant;
      }
    }

    return null;
  }

  AuditAdminState copyWith({
    AuditAdminScopeMode? scopeMode,
    List<AuditEventEntity>? events,
    List<AuditTenantOptionEntity>? tenants,
    int? page,
    int? pageSize,
    int? total,
    String? searchTerm,
    bool? isLoadingEvents,
    bool? isLoadingTenants,
    bool? isMutating,
    String? selectedTenantId,
    String? selectedEventId,
    bool clearSelectedTenant = false,
    bool clearSelectedEvent = false,
    AuditLifecycleSummaryEntity? latestLifecycleSummary,
    AuditChainVerificationSummaryEntity? latestChainSummary,
    AuditSealBacklogSummaryEntity? latestSealSummary,
    bool clearLifecycleSummary = false,
    bool clearChainSummary = false,
    bool clearSealSummary = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AuditAdminState(
      scopeMode: scopeMode ?? this.scopeMode,
      events: events ?? this.events,
      tenants: tenants ?? this.tenants,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      total: total ?? this.total,
      searchTerm: searchTerm ?? this.searchTerm,
      isLoadingEvents: isLoadingEvents ?? this.isLoadingEvents,
      isLoadingTenants: isLoadingTenants ?? this.isLoadingTenants,
      isMutating: isMutating ?? this.isMutating,
      selectedTenantId: clearSelectedTenant
          ? null
          : (selectedTenantId ?? this.selectedTenantId),
      selectedEventId: clearSelectedEvent
          ? null
          : (selectedEventId ?? this.selectedEventId),
      latestLifecycleSummary: clearLifecycleSummary
          ? null
          : (latestLifecycleSummary ?? this.latestLifecycleSummary),
      latestChainSummary: clearChainSummary
          ? null
          : (latestChainSummary ?? this.latestChainSummary),
      latestSealSummary: clearSealSummary
          ? null
          : (latestSealSummary ?? this.latestSealSummary),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final auditAdminRepositoryProvider = Provider<AuditAdminRepository>((ref) {
  return AuditAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final auditAdminControllerProvider =
    StateNotifierProvider<AuditAdminController, AuditAdminState>((ref) {
      return AuditAdminController(ref);
    });

class AuditAdminController extends StateNotifier<AuditAdminState> {
  AuditAdminController(this.ref)
    : super(
        const AuditAdminState(
          scopeMode: AuditAdminScopeMode.global,
          events: <AuditEventEntity>[],
          tenants: <AuditTenantOptionEntity>[],
          page: 1,
          pageSize: 15,
          total: 0,
          searchTerm: '',
          isLoadingEvents: false,
          isLoadingTenants: false,
          isMutating: false,
        ),
      );

  final Ref ref;

  Future<void> loadInitialData() async {
    await loadTenants();
    await loadEvents();
  }

  Future<void> refresh() async {
    await loadEvents();
  }

  Future<void> loadTenants() async {
    state = state.copyWith(isLoadingTenants: true, clearError: true);

    final response = await ref
        .read(auditAdminRepositoryProvider)
        .fetchTenants();
    if (response.isFailure) {
      _applyFailure(response.failure!, fallback: 'Could not load tenants.');
      state = state.copyWith(isLoadingTenants: false);
      return;
    }

    final tenants = response.data ?? const <AuditTenantOptionEntity>[];
    var selectedTenantId = state.selectedTenantId;
    final stillVisible = tenants.any((tenant) => tenant.id == selectedTenantId);
    if (!stillVisible) {
      selectedTenantId = tenants.isEmpty ? null : tenants.first.id;
    }

    state = state.copyWith(
      tenants: tenants,
      selectedTenantId: selectedTenantId,
      isLoadingTenants: false,
      clearError: true,
    );
  }

  Future<void> loadEvents() async {
    final tenantId = _effectiveTenantId();
    if (state.scopeMode == AuditAdminScopeMode.tenant &&
        (tenantId == null || tenantId.isEmpty)) {
      state = state.copyWith(
        events: const <AuditEventEntity>[],
        total: 0,
        clearSelectedEvent: true,
      );
      return;
    }

    state = state.copyWith(isLoadingEvents: true, clearError: true);

    final response = await ref
        .read(auditAdminRepositoryProvider)
        .fetchAuditEvents(
          AuditEventListQuery(
            pageRequest: PageRequest(
              page: state.page,
              pageSize: state.pageSize,
            ),
            scopeMode: state.scopeMode,
            tenantId: tenantId,
            searchTerm: state.searchTerm,
          ),
        );
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Could not load audit events.',
      );
      state = state.copyWith(isLoadingEvents: false);
      return;
    }

    final page = response.data!;
    var selectedEventId = state.selectedEventId;
    final selectedStillVisible = page.items.any(
      (event) => event.id == selectedEventId,
    );
    if (!selectedStillVisible) {
      selectedEventId = page.items.isEmpty ? null : page.items.first.id;
    }

    state = state.copyWith(
      events: page.items,
      total: page.total,
      selectedEventId: selectedEventId,
      isLoadingEvents: false,
      clearError: true,
    );
  }

  Future<void> setScopeMode(AuditAdminScopeMode scopeMode) async {
    if (scopeMode == state.scopeMode) {
      return;
    }

    state = state.copyWith(
      scopeMode: scopeMode,
      page: 1,
      clearSelectedEvent: true,
      clearError: true,
    );

    if (scopeMode == AuditAdminScopeMode.tenant && state.tenants.isEmpty) {
      await loadTenants();
    }

    await loadEvents();
  }

  Future<void> selectTenant(String tenantId) async {
    if (tenantId == state.selectedTenantId) {
      return;
    }

    state = state.copyWith(
      selectedTenantId: tenantId,
      page: 1,
      clearSelectedEvent: true,
      clearError: true,
    );

    await loadEvents();
  }

  void selectEvent(String eventId) {
    if (eventId == state.selectedEventId) {
      return;
    }

    state = state.copyWith(selectedEventId: eventId);
  }

  void setSearchTerm(String value) {
    state = state.copyWith(searchTerm: value, page: 1);
  }

  void setRowsPerPage(int rowsPerPage) {
    state = state.copyWith(pageSize: rowsPerPage, page: 1);
  }

  void setPage(int page) {
    var safePage = page;
    if (safePage < 1) {
      safePage = 1;
    }

    final maxPage = state.pages;
    if (maxPage > 0 && safePage > maxPage) {
      safePage = maxPage;
    }

    state = state.copyWith(page: safePage);
  }

  Future<bool> placeLegalHold(AuditPlaceLegalHoldInput input) async {
    return _runRowMutation(
      () => ref.read(auditAdminRepositoryProvider).placeLegalHold(input),
      conflictMessage: 'Audit event changed on the server. Reloading events.',
    );
  }

  Future<bool> releaseLegalHold(AuditReleaseLegalHoldInput input) async {
    return _runRowMutation(
      () => ref.read(auditAdminRepositoryProvider).releaseLegalHold(input),
      conflictMessage: 'Audit event changed on the server. Reloading events.',
    );
  }

  Future<bool> redactEvent(AuditRedactInput input) async {
    return _runRowMutation(
      () => ref.read(auditAdminRepositoryProvider).redactEvent(input),
      conflictMessage: 'Audit event changed on the server. Reloading events.',
    );
  }

  Future<bool> tombstoneEvent(AuditTombstoneInput input) async {
    return _runRowMutation(
      () => ref.read(auditAdminRepositoryProvider).tombstoneEvent(input),
      conflictMessage: 'Audit event changed on the server. Reloading events.',
    );
  }

  Future<bool> runLifecycle(AuditRunLifecycleInput input) async {
    state = state.copyWith(isMutating: true, clearError: true);

    final response = await ref
        .read(auditAdminRepositoryProvider)
        .runLifecycle(input);
    if (response.isFailure) {
      final failure = response.failure!;
      if (failure is ApiFailure && failure.statusCode == 409) {
        await loadEvents();
      }
      _applyFailure(failure, fallback: 'Lifecycle operation failed.');
      state = state.copyWith(isMutating: false);
      return false;
    }

    state = state.copyWith(
      latestLifecycleSummary: response.data,
      isMutating: false,
      clearError: true,
    );
    await loadEvents();
    return true;
  }

  Future<bool> verifyChain(AuditVerifyChainInput input) async {
    state = state.copyWith(isMutating: true, clearError: true);

    final response = await ref
        .read(auditAdminRepositoryProvider)
        .verifyChain(input);
    if (response.isFailure) {
      _applyFailure(response.failure!, fallback: 'Chain verification failed.');
      state = state.copyWith(isMutating: false);
      return false;
    }

    state = state.copyWith(
      latestChainSummary: response.data,
      isMutating: false,
      clearError: true,
    );
    return true;
  }

  Future<bool> sealBacklog(AuditSealBacklogInput input) async {
    state = state.copyWith(isMutating: true, clearError: true);

    final response = await ref
        .read(auditAdminRepositoryProvider)
        .sealBacklog(input);
    if (response.isFailure) {
      _applyFailure(
        response.failure!,
        fallback: 'Seal backlog operation failed.',
      );
      state = state.copyWith(isMutating: false);
      return false;
    }

    state = state.copyWith(
      latestSealSummary: response.data,
      isMutating: false,
      clearError: true,
    );
    await loadEvents();
    return true;
  }

  Future<bool> _runRowMutation(
    Future<Result<void>> Function() run, {
    required String conflictMessage,
  }) async {
    state = state.copyWith(isMutating: true, clearError: true);

    final response = await run();
    if (response.isSuccess) {
      state = state.copyWith(isMutating: false, clearError: true);
      await loadEvents();
      return true;
    }

    final failure = response.failure!;
    if (failure is ApiFailure && failure.statusCode == 409) {
      await loadEvents();
      state = state.copyWith(isMutating: false, errorMessage: conflictMessage);
      return false;
    }

    _applyFailure(failure, fallback: 'API error.');
    state = state.copyWith(isMutating: false);
    return false;
  }

  String? _effectiveTenantId() {
    if (state.scopeMode == AuditAdminScopeMode.global) {
      return null;
    }

    return state.selectedTenantId;
  }

  void _applyFailure(Failure failure, {required String fallback}) {
    if (failure is SessionExpiredFailure) {
      ref.read(authControllerProvider.notifier).refreshSession();
    }

    state = state.copyWith(
      errorMessage: failure.message.isEmpty ? fallback : failure.message,
    );
  }
}
