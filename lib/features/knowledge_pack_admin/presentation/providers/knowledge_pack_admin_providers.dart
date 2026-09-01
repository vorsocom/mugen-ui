import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_projection_status.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/infrastructure/knowledge_pack_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

const String knowledgePackPluginToken = 'core.fw.knowledge_pack';
const String _serviceProfilePluginToken = 'core.fw.service_profile';

final knowledgePackShellAvailabilityProvider = Provider<ShellRouteAvailability>(
  (ref) {
    final access = ref.watch(
      corePluginAccessProvider(knowledgePackPluginToken),
    );
    return access.when(
      loading: () => const ShellRouteAvailability.pending(),
      error: (_, _) => const ShellRouteAvailability.unavailable(
        'Knowledge Pack availability could not be verified.',
      ),
      data: (value) => value.isAvailable
          ? const ShellRouteAvailability.available()
          : ShellRouteAvailability.unavailable(value.message),
    );
  },
);

final knowledgePackAdminResourcesProvider =
    Provider<List<AcpResourceDescriptor>>((ref) {
      final serviceProfileEnabled = ref
          .watch(corePluginAccessProvider(_serviceProfilePluginToken))
          .maybeWhen(data: (value) => value.isAvailable, orElse: () => false);
      return buildKnowledgePackAdminResources(
        serviceProfilesEnabled: serviceProfileEnabled,
      );
    });

final knowledgePackAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  final delegate = AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
  final resources = ref.watch(knowledgePackAdminResourcesProvider);
  return KnowledgePackAdminRepository(
    delegate: delegate,
    projectionDescriptor: resources.firstWhere(
      (descriptor) => descriptor.entitySet == 'KnowledgeIndexProjections',
    ),
  );
});

final knowledgePackAdminControllerProvider =
    StateNotifierProvider<KnowledgePackAdminController, AcpAdminState>((ref) {
      ref.watch(knowledgePackAdminResourcesProvider);
      ref.watch(knowledgePackAdminRepositoryProvider);
      return KnowledgePackAdminController(
        ref,
        onProjectionUpdate: (message) {
          ref
              .read(snackBarDispatcherProvider)
              .show(ref.read(appNavigatorProvider), message);
        },
      );
    });

class KnowledgePackAdminController extends AcpAdminController {
  KnowledgePackAdminController(
    this.ref, {
    this.pollInterval = const Duration(seconds: 2),
    this.maxStatusFailures = 3,
    void Function(String message)? onProjectionUpdate,
  }) : _onProjectionUpdate = onProjectionUpdate,
       super(
         repository: ref.read(knowledgePackAdminRepositoryProvider),
         descriptors: ref.read(knowledgePackAdminResourcesProvider),
         onSessionExpired: () {
           ref.read(authControllerProvider.notifier).refreshSession();
         },
       );

  final Ref ref;
  final Duration pollInterval;
  final int maxStatusFailures;
  final void Function(String message)? _onProjectionUpdate;
  final Set<String> _pollingProjectionIds = <String>{};
  bool _disposed = false;

  @override
  Future<Result<Object?>> runEntityAction({
    required AcpActionDescriptor action,
    required String rowId,
    required Map<String, dynamic> values,
    String? tenantIdOverride,
    bool useTenantIdOverride = false,
    int? rowVersion,
  }) async {
    final result = await super.runEntityAction(
      action: action,
      rowId: rowId,
      values: values,
      tenantIdOverride: tenantIdOverride,
      useTenantIdOverride: useTenantIdOverride,
      rowVersion: rowVersion,
    );
    if (result.isFailure || !_projectionActions.contains(action.name)) {
      return result;
    }
    final response = result.data;
    if (response is! Map) {
      return result;
    }
    final projectionId = response['ProjectionId']?.toString().trim() ?? '';
    final initialStatus =
        response['Status']?.toString().trim().toLowerCase() ?? '';
    if (projectionId.isEmpty ||
        !knowledgeProjectionActiveStatuses.contains(initialStatus)) {
      return result;
    }
    final tenantId = useTenantIdOverride
        ? tenantIdOverride
        : state.selectedTenantId;
    unawaited(
      _pollProjection(
        projectionId: projectionId,
        tenantId: tenantId,
        initialStatus: initialStatus,
      ),
    );
    return result;
  }

  Future<void> _pollProjection({
    required String projectionId,
    required String? tenantId,
    required String initialStatus,
  }) async {
    if (!_pollingProjectionIds.add(projectionId)) {
      return;
    }
    var lastStatus = initialStatus;
    var failures = 0;
    try {
      while (!_disposed) {
        await Future<void>.delayed(pollInterval);
        if (_disposed) {
          return;
        }
        final result = await repository.fetchRow(
          descriptor: descriptorForKey('knowledge-index-projections'),
          rowId: projectionId,
          tenantId: tenantId,
        );
        if (result.isFailure) {
          failures += 1;
          if (failures >= maxStatusFailures) {
            state = state.copyWith(
              errorMessage:
                  'Projection status could not be determined reliably. '
                  'Refresh Projections before retrying publication.',
            );
            return;
          }
          continue;
        }
        final projection = result.data!;
        final status =
            projection['Status']?.toString().trim().toLowerCase() ?? '';
        if (status.isEmpty) {
          failures += 1;
          if (failures >= maxStatusFailures) {
            state = state.copyWith(
              errorMessage:
                  'Projection status could not be determined reliably. '
                  'Refresh Projections before retrying publication.',
            );
            return;
          }
          continue;
        }
        failures = 0;
        if (status != lastStatus) {
          lastStatus = status;
          _onProjectionUpdate?.call(_projectionUpdateMessage(projection));
          await _refreshProjectionSurfaces();
        }
        if (knowledgeProjectionIsTerminal(projection)) {
          return;
        }
      }
    } finally {
      _pollingProjectionIds.remove(projectionId);
    }
  }

  Future<void> _refreshProjectionSurfaces() async {
    for (final key in const <String>[
      'knowledge-index-projections',
      'knowledge-pack-versions',
      'knowledge-packs',
    ]) {
      await refreshResource(key);
    }
  }

  String _projectionUpdateMessage(AcpRow projection) {
    final stateLabel = knowledgeProjectionStateLabel(projection);
    return switch (stateLabel) {
      'Indexing' => 'Projection indexing started.',
      'Reindexing' => 'Projection reindexing started.',
      'Searchable' => 'Projection is searchable.',
      'Failed' =>
        'Projection failed. Review the safe failure detail and retry.',
      'Cancelled' => 'Projection was cancelled.',
      _ => 'Projection status changed to $stateLabel.',
    };
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

const Set<String> _projectionActions = <String>{
  'publish',
  'rollback_version',
  'reindex',
  'retry',
};
