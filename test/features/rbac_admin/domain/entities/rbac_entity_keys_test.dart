import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';

void main() {
  test(
    'RBAC role key falls back to displayName when namespace/name is empty',
    () {
      final role = RbacRoleEntity(
        id: 'role-1',
        namespace: '',
        name: 'viewer',
        displayName: 'Viewer',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2026, 1, 1),
        dateLastModified: DateTime.utc(2026, 1, 2),
        tenantId: null,
        deleted: false,
        seedData: false,
      );

      expect(role.key, 'Viewer');
    },
  );

  test(
    'RBAC permission object/type keys fall back to name when namespace is empty',
    () {
      final permissionObject = RbacPermissionObjectEntity(
        id: 'po-1',
        namespace: '',
        name: 'tenant',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2026, 1, 1),
        dateLastModified: DateTime.utc(2026, 1, 2),
        deleted: false,
        seedData: false,
      );
      expect(permissionObject.key, 'tenant');

      final permissionType = RbacPermissionTypeEntity(
        id: 'pt-1',
        namespace: '',
        name: 'manage',
        status: 'active',
        rowVersion: 1,
        dateCreated: DateTime.utc(2026, 1, 1),
        dateLastModified: DateTime.utc(2026, 1, 2),
        deleted: false,
        seedData: false,
      );
      expect(permissionType.key, 'manage');
    },
  );
}
