import 'package:flutter/material.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/acp_console/presentation/widgets/acp_console_panel.dart';
import 'package:mugen_ui/features/audit_admin/presentation/widgets/audit_management_panel.dart';
import 'package:mugen_ui/features/chat/presentation/pages/chat_page.dart';
import 'package:mugen_ui/features/context_admin/presentation/widgets/context_engine_panel.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/widgets/channel_orchestration_panel.dart';
import 'package:mugen_ui/features/rbac_admin/presentation/widgets/rbac_management_panel.dart';
import 'package:mugen_ui/features/tenant_admin/presentation/widgets/tenant_management_panel.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/features/runtime_admin/presentation/widgets/runtime_control_panel.dart';

Widget buildSpaRouteWidget(String route) {
  switch (route) {
    case RouteIds.dashboard:
    case RouteIds.chat:
      return const ChatPage();
    case RouteIds.localUsers:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: LocalUserPanel(),
      );
    case RouteIds.tenantManagement:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: TenantManagementPanel(),
      );
    case RouteIds.rolePermissionManagement:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: RbacManagementPanel(),
      );
    case RouteIds.auditManagement:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AuditManagementPanel(),
      );
    case RouteIds.runtimeControl:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: RuntimeControlPanel(),
      );
    case RouteIds.channelOrchestration:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ChannelOrchestrationPanel(),
      );
    case RouteIds.contextEngine:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: ContextEnginePanel(),
      );
    case RouteIds.acpConsole:
      return const Padding(
        padding: EdgeInsets.all(16),
        child: AcpConsolePanel(),
      );
    default:
      return const _RoutePlaceholder(
        title: 'Unknown route',
        description: 'The selected route is not configured.',
      );
  }
}

class _RoutePlaceholder extends StatelessWidget {
  const _RoutePlaceholder({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(description),
          ],
        ),
      ),
    );
  }
}
