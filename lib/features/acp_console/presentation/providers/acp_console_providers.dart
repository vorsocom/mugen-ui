import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/acp_console/application/acp_console_resources.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

final acpConsoleRepositoryProvider = Provider<AcpAdminRepository>((ref) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final acpConsoleControllerProvider =
    StateNotifierProvider<AcpConsoleController, AcpAdminState>((ref) {
      return AcpConsoleController(ref);
    });

class AcpConsoleController extends AcpAdminController {
  AcpConsoleController(this.ref)
    : super(
        repository: ref.read(acpConsoleRepositoryProvider),
        descriptors: acpConsoleResources,
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );

  final Ref ref;
}
