import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/application/knowledge_pack_admin_resources.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_controller.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_repository.dart';
import 'package:mugen_ui/shared/infrastructure/acp_admin/acp_admin_repository_impl.dart';

final knowledgePackAdminRepositoryProvider = Provider<AcpAdminRepository>((
  ref,
) {
  return AcpAdminRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    authenticatedHttpClient: ref.watch(authenticatedHttpClientProvider),
  );
});

final knowledgePackAdminControllerProvider =
    StateNotifierProvider<KnowledgePackAdminController, AcpAdminState>((ref) {
      return KnowledgePackAdminController(ref);
    });

class KnowledgePackAdminController extends AcpAdminController {
  KnowledgePackAdminController(this.ref)
    : super(
        repository: ref.read(knowledgePackAdminRepositoryProvider),
        descriptors: knowledgePackAdminResources,
        onSessionExpired: () {
          ref.read(authControllerProvider.notifier).refreshSession();
        },
      );

  final Ref ref;
}
