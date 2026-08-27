import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/billing_catalog/application/billing_catalog_admin_controller.dart';
import 'package:mugen_ui/features/billing_catalog/presentation/providers/billing_catalog_providers.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class BillingCatalogPanel extends ConsumerWidget {
  const BillingCatalogPanel({super.key, this.target});

  final BillingWorkspaceTarget? target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdministrator =
        ref
            .watch(authControllerProvider)
            .session
            ?.roles
            .contains('$acpNamespace:administrator') ??
        false;
    return AcpAdminPanel<BillingCatalogAdminController>(
      controllerProvider: billingCatalogAdminControllerProvider,
      title: 'Billing Catalog',
      description:
          'Manage reusable global products, metering, schedules, currencies, tax, terms, templates, and discounts. Tenant selection never changes this workspace.',
      mutationsEnabled: isAdministrator,
      initialResourceKey: target?.workspace == BillingWorkspace.catalog
          ? target?.resourceKey
          : null,
      initialRowId: target?.workspace == BillingWorkspace.catalog
          ? target?.rowId
          : null,
    );
  }
}
