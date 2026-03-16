import 'package:flutter/material.dart';

import 'package:mugen_ui/features/runtime_admin/presentation/providers/runtime_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class RuntimeControlPanel extends StatelessWidget {
  const RuntimeControlPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<RuntimeAdminController>(
      controllerProvider: runtimeAdminControllerProvider,
      description:
          'Manage runtime client profiles, runtime defaults, key lifecycles, and platform reload controls.',
    );
  }
}
