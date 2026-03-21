class RbacTenantSummaryEntity {
  const RbacTenantSummaryEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.rowVersion,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final int rowVersion;
}
