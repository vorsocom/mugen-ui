import 'package:mugen_ui/features/audit_admin/application/dto/audit_admin_inputs.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_chain_verification_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_event_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_lifecycle_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_seal_backlog_summary_entity.dart';
import 'package:mugen_ui/features/audit_admin/domain/entities/audit_tenant_option_entity.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/domain/result.dart';

abstract class AuditAdminRepository {
  Future<Result<PageResult<AuditEventEntity>>> fetchAuditEvents(
    AuditEventListQuery query,
  );

  Future<Result<List<AuditTenantOptionEntity>>> fetchTenants({int top = 200});

  Future<Result<void>> placeLegalHold(AuditPlaceLegalHoldInput input);
  Future<Result<void>> releaseLegalHold(AuditReleaseLegalHoldInput input);
  Future<Result<void>> redactEvent(AuditRedactInput input);
  Future<Result<void>> tombstoneEvent(AuditTombstoneInput input);

  Future<Result<AuditLifecycleSummaryEntity>> runLifecycle(
    AuditRunLifecycleInput input,
  );

  Future<Result<AuditChainVerificationSummaryEntity>> verifyChain(
    AuditVerifyChainInput input,
  );

  Future<Result<AuditSealBacklogSummaryEntity>> sealBacklog(
    AuditSealBacklogInput input,
  );
}
