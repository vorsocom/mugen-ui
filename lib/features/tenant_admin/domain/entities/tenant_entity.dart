class TenantEntity {
  const TenantEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String name;
  final String slug;
  final String status;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
