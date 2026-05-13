class TenantMembershipEntity {
  const TenantMembershipEntity({
    required this.id,
    required this.tenantId,
    required this.userId,
    required this.roleInTenant,
    required this.status,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
    this.userName,
    this.userEmail,
  });

  final String id;
  final String tenantId;
  final String userId;
  final String roleInTenant;
  final String status;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
  final String? userName;
  final String? userEmail;
}
