class RbacRoleMembershipEntity {
  const RbacRoleMembershipEntity({
    required this.id,
    required this.tenantId,
    required this.roleId,
    required this.userId,
    required this.roleDisplayName,
    required this.roleKey,
    required this.roleNamespace,
    required this.roleName,
    required this.userDisplayName,
    required this.userEmail,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String tenantId;
  final String roleId;
  final String userId;
  final String roleDisplayName;
  final String roleKey;
  final String roleNamespace;
  final String roleName;
  final String userDisplayName;
  final String userEmail;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
