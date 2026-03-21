class TenantDomainEntity {
  const TenantDomainEntity({
    required this.id,
    required this.tenantId,
    required this.domain,
    required this.isPrimary,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String tenantId;
  final String domain;
  final bool isPrimary;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
