import 'package:flutter/material.dart';

import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class ChannelOrchestrationPanel extends StatelessWidget {
  const ChannelOrchestrationPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<OrchestrationAdminController>(
      controllerProvider: orchestrationAdminControllerProvider,
      description:
          'Configure channel intake, routing, throttling, moderation, operational state, and replayable work items.',
    );
  }
}
