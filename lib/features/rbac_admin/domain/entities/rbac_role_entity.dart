class RbacRoleEntity {
  const RbacRoleEntity({
    required this.id,
    required this.namespace,
    required this.name,
    required this.displayName,
    required this.status,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.tenantId,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String namespace;
  final String name;
  final String displayName;
  final String status;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final String? tenantId;
  final bool deleted;
  final bool seedData;

  String get key {
    if (namespace.isEmpty || name.isEmpty) {
      return displayName;
    }
    return '$namespace:$name';
  }
}
