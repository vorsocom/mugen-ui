import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_admin_controller.dart';
import 'package:mugen_ui/features/billing_catalog/presentation/providers/billing_catalog_providers.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class BillingCatalogPanel extends ConsumerWidget {
  const BillingCatalogPanel({super.key, this.target});

  final BillingWorkspaceTarget? target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceTarget = ref.watch(acpWorkspaceNavigationProvider);
    final routeTarget = workspaceTarget?.routeId == RouteIds.billingCatalog
        ? workspaceTarget
        : null;
    final isAdministrator =
        ref
            .watch(authControllerProvider)
            .session
            ?.roles
            .contains('$acpNamespace:administrator') ??
        false;
    return AcpAdminPanel<BillingCatalogAdminController>(
      key: ValueKey<String?>(
        routeTarget == null
            ? null
            : '${routeTarget.resourceKey}:${routeTarget.rowId}:${routeTarget.filterValues}',
      ),
      controllerProvider: billingCatalogAdminControllerProvider,
      title: 'Billing Catalog',
      description:
          'Manage reusable global products, metering, schedules, currencies, tax, terms, templates, and discounts. Tenant selection never changes this workspace.',
      mutationsEnabled: isAdministrator,
      initialResourceKey: target?.workspace == BillingWorkspace.catalog
          ? target?.resourceKey
          : routeTarget?.resourceKey,
      initialRowId: target?.workspace == BillingWorkspace.catalog
          ? target?.rowId
          : routeTarget?.rowId,
      initialFilterValues:
          routeTarget?.filterValues ?? const <String, String>{},
    );
  }
}
