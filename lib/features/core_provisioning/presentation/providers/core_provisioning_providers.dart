import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_operations_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/connector_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/core_plugin_access_service.dart';
import 'package:mugen_ui/features/core_provisioning/application/governance_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/reporting_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/sla_resources.dart';
import 'package:mugen_ui/features/core_provisioning/application/workflow_resources.dart';
import 'package:mugen_ui/features/core_provisioning/domain/entities/core_plugin_access.dart';
import 'package:mugen_ui/features/core_provisioning/domain/repositories/core_plugin_repository.dart';
import 'package:mugen_ui/features/core_provisioning/infrastructure/repositories/core_plugin_repository_impl.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/billing_acp_admin_repository.dart';

const String billingPluginToken = 'core.fw.billing';
const String connectorPluginToken = 'core.fw.ops_connector';
const String governancePluginToken = 'core.fw.ops_governance';
const String workflowPluginToken = 'core.fw.ops_workflow';
const String slaPluginToken = 'core.fw.ops_sla';
const String reportingPluginToken = 'core.fw.ops_reporting';

final corePluginRepositoryProvider = Provider<CorePluginRepository>((ref) {
  return CorePluginRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final corePluginAccessProvider =
    FutureProvider.family<CorePluginAccess, String>((ref, token) async {
      final sessionKey = ref.watch(
        authControllerProvider.select(
          (state) => (state.session?.userId, state.session?.accessToken),
        ),
      );
      if (sessionKey.$1 == null || sessionKey.$2 == null) {
        return const CorePluginAccess(
          status: CorePluginAccessStatus.unavailable,
          message: 'Sign in to access Core provisioning.',
        );
      }
      return CorePluginAccessService(
        repository: ref.read(corePluginRepositoryProvider),
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      ).resolve(token);
    });

Provider<ShellRouteAvailability> _availabilityProvider(String token) {
  return Provider<ShellRouteAvailability>((ref) {
    final access = ref.watch(corePluginAccessProvider(token));
    return access.when(
      loading: () => const ShellRouteAvailability.pending(),
      error: (_, _) => const ShellRouteAvailability.unavailable(
        'Plugin availability could not be verified.',
      ),
      data: (value) => value.isAvailable
          ? const ShellRouteAvailability.available()
          : ShellRouteAvailability.unavailable(value.message),
    );
  });
}

final billingOperationsShellAvailabilityProvider = _availabilityProvider(
  billingPluginToken,
);
final connectorsShellAvailabilityProvider = _availabilityProvider(
  connectorPluginToken,
);
final governanceShellAvailabilityProvider = _availabilityProvider(
  governancePluginToken,
);
final workflowsShellAvailabilityProvider = _availabilityProvider(
  workflowPluginToken,
);
final slaShellAvailabilityProvider = _availabilityProvider(slaPluginToken);
final reportingShellAvailabilityProvider = _availabilityProvider(
  reportingPluginToken,
);

final coreProvisioningAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final billingOperationsControllerProvider =
    StateNotifierProvider<BillingOperationsController, AcpAdminState>((ref) {
      return BillingOperationsController(ref);
    });
final billingOperationsAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  return BillingAcpAdminRepository(
    ref.watch(coreProvisioningAdminRepositoryProvider),
  );
});
final connectorAdminControllerProvider =
    StateNotifierProvider<ConnectorAdminController, AcpAdminState>((ref) {
      return ConnectorAdminController(ref);
    });
final governanceAdminControllerProvider =
    StateNotifierProvider<GovernanceAdminController, AcpAdminState>((ref) {
      return GovernanceAdminController(ref);
    });
final workflowAdminControllerProvider =
    StateNotifierProvider<WorkflowAdminController, AcpAdminState>((ref) {
      return WorkflowAdminController(ref);
    });
final slaAdminControllerProvider =
    StateNotifierProvider<SlaAdminController, AcpAdminState>((ref) {
      return SlaAdminController(ref);
    });
final reportingAdminControllerProvider =
    StateNotifierProvider<ReportingAdminController, AcpAdminState>((ref) {
      return ReportingAdminController(ref);
    });

abstract class _CoreProvisioningController extends AcpAdminController {
  _CoreProvisioningController(
    Ref ref,
    List<AcpResourceDescriptor> descriptors, {
    AcpAdminRepository? repository,
  }) : super(
         repository:
             repository ?? ref.read(coreProvisioningAdminRepositoryProvider),
         descriptors: descriptors,
         onSessionExpired: () {
           ref.read(authControllerProvider.notifier).refreshSession();
         },
       );
}

class BillingOperationsController extends _CoreProvisioningController {
  BillingOperationsController(Ref ref)
    : super(
        ref,
        billingOperationsResources,
        repository: ref.read(billingOperationsAdminRepositoryProvider),
      );
}

class ConnectorAdminController extends _CoreProvisioningController {
  ConnectorAdminController(Ref ref) : super(ref, connectorResources);
}

class GovernanceAdminController extends _CoreProvisioningController {
  GovernanceAdminController(Ref ref) : super(ref, governanceResources);
}

class WorkflowAdminController extends _CoreProvisioningController {
  WorkflowAdminController(Ref ref) : super(ref, workflowResources);
}

class SlaAdminController extends _CoreProvisioningController {
  SlaAdminController(Ref ref) : super(ref, slaResources);
}

class ReportingAdminController extends _CoreProvisioningController {
  ReportingAdminController(Ref ref) : super(ref, reportingResources);
}
