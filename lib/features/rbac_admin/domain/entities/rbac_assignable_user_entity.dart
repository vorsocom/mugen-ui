class RbacAssignableUserEntity {
  const RbacAssignableUserEntity({
    required this.id,
    required this.username,
    required this.displayName,
    required this.email,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String username;
  final String displayName;
  final String email;
  final bool deleted;
  final bool seedData;
}
