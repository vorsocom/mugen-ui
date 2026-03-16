import 'package:flutter/material.dart';

import 'package:mugen_ui/features/context_admin/presentation/providers/context_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class ContextEnginePanel extends StatelessWidget {
  const ContextEnginePanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<ContextAdminController>(
      controllerProvider: contextAdminControllerProvider,
      description:
          'Configure context profiles, policies, contributor/source bindings, and trace capture behavior.',
    );
  }
}
