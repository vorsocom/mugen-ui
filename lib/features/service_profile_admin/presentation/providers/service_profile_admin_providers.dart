import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/service_profile_admin/application/service_profile_admin_resources.dart';
import 'package:mugen_ui/features/service_profile_admin/infrastructure/service_profile_admin_repository.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

const String _knowledgePackPluginToken = 'core.fw.knowledge_pack';

typedef ServiceProfileCapabilities = ({
  bool channelOrchestration,
  bool billing,
  bool knowledgePack,
});

final serviceProfileShellAvailabilityProvider =
    Provider<ShellRouteAvailability>((ref) {
      final access = ref.watch(
        corePluginAccessProvider(serviceProfilePluginToken),
      );
      return access.when(
        loading: () => const ShellRouteAvailability.pending(),
        error: (_, _) => const ShellRouteAvailability.unavailable(
          'Service Profile availability could not be verified.',
        ),
        data: (value) => value.isAvailable
            ? const ShellRouteAvailability.available()
            : ShellRouteAvailability.unavailable(value.message),
      );
    });

final serviceProfileCapabilitiesProvider = Provider<ServiceProfileCapabilities>(
  (ref) {
    bool available(String token) {
      return ref
          .watch(corePluginAccessProvider(token))
          .maybeWhen(data: (value) => value.isAvailable, orElse: () => false);
    }

    return (
      channelOrchestration: available(channelOrchestrationPluginToken),
      billing: available(billingPluginToken),
      knowledgePack: available(_knowledgePackPluginToken),
    );
  },
);

final serviceProfileAdminResourcesProvider =
    Provider<List<AcpResourceDescriptor>>((ref) {
      final capabilities = ref.watch(serviceProfileCapabilitiesProvider);
      return buildServiceProfileAdminResources(
        channelOrchestrationEnabled: capabilities.channelOrchestration,
        billingEnabled: capabilities.billing,
        knowledgePackEnabled: capabilities.knowledgePack,
      );
    });

final serviceProfileAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  final capabilities = ref.watch(serviceProfileCapabilitiesProvider);
  return ServiceProfileAdminRepository(
    delegate: AcpAdminRepositoryImpl(
      appConfig: ref.watch(appConfigProvider),
      authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
    ),
    channelOrchestrationEnabled: capabilities.channelOrchestration,
    billingEnabled: capabilities.billing,
    knowledgePackEnabled: capabilities.knowledgePack,
  );
});

final serviceProfileAdminControllerProvider =
    StateNotifierProvider<ServiceProfileAdminController, AcpAdminState>((ref) {
      return ServiceProfileAdminController(
        ref,
        repository: ref.watch(serviceProfileAdminRepositoryProvider),
        descriptors: ref.watch(serviceProfileAdminResourcesProvider),
      );
    });

class ServiceProfileAdminController extends AcpAdminController {
  ServiceProfileAdminController(
    this.ref, {
    required super.repository,
    required super.descriptors,
  }) : super(
         onSessionExpired: () {
           ref.read(authControllerProvider.notifier).refreshSession();
         },
       );

  final Ref ref;
}
