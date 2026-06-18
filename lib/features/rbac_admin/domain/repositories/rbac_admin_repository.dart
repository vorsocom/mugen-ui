import 'package:mugen_ui/features/rbac_admin/application/dto/rbac_admin_inputs.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_entry_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_object_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_permission_type_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_membership_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_role_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_member_entity.dart';
import 'package:mugen_ui/features/rbac_admin/domain/entities/rbac_tenant_summary_entity.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class RbacAdminRepository {
  Future<Result<List<RbacTenantSummaryEntity>>> fetchTenants({int top = 200});

  Future<Result<List<RbacRoleEntity>>> fetchGlobalRoles({int top = 200});
  Future<Result<void>> createGlobalRole(RbacCreateGlobalRoleInput input);
  Future<Result<void>> updateGlobalRole(RbacUpdateGlobalRoleInput input);

  Future<Result<List<RbacRoleEntity>>> fetchTenantRoles({
    required String tenantId,
    int top = 200,
  });
  Future<Result<void>> createTenantRole(RbacCreateTenantRoleInput input);
  Future<Result<void>> updateTenantRole(RbacUpdateTenantRoleInput input);
  Future<Result<void>> deprecateTenantRole(RbacTenantRoleLifecycleInput input);
  Future<Result<void>> reactivateTenantRole(RbacTenantRoleLifecycleInput input);

  Future<Result<List<RbacPermissionObjectEntity>>> fetchPermissionObjects({
    int top = 200,
  });
  Future<Result<void>> createPermissionObject(
    RbacCreatePermissionObjectInput input,
  );
  Future<Result<void>> deprecatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  );
  Future<Result<void>> reactivatePermissionObject(
    RbacPermissionObjectLifecycleInput input,
  );

  Future<Result<List<RbacPermissionTypeEntity>>> fetchPermissionTypes({
    int top = 200,
  });
  Future<Result<void>> createPermissionType(
    RbacCreatePermissionTypeInput input,
  );
  Future<Result<void>> deprecatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  );
  Future<Result<void>> reactivatePermissionType(
    RbacPermissionTypeLifecycleInput input,
  );

  Future<Result<List<RbacPermissionEntryEntity>>> fetchGlobalPermissionEntries({
    int top = 200,
  });
  Future<Result<void>> createGlobalPermissionEntry(
    RbacCreateGlobalPermissionEntryInput input,
  );
  Future<Result<void>> updateGlobalPermissionEntry(
    RbacUpdateGlobalPermissionEntryInput input,
  );
  Future<Result<void>> deleteGlobalPermissionEntry(
    RbacDeleteGlobalPermissionEntryInput input,
  );

  Future<Result<List<RbacPermissionEntryEntity>>> fetchTenantPermissionEntries({
    required String tenantId,
    int top = 200,
  });
  Future<Result<void>> createTenantPermissionEntry(
    RbacCreateTenantPermissionEntryInput input,
  );
  Future<Result<void>> updateTenantPermissionEntry(
    RbacUpdateTenantPermissionEntryInput input,
  );
  Future<Result<void>> deleteTenantPermissionEntry(
    RbacDeleteTenantPermissionEntryInput input,
  );

  Future<Result<List<RbacRoleMembershipEntity>>> fetchTenantRoleMemberships({
    required String tenantId,
    int top = 200,
  });
  Future<Result<List<RbacTenantMemberEntity>>> fetchTenantMembers({
    required String tenantId,
    int top = 200,
  });
  Future<Result<void>> createTenantRoleMembership(
    RbacCreateRoleMembershipInput input,
  );
  Future<Result<void>> deleteTenantRoleMembership(
    RbacDeleteRoleMembershipInput input,
  );
}
