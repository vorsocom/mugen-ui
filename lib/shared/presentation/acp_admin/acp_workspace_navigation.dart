import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';

class AcpWorkspaceNavigationController extends Notifier<AcpWorkspaceTarget?> {
  @override
  AcpWorkspaceTarget? build() => null;

  void open(AcpWorkspaceTarget target) {
    state = target;
    ref.read(shellControllerProvider.notifier).setRoute(target.routeId);
  }

  void clear() {
    state = null;
  }
}

final acpWorkspaceNavigationProvider =
    NotifierProvider<AcpWorkspaceNavigationController, AcpWorkspaceTarget?>(
      AcpWorkspaceNavigationController.new,
    );

Future<void> openAcpWorkspace(WidgetRef ref, AcpWorkspaceTarget target) async {
  ref.read(acpWorkspaceNavigationProvider.notifier).open(target);
}
