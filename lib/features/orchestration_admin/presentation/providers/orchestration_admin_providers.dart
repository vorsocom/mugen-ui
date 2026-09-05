import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/features/orchestration_admin/application/ingress_binding_ownership.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

final orchestrationAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final orchestrationAdminControllerProvider =
    StateNotifierProvider<OrchestrationAdminController, AcpAdminState>((ref) {
      return OrchestrationAdminController(ref);
    });

class OrchestrationAdminController extends AcpAdminController {
  OrchestrationAdminController(this.ref)
    : super(
        repository: ref.read(orchestrationAdminRepositoryProvider),
        descriptors: orchestrationAdminResources,
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );

  final Ref ref;

  @override
  Future<Result<Object?>> createRow(
    Map<String, dynamic> values, {
    bool deferRefresh = false,
  }) async {
    final resourceKey = state.activeResourceKey;
    final selectedTenantId = state.selectedTenantId;
    if (activeDescriptor.entitySet == 'IngressBindings') {
      final validation = await _validateIngress(values, selectedTenantId);
      if (validation.isFailure) {
        return Result<Object?>.failure(validation.failure!);
      }
      if (_selectionChanged(resourceKey, selectedTenantId)) {
        return _staleSelectionFailure();
      }
    }
    return super.createRow(values, deferRefresh: deferRefresh);
  }

  @override
  Future<Result<Object?>> updateRow({
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final resourceKey = state.activeResourceKey;
    final selectedTenantId = state.selectedTenantId;
    if (activeDescriptor.entitySet == 'IngressBindings') {
      final tenantId = useTenantIdOverride
          ? tenantIdOverride
          : selectedTenantId;
      final current = await repository.fetchRow(
        descriptor: activeDescriptor,
        rowId: rowId,
        tenantId: tenantId,
      );
      if (current.isFailure) {
        _ownershipFailure(current.failure!);
        return Result<Object?>.failure(current.failure!);
      }
      final validation = await _validateIngress(<String, dynamic>{
        ...current.data!,
        ...values,
      }, tenantId);
      if (validation.isFailure) {
        return Result<Object?>.failure(validation.failure!);
      }
      if (_selectionChanged(resourceKey, selectedTenantId)) {
        return _staleSelectionFailure();
      }
    }
    return super.updateRow(
      rowId: rowId,
      values: values,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
      rowVersion: rowVersion,
    );
  }

  bool _selectionChanged(String resourceKey, String? selectedTenantId) =>
      state.activeResourceKey != resourceKey ||
      state.selectedTenantId != selectedTenantId;

  Result<Object?> _staleSelectionFailure() {
    const failure = ValidationFailure(
      'The selected tenant or resource changed. Reopen the form and try again.',
    );
    _ownershipFailure(failure);
    return const Result<Object?>.failure(failure);
  }

  Future<Result<void>> _validateIngress(
    Map<String, dynamic> values,
    String? tenantId,
  ) async {
    state = state.copyWith(isMutating: true, clearError: true);
    final result = await validateIngressBindingOwnership(
      repository: repository,
      values: values,
      tenantId: tenantId,
    );
    state = state.copyWith(isMutating: false);
    if (result.isFailure) {
      _ownershipFailure(result.failure!);
    }
    return result;
  }

  void _ownershipFailure(Failure failure) {
    state = state.copyWith(errorMessage: failure.message);
    if (failure is SessionExpiredFailure) {
      ref.read(authControllerProvider.notifier).refreshSession();
    }
  }
}
