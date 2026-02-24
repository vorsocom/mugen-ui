class RbacPermissionObjectEntity {
  const RbacPermissionObjectEntity({
    required this.id,
    required this.namespace,
    required this.name,
    required this.status,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String namespace;
  final String name;
  final String status;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;

  String get key {
    if (namespace.isEmpty || name.isEmpty) {
      return name;
    }
    return '$namespace:$name';
  }
}
