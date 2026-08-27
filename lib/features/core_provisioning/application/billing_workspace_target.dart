enum BillingWorkspace { catalog, operations }

class BillingWorkspaceTarget {
  const BillingWorkspaceTarget({
    required this.workspace,
    required this.resourceKey,
    this.tenantId,
    this.rowId,
  });

  final BillingWorkspace workspace;
  final String resourceKey;
  final String? tenantId;
  final String? rowId;
}
