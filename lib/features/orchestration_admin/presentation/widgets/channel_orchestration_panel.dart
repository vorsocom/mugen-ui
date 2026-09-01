import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/orchestration_admin/presentation/providers/orchestration_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class ChannelOrchestrationPanel extends ConsumerWidget {
  const ChannelOrchestrationPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(acpWorkspaceNavigationProvider);
    final routeTarget = target?.routeId == RouteIds.channelOrchestration
        ? target
        : null;
    return AcpAdminPanel<OrchestrationAdminController>(
      key: ValueKey<String?>(
        routeTarget == null
            ? null
            : '${routeTarget.resourceKey}:${routeTarget.rowId}:${routeTarget.filterValues}',
      ),
      controllerProvider: orchestrationAdminControllerProvider,
      title: 'Channel Orchestration',
      description:
          'Configure channel intake, routing, throttling, moderation, operational state, and replayable work items.',
      initialResourceKey: routeTarget?.resourceKey,
      initialTenantId: routeTarget?.tenantId,
      initialRowId: routeTarget?.rowId,
      initialFilterValues:
          routeTarget?.filterValues ?? const <String, String>{},
    );
  }
}
