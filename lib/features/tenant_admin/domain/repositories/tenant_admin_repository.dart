import 'package:mugen_ui/features/tenant_admin/application/dto/tenant_admin_inputs.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_domain_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_invitation_entity.dart';
import 'package:mugen_ui/features/tenant_admin/domain/entities/tenant_membership_entity.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class TenantAdminRepository {
  Future<Result<PageResult<TenantEntity>>> fetchTenants(TenantListQuery query);

  Future<Result<void>> createTenant(CreateTenantInput input);
  Future<Result<void>> updateTenant(UpdateTenantInput input);
  Future<Result<void>> deactivateTenant(TenantLifecycleInput input);
  Future<Result<void>> reactivateTenant(TenantLifecycleInput input);

  Future<Result<List<TenantDomainEntity>>> fetchTenantDomains({
    required String tenantId,
    int top = 100,
  });
  Future<Result<void>> createTenantDomain(CreateTenantDomainInput input);
  Future<Result<void>> updateTenantDomain(UpdateTenantDomainInput input);
  Future<Result<void>> deleteTenantDomain(DeleteTenantDomainInput input);

  Future<Result<List<TenantInvitationEntity>>> fetchTenantInvitations({
    required String tenantId,
    int top = 100,
  });
  Future<Result<void>> createTenantInvitation(
    CreateTenantInvitationInput input,
  );
  Future<Result<void>> resendTenantInvitation(
    TenantInvitationActionInput input,
  );
  Future<Result<void>> revokeTenantInvitation(
    TenantInvitationActionInput input,
  );

  Future<Result<List<TenantMembershipEntity>>> fetchTenantMemberships({
    required String tenantId,
    int top = 100,
  });
  Future<Result<void>> createTenantMembership(
    CreateTenantMembershipInput input,
  );
  Future<Result<void>> updateTenantMembership(
    UpdateTenantMembershipInput input,
  );
  Future<Result<void>> suspendTenantMembership(
    TenantMembershipActionInput input,
  );
  Future<Result<void>> unsuspendTenantMembership(
    TenantMembershipActionInput input,
  );
  Future<Result<void>> removeTenantMembership(
    TenantMembershipActionInput input,
  );
}
