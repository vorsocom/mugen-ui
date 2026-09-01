import 'package:mugen_ui/shared/application/acp_admin/acp_admin_models.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class FixedAcpWorkspaceNavigationController
    extends AcpWorkspaceNavigationController {
  FixedAcpWorkspaceNavigationController(this.target);

  final AcpWorkspaceTarget target;

  @override
  AcpWorkspaceTarget? build() => target;
}
