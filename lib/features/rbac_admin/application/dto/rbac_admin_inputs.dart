class RbacCreateGlobalRoleInput {
  const RbacCreateGlobalRoleInput({
    required this.namespace,
    required this.name,
    required this.displayName,
  });

  final String namespace;
  final String name;
  final String displayName;
}

class RbacUpdateGlobalRoleInput {
  const RbacUpdateGlobalRoleInput({
    required this.roleId,
    required this.displayName,
    required this.rowVersion,
  });

  final String roleId;
  final String displayName;
  final int rowVersion;
}

class RbacCreateTenantRoleInput {
  const RbacCreateTenantRoleInput({
    required this.tenantId,
    required this.namespace,
    required this.name,
    required this.displayName,
  });

  final String tenantId;
  final String namespace;
  final String name;
  final String displayName;
}

class RbacUpdateTenantRoleInput {
  const RbacUpdateTenantRoleInput({
    required this.tenantId,
    required this.roleId,
    required this.displayName,
    required this.rowVersion,
  });

  final String tenantId;
  final String roleId;
  final String displayName;
  final int rowVersion;
}

class RbacTenantRoleLifecycleInput {
  const RbacTenantRoleLifecycleInput({
    required this.tenantId,
    required this.roleId,
    required this.rowVersion,
  });

  final String tenantId;
  final String roleId;
  final int rowVersion;
}

class RbacCreatePermissionObjectInput {
  const RbacCreatePermissionObjectInput({
    required this.namespace,
    required this.name,
  });

  final String namespace;
  final String name;
}

class RbacPermissionObjectLifecycleInput {
  const RbacPermissionObjectLifecycleInput({
    required this.permissionObjectId,
    required this.rowVersion,
  });

  final String permissionObjectId;
  final int rowVersion;
}

class RbacCreatePermissionTypeInput {
  const RbacCreatePermissionTypeInput({
    required this.namespace,
    required this.name,
  });

  final String namespace;
  final String name;
}

class RbacPermissionTypeLifecycleInput {
  const RbacPermissionTypeLifecycleInput({
    required this.permissionTypeId,
    required this.rowVersion,
  });

  final String permissionTypeId;
  final int rowVersion;
}

class RbacCreateGlobalPermissionEntryInput {
  const RbacCreateGlobalPermissionEntryInput({
    required this.globalRoleId,
    required this.permissionObjectId,
    required this.permissionTypeId,
    required this.permitted,
  });

  final String globalRoleId;
  final String permissionObjectId;
  final String permissionTypeId;
  final bool permitted;
}

class RbacUpdateGlobalPermissionEntryInput {
  const RbacUpdateGlobalPermissionEntryInput({
    required this.entryId,
    required this.rowVersion,
    required this.permitted,
  });

  final String entryId;
  final int rowVersion;
  final bool permitted;
}

class RbacDeleteGlobalPermissionEntryInput {
  const RbacDeleteGlobalPermissionEntryInput({
    required this.entryId,
    required this.rowVersion,
  });

  final String entryId;
  final int rowVersion;
}

class RbacCreateTenantPermissionEntryInput {
  const RbacCreateTenantPermissionEntryInput({
    required this.tenantId,
    required this.roleId,
    required this.permissionObjectId,
    required this.permissionTypeId,
    required this.permitted,
  });

  final String tenantId;
  final String roleId;
  final String permissionObjectId;
  final String permissionTypeId;
  final bool permitted;
}

class RbacUpdateTenantPermissionEntryInput {
  const RbacUpdateTenantPermissionEntryInput({
    required this.tenantId,
    required this.entryId,
    required this.rowVersion,
    required this.permitted,
  });

  final String tenantId;
  final String entryId;
  final int rowVersion;
  final bool permitted;
}

class RbacDeleteTenantPermissionEntryInput {
  const RbacDeleteTenantPermissionEntryInput({
    required this.tenantId,
    required this.entryId,
    required this.rowVersion,
  });

  final String tenantId;
  final String entryId;
  final int rowVersion;
}

class RbacCreateRoleMembershipInput {
  const RbacCreateRoleMembershipInput({
    required this.tenantId,
    required this.roleId,
    required this.userId,
  });

  final String tenantId;
  final String roleId;
  final String userId;
}

class RbacDeleteRoleMembershipInput {
  const RbacDeleteRoleMembershipInput({
    required this.tenantId,
    required this.membershipId,
    required this.rowVersion,
  });

  final String tenantId;
  final String membershipId;
  final int rowVersion;
}
