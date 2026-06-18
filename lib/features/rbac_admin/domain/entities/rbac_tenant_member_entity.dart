class RbacTenantMemberEntity {
  const RbacTenantMemberEntity({
    required this.membershipId,
    required this.tenantId,
    required this.userId,
    required this.displayName,
    required this.email,
    required this.status,
    required this.deleted,
  });

  final String membershipId;
  final String tenantId;
  final String userId;
  final String displayName;
  final String email;
  final String status;
  final bool deleted;
}
