class UserRoleEntity {
  const UserRoleEntity({
    required this.id,
    required this.name,
    required this.displayName,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String name;
  final String displayName;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
