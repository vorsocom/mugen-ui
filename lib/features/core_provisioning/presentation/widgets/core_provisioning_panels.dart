import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_workspace_navigation.dart';

class BillingOperationsPanel extends ConsumerWidget {
  const BillingOperationsPanel({
    super.key,
    this.target,
  }); // coverage:ignore-line

  final BillingWorkspaceTarget? target;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaceTarget = ref.watch(acpWorkspaceNavigationProvider);
    final routeTarget = workspaceTarget?.routeId == RouteIds.billingOperations
        ? workspaceTarget
        : null;
    return AcpAdminPanel<BillingOperationsController>(
      key: ValueKey<String?>(
        routeTarget == null
            ? null
            : '${routeTarget.resourceKey}:${routeTarget.rowId}:${routeTarget.filterValues}',
      ),
      controllerProvider: billingOperationsControllerProvider,
      title: 'Billing Operations',
      description:
          'Manage tenant adoption, generated entitlements, billing executions, invoices, payments, corrections, allocations, and ledger records.',
      initialResourceKey: target?.workspace == BillingWorkspace.operations
          ? target?.resourceKey
          : routeTarget?.resourceKey,
      initialTenantId: target?.workspace == BillingWorkspace.operations
          ? target?.tenantId
          : routeTarget?.tenantId,
      initialRowId: target?.workspace == BillingWorkspace.operations
          ? target?.rowId
          : routeTarget?.rowId,
      initialFilterValues:
          routeTarget?.filterValues ?? const <String, String>{},
    );
  }
}

class ConnectorsPanel extends StatelessWidget {
  const ConnectorsPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<ConnectorAdminController>(
      controllerProvider: connectorAdminControllerProvider,
      title: 'Connectors',
      description:
          'Manage global connector contracts, tenant instances, guarded calls, and redacted diagnostics.',
    );
  }
}

class GovernancePanel extends StatelessWidget {
  const GovernancePanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<GovernanceAdminController>(
      controllerProvider: governanceAdminControllerProvider,
      title: 'Governance',
      description:
          'Edit policy documents, evaluate active policies, and activate policy versions.',
    );
  }
}

class WorkflowsPanel extends StatelessWidget {
  const WorkflowsPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<WorkflowAdminController>(
      controllerProvider: workflowAdminControllerProvider,
      title: 'Workflows',
      description:
          'Provision workflow definitions, versions, states, and searchable transitions.',
    );
  }
}

class SlaPanel extends StatelessWidget {
  const SlaPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<SlaAdminController>(
      controllerProvider: slaAdminControllerProvider,
      title: 'SLA',
      description:
          'Configure SLA policies, timezone-aware business calendars, and typed targets.',
    );
  }
}

class ReportingPanel extends StatelessWidget {
  const ReportingPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<ReportingAdminController>(
      controllerProvider: reportingAdminControllerProvider,
      title: 'Reporting',
      description:
          'Configure metrics and reports, run timezone-aware aggregations, and inspect generated data.',
    );
  }
}
