import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';

void main() {
  test('constructors preserve RBAC input fields', () {
    final createTenantRole = RbacCreateTenantRoleInput(
      tenantId: 'tenant-1',
      namespace: 'acp',
      name: 'viewer',
      displayName: 'Viewer',
    );
    expect(createTenantRole.tenantId, 'tenant-1');
    expect(createTenantRole.namespace, 'acp');
    expect(createTenantRole.name, 'viewer');
    expect(createTenantRole.displayName, 'Viewer');

    final updateTenantRole = RbacUpdateTenantRoleInput(
      tenantId: 'tenant-1',
      roleId: 'role-1',
      displayName: 'Viewer Plus',
      rowVersion: 8,
    );
    expect(updateTenantRole.tenantId, 'tenant-1');
    expect(updateTenantRole.roleId, 'role-1');
    expect(updateTenantRole.displayName, 'Viewer Plus');
    expect(updateTenantRole.rowVersion, 8);

    final createPermissionObject = RbacCreatePermissionObjectInput(
      namespace: 'acp',
      name: 'tenant',
    );
    expect(createPermissionObject.namespace, 'acp');
    expect(createPermissionObject.name, 'tenant');

    final createPermissionType = RbacCreatePermissionTypeInput(
      namespace: 'acp',
      name: 'manage',
    );
    expect(createPermissionType.namespace, 'acp');
    expect(createPermissionType.name, 'manage');

    final createGlobalEntry = RbacCreateGlobalPermissionEntryInput(
      globalRoleId: 'gr-1',
      permissionObjectId: 'po-1',
      permissionTypeId: 'pt-1',
      permitted: true,
    );
    expect(createGlobalEntry.globalRoleId, 'gr-1');
    expect(createGlobalEntry.permissionObjectId, 'po-1');
    expect(createGlobalEntry.permissionTypeId, 'pt-1');
    expect(createGlobalEntry.permitted, isTrue);

    final createTenantEntry = RbacCreateTenantPermissionEntryInput(
      tenantId: 'tenant-1',
      roleId: 'tr-1',
      permissionObjectId: 'po-1',
      permissionTypeId: 'pt-1',
      permitted: false,
    );
    expect(createTenantEntry.tenantId, 'tenant-1');
    expect(createTenantEntry.roleId, 'tr-1');
    expect(createTenantEntry.permissionObjectId, 'po-1');
    expect(createTenantEntry.permissionTypeId, 'pt-1');
    expect(createTenantEntry.permitted, isFalse);
  });
}
