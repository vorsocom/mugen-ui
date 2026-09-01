import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/service_profile_admin/presentation/providers/service_profile_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class ServiceProfilePanel extends ConsumerWidget {
  const ServiceProfilePanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resources = ref.watch(serviceProfileAdminResourcesProvider);
    final target = ref.watch(acpWorkspaceNavigationProvider);
    final routeTarget = target?.routeId == RouteIds.serviceProfiles
        ? target
        : null;
    return AcpAdminPanel<ServiceProfileAdminController>(
      key: ValueKey<String?>(
        '${resources.map((item) => item.key).join(',')}:${routeTarget?.resourceKey}:${routeTarget?.rowId}:${routeTarget?.filterValues}',
      ),
      controllerProvider: serviceProfileAdminControllerProvider,
      title: 'Service Profiles',
      description:
          'Manage stable service identities, ingress endpoint routing, and exact Product access without conflating tenant administration, billing ownership, or downstream behavior.',
      initialResourceKey: routeTarget?.resourceKey,
      initialTenantId: routeTarget?.tenantId,
      initialRowId: routeTarget?.rowId,
      initialFilterValues:
          routeTarget?.filterValues ?? const <String, String>{},
      onNavigate: (next) => openAcpWorkspace(ref, next),
    );
  }
}
