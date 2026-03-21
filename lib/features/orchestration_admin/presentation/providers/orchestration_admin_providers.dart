import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/orchestration_admin/application/orchestration_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
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
}
