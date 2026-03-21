class AuditTenantOptionEntity {
  const AuditTenantOptionEntity({
    required this.id,
    required this.name,
    required this.slug,
    required this.status,
  });

  final String id;
  final String name;
  final String slug;
  final String status;

  String get label => '$name ($slug)';
}
