import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/context_admin/application/context_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

final contextAdminRepositoryProvider = Provider<AcpAdminRepository>((ref) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final contextAdminControllerProvider =
    StateNotifierProvider<ContextAdminController, AcpAdminState>((ref) {
      return ContextAdminController(ref);
    });

class ContextAdminController extends AcpAdminController {
  ContextAdminController(this.ref)
    : super(
        repository: ref.read(contextAdminRepositoryProvider),
        descriptors: contextAdminResources,
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );

  final Ref ref;
}
