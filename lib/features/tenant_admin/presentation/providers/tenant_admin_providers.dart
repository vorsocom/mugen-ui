import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/repositories/tenant_admin_repository.dart';
import 'package:mugen_ui/features/tenant_admin/infrastructure/repositories/tenant_admin_repository_impl.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

enum TenantAdminTab { domains, invitations, memberships }

class TenantAdminState {
  const TenantAdminState({
    required this.tenants,
    required this.domains,
    required this.invitations,
    required this.memberships,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.searchTerm,
    required this.activeTab,
    required this.isLoadingTenants,
    required this.isLoadingDetails,
    this.selectedTenantId,
    this.errorMessage,
  });

  final List<TenantEntity> tenants;
  final List<TenantDomainEntity> domains;
  final List<TenantInvitationEntity> invitations;
  final List<TenantMembershipEntity> memberships;
  final int total;
  final int page;
  final int pageSize;
  final String searchTerm;
  final TenantAdminTab activeTab;
  final bool isLoadingTenants;
  final bool isLoadingDetails;
  final String? selectedTenantId;
  final String? errorMessage;

  int get pages {
    if (pageSize <= 0) {
      return 1;
    }

    return (total / pageSize).ceil();
  }

  TenantEntity? get selectedTenant {
    if (selectedTenantId == null) {
      return null;
    }

    for (final tenant in tenants) {
      if (tenant.id == selectedTenantId) {
        return tenant;
      }
    }

    return null;
  }

  TenantAdminState copyWith({
    List<TenantEntity>? tenants,
    List<TenantDomainEntity>? domains,
    List<TenantInvitationEntity>? invitations,
    List<TenantMembershipEntity>? memberships,
    int? total,
    int? page,
    int? pageSize,
    String? searchTerm,
    TenantAdminTab? activeTab,
    bool? isLoadingTenants,
    bool? isLoadingDetails,
    String? selectedTenantId,
    bool clearSelectedTenant = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return TenantAdminState(
      tenants: tenants ?? this.tenants,
      domains: domains ?? this.domains,
      invitations: invitations ?? this.invitations,
      memberships: memberships ?? this.memberships,
      total: total ?? this.total,
      page: page ?? this.page,
      pageSize: pageSize ?? this.pageSize,
      searchTerm: searchTerm ?? this.searchTerm,
      activeTab: activeTab ?? this.activeTab,
      isLoadingTenants: isLoadingTenants ?? this.isLoadingTenants,
      isLoadingDetails: isLoadingDetails ?? this.isLoadingDetails,
      selectedTenantId: clearSelectedTenant
          ? null
          : (selectedTenantId ?? this.selectedTenantId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

final tenantAdminRepositoryProvider = Provider<TenantAdminRepository>((ref) {
  return TenantAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final tenantAdminControllerProvider =
    StateNotifierProvider<TenantAdminController, TenantAdminState>((ref) {
      return TenantAdminController(ref);
    });

class TenantAdminController extends StateNotifier<TenantAdminState> {
  TenantAdminController(this.ref)
    : super(
        const TenantAdminState(
          tenants: <TenantEntity>[],
          domains: <TenantDomainEntity>[],
          invitations: <TenantInvitationEntity>[],
          memberships: <TenantMembershipEntity>[],
          total: 0,
          page: 1,
          pageSize: 15,
          searchTerm: '',
          activeTab: TenantAdminTab.domains,
          isLoadingTenants: false,
          isLoadingDetails: false,
        ),
      );

  final Ref ref;

  Future<void> loadTenants() async {
    state = state.copyWith(isLoadingTenants: true, clearError: true);

    final response = await ref
        .read(tenantAdminRepositoryProvider)
        .fetchTenants(
          TenantListQuery(
            pageRequest: PageRequest(
              page: state.page,
              pageSize: state.pageSize,
            ),
            searchTerm: state.searchTerm,
          ),
        );

    if (response.isFailure) {
      _applyFailure(response.failure!, fallback: 'Could not load tenants.');
      state = state.copyWith(isLoadingTenants: false);
      return;
    }

    final page = response.data!;
    var selectedTenantId = state.selectedTenantId;
    final selectedStillVisible = page.items.any(
      (t) => t.id == selectedTenantId,
    );
    if (!selectedStillVisible) {
      selectedTenantId = page.items.isEmpty ? null : page.items.first.id;
    }

    state = state.copyWith(
      tenants: page.items,
      total: page.total,
      selectedTenantId: selectedTenantId,
      isLoadingTenants: false,
      clearError: true,
    );

    if (selectedTenantId == null) {
      state = state.copyWith(
        domains: const <TenantDomainEntity>[],
        invitations: const <TenantInvitationEntity>[],
        memberships: const <TenantMembershipEntity>[],
      );
      return;
    }

    await loadSelectedTenantDetails();
  }

  Future<void> loadSelectedTenantDetails() async {
    final tenantId = state.selectedTenantId;
    if (tenantId == null || tenantId.isEmpty) {
      return;
    }

    state = state.copyWith(isLoadingDetails: true, clearError: true);
    final repository = ref.read(tenantAdminRepositoryProvider);
    final domains = await repository.fetchTenantDomains(tenantId: tenantId);
    final invitations = await repository.fetchTenantInvitations(
      tenantId: tenantId,
    );
    final memberships = await repository.fetchTenantMemberships(
      tenantId: tenantId,
    );

    final firstFailure =
        domains.failure ?? invitations.failure ?? memberships.failure;

    if (firstFailure != null) {
      _applyFailure(firstFailure, fallback: 'Could not load tenant details.');
      state = state.copyWith(isLoadingDetails: false);
      return;
    }

    state = state.copyWith(
      domains: domains.data ?? const <TenantDomainEntity>[],
      invitations: invitations.data ?? const <TenantInvitationEntity>[],
      memberships: memberships.data ?? const <TenantMembershipEntity>[],
      isLoadingDetails: false,
      clearError: true,
    );
  }

  Future<void> selectTenant(String tenantId) async {
    if (tenantId == state.selectedTenantId) {
      return;
    }

    state = state.copyWith(selectedTenantId: tenantId);
    await loadSelectedTenantDetails();
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

  void setSearchTerm(String value) {
    state = state.copyWith(searchTerm: value, page: 1);
  }

  void setActiveTab(TenantAdminTab tab) {
    state = state.copyWith(activeTab: tab);
  }

  Future<bool> createTenant(CreateTenantInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).createTenant(input),
      conflictMessage: 'Tenant could not be created due to a conflict.',
      reloadOnSuccess: loadTenants,
      reloadOnConflict: loadTenants,
    );
  }

  Future<bool> updateTenant(UpdateTenantInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).updateTenant(input),
      conflictMessage: 'Tenant changed on the server. Reloading tenants.',
      reloadOnSuccess: loadTenants,
      reloadOnConflict: loadTenants,
    );
  }

  Future<bool> deactivateTenant(TenantLifecycleInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).deactivateTenant(input),
      conflictMessage:
          'Tenant state changed on the server. Reloading tenants now.',
      reloadOnSuccess: loadTenants,
      reloadOnConflict: loadTenants,
    );
  }

  Future<bool> reactivateTenant(TenantLifecycleInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).reactivateTenant(input),
      conflictMessage:
          'Tenant state changed on the server. Reloading tenants now.',
      reloadOnSuccess: loadTenants,
      reloadOnConflict: loadTenants,
    );
  }

  Future<bool> createDomain(CreateTenantDomainInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).createTenantDomain(input),
      conflictMessage: 'Domain changed on the server. Reloading domains.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> updateDomain(UpdateTenantDomainInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).updateTenantDomain(input),
      conflictMessage: 'Domain changed on the server. Reloading domains.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> deleteDomain(DeleteTenantDomainInput input) async {
    return _runMutation(
      () => ref.read(tenantAdminRepositoryProvider).deleteTenantDomain(input),
      conflictMessage: 'Domain changed on the server. Reloading domains.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> createInvitation(CreateTenantInvitationInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).createTenantInvitation(input),
      conflictMessage: 'Invitation changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> resendInvitation(TenantInvitationActionInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).resendTenantInvitation(input),
      conflictMessage: 'Invitation changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> revokeInvitation(TenantInvitationActionInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).revokeTenantInvitation(input),
      conflictMessage: 'Invitation changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> createMembership(CreateTenantMembershipInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).createTenantMembership(input),
      conflictMessage: 'Membership changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> updateMembership(UpdateTenantMembershipInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).updateTenantMembership(input),
      conflictMessage: 'Membership changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> suspendMembership(TenantMembershipActionInput input) async {
    return _runMutation(
      () => ref
          .read(tenantAdminRepositoryProvider)
          .suspendTenantMembership(input),
      conflictMessage: 'Membership changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> unsuspendMembership(TenantMembershipActionInput input) async {
    return _runMutation(
      () => ref
          .read(tenantAdminRepositoryProvider)
          .unsuspendTenantMembership(input),
      conflictMessage: 'Membership changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> removeMembership(TenantMembershipActionInput input) async {
    return _runMutation(
      () =>
          ref.read(tenantAdminRepositoryProvider).removeTenantMembership(input),
      conflictMessage: 'Membership changed on the server. Reloading list.',
      reloadOnSuccess: loadSelectedTenantDetails,
      reloadOnConflict: loadSelectedTenantDetails,
    );
  }

  Future<bool> _runMutation(
    Future<Result<void>> Function() run, {
    required String conflictMessage,
    required Future<void> Function() reloadOnSuccess,
    required Future<void> Function() reloadOnConflict,
  }) async {
    final response = await run();
    if (response.isSuccess) {
      await reloadOnSuccess();
      return true;
    }

    final failure = response.failure!;
    if (failure is ApiFailure && failure.statusCode == 409) {
      await reloadOnConflict();
      state = state.copyWith(errorMessage: conflictMessage);
      return false;
    }

    _applyFailure(failure, fallback: 'API error.');
    return false;
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
