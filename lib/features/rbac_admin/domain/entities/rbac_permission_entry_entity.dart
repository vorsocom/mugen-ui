class RbacPermissionEntryEntity {
  const RbacPermissionEntryEntity({
    required this.id,
    required this.tenantId,
    required this.roleId,
    required this.roleDisplayName,
    required this.permissionObjectId,
    required this.permissionObjectDisplayName,
    required this.permissionTypeId,
    required this.permissionTypeDisplayName,
    required this.permitted,
    required this.rowVersion,
    required this.dateCreated,
    required this.dateLastModified,
    required this.deleted,
    required this.seedData,
  });

  final String id;
  final String? tenantId;
  final String roleId;
  final String roleDisplayName;
  final String permissionObjectId;
  final String permissionObjectDisplayName;
  final String permissionTypeId;
  final String permissionTypeDisplayName;
  final bool permitted;
  final int rowVersion;
  final DateTime dateCreated;
  final DateTime dateLastModified;
  final bool deleted;
  final bool seedData;
}
