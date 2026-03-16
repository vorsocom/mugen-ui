import 'package:flutter/material.dart';

import 'package:mugen_ui/features/acp_console/presentation/providers/acp_console_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class AcpConsolePanel extends StatelessWidget {
  const AcpConsolePanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<AcpConsoleController>(
      controllerProvider: acpConsoleControllerProvider,
      description:
          'Advanced descriptor-driven ACP console for long-tail resources that do not yet have dedicated forms.',
    );
  }
}
