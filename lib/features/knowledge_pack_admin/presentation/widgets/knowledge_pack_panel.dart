import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/knowledge_pack_admin/presentation/providers/knowledge_pack_admin_providers.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class KnowledgePackPanel extends ConsumerWidget {
  const KnowledgePackPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = ref.watch(acpWorkspaceNavigationProvider);
    final routeTarget = target?.routeId == RouteIds.knowledgePacks
        ? target
        : null;
    return AcpAdminPanel<KnowledgePackAdminController>(
      key: ValueKey<String?>(
        routeTarget == null
            ? null
            : '${routeTarget.resourceKey}:${routeTarget.rowId}:${routeTarget.filterValues}',
      ),
      controllerProvider: knowledgePackAdminControllerProvider,
      title: 'Knowledge Packs',
      description:
          'Manage knowledge packs, lifecycle versions, searchable projections, entries, approvals, and retrieval scopes.',
      initialResourceKey: routeTarget?.resourceKey,
      initialTenantId: routeTarget?.tenantId,
      initialRowId: routeTarget?.rowId,
      initialFilterValues:
          routeTarget?.filterValues ?? const <String, String>{},
      onNavigate: (next) => openAcpWorkspace(ref, next),
    );
  }
}
