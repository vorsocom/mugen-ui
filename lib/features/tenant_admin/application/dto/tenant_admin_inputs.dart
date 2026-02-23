import 'package:mugen_ui/shared/application/pagination.dart';

class TenantListQuery {
  const TenantListQuery({required this.pageRequest, this.searchTerm});

  final PageRequest pageRequest;
  final String? searchTerm;
}

class CreateTenantInput {
  const CreateTenantInput({required this.name, required this.slug});

  final String name;
  final String slug;
}

class UpdateTenantInput {
  const UpdateTenantInput({
    required this.tenantId,
    required this.name,
    required this.slug,
    required this.rowVersion,
  });

  final String tenantId;
  final String name;
  final String slug;
  final int rowVersion;
}

class TenantLifecycleInput {
  const TenantLifecycleInput({
    required this.tenantId,
    required this.rowVersion,
  });

  final String tenantId;
  final int rowVersion;
}

class CreateTenantDomainInput {
  const CreateTenantDomainInput({
    required this.tenantId,
    required this.domain,
    required this.isPrimary,
  });

  final String tenantId;
  final String domain;
  final bool isPrimary;
}

class UpdateTenantDomainInput {
  const UpdateTenantDomainInput({
    required this.tenantId,
    required this.domainId,
    required this.domain,
    required this.isPrimary,
    required this.rowVersion,
  });

  final String tenantId;
  final String domainId;
  final String domain;
  final bool isPrimary;
  final int rowVersion;
}

class DeleteTenantDomainInput {
  const DeleteTenantDomainInput({
    required this.tenantId,
    required this.domainId,
    required this.rowVersion,
  });

  final String tenantId;
  final String domainId;
  final int rowVersion;
}

class CreateTenantInvitationInput {
  const CreateTenantInvitationInput({
    required this.tenantId,
    required this.email,
    required this.roleInTenant,
  });

  final String tenantId;
  final String email;
  final String roleInTenant;
}

class TenantInvitationActionInput {
  const TenantInvitationActionInput({
    required this.tenantId,
    required this.invitationId,
    required this.rowVersion,
  });

  final String tenantId;
  final String invitationId;
  final int rowVersion;
}

class CreateTenantMembershipInput {
  const CreateTenantMembershipInput({
    required this.tenantId,
    required this.userId,
    required this.roleInTenant,
  });

  final String tenantId;
  final String userId;
  final String roleInTenant;
}

class UpdateTenantMembershipInput {
  const UpdateTenantMembershipInput({
    required this.tenantId,
    required this.membershipId,
    required this.roleInTenant,
    required this.rowVersion,
  });

  final String tenantId;
  final String membershipId;
  final String roleInTenant;
  final int rowVersion;
}

class TenantMembershipActionInput {
  const TenantMembershipActionInput({
    required this.tenantId,
    required this.membershipId,
    required this.rowVersion,
  });

  final String tenantId;
  final String membershipId;
  final int rowVersion;
}
