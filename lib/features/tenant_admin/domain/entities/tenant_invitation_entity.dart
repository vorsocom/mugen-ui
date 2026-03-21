class TenantInvitationEntity {
  const TenantInvitationEntity({
    required this.id,
    required this.tenantId,
    required this.email,
    required this.roleInTenant,
    required this.status,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.expiresAt,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String tenantId;
  final String email;
  final String roleInTenant;
  final String status;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final DateTime? expiresAt;
  final bool deleted;
  final bool seedData;
}
