import 'package:flutter/material.dart';

import 'package:mugen_ui/features/core_provisioning/presentation/providers/core_provisioning_providers.dart';
import 'package:mugen_ui/features/core_provisioning/application/billing_workspace_target.dart';
import 'package:mugen_ui/shared/presentation/acp_admin/acp_admin_panel.dart';

class BillingOperationsPanel extends StatelessWidget {
  const BillingOperationsPanel({
    super.key,
    this.target,
  }); // coverage:ignore-line

  final BillingWorkspaceTarget? target;

  @override
  Widget build(BuildContext context) {
    return AcpAdminPanel<BillingOperationsController>(
      controllerProvider: billingOperationsControllerProvider,
      title: 'Billing Operations',
      description:
          'Manage tenant adoption, generated entitlements, billing executions, invoices, payments, corrections, allocations, and ledger records.',
      initialResourceKey: target?.workspace == BillingWorkspace.operations
          ? target?.resourceKey
          : null,
      initialTenantId: target?.workspace == BillingWorkspace.operations
          ? target?.tenantId
          : null,
      initialRowId: target?.workspace == BillingWorkspace.operations
          ? target?.rowId
          : null,
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
