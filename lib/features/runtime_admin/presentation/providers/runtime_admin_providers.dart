import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/runtime_admin/application/runtime_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

final runtimeAdminRepositoryProvider = Provider<AcpAdminRepository>((ref) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final runtimeAdminControllerProvider =
    StateNotifierProvider<RuntimeAdminController, AcpAdminState>((ref) {
      return RuntimeAdminController(ref);
    });

class RuntimeAdminController extends AcpAdminController {
  RuntimeAdminController(this.ref)
    : super(
        repository: ref.read(runtimeAdminRepositoryProvider),
        descriptors: runtimeAdminResources,
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );

  final Ref ref;
}
