// coverage:ignore-file
import 'package:mugen_ui/shared/application/pagination.dart';

enum AuditAdminScopeMode { global, tenant }

class AuditEventListQuery {
  const AuditEventListQuery({
    required this.pageRequest,
    required this.scopeMode,
    this.searchTerm,
    this.tenantId,
  });

  final PageRequest pageRequest;
  final AuditAdminScopeMode scopeMode;
  final String? searchTerm;
  final String? tenantId;
}

class AuditPlaceLegalHoldInput {
  const AuditPlaceLegalHoldInput({
    required this.eventId,
    required this.rowVersion,
    required this.reason,
    required this.scopeMode,
    this.tenantId,
    this.legalHoldUntil,
  });

  final String eventId;
  final int rowVersion;
  final String reason;
  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
  final DateTime? legalHoldUntil;
}

class AuditReleaseLegalHoldInput {
  const AuditReleaseLegalHoldInput({
    required this.eventId,
    required this.rowVersion,
    required this.reason,
    required this.scopeMode,
    this.tenantId,
  });

  final String eventId;
  final int rowVersion;
  final String reason;
  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
}

class AuditRedactInput {
  const AuditRedactInput({
    required this.eventId,
    required this.rowVersion,
    required this.reason,
    required this.scopeMode,
    this.tenantId,
  });

  final String eventId;
  final int rowVersion;
  final String reason;
  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
}

class AuditTombstoneInput {
  const AuditTombstoneInput({
    required this.eventId,
    required this.rowVersion,
    required this.reason,
    required this.scopeMode,
    this.tenantId,
    this.purgeAfterDays,
  });

  final String eventId;
  final int rowVersion;
  final String reason;
  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
  final int? purgeAfterDays;
}

class AuditRunLifecycleInput {
  const AuditRunLifecycleInput({
    required this.scopeMode,
    this.tenantId,
    this.batchSize,
    this.maxBatches,
    this.dryRun = true,
    this.nowOverride,
    this.phases,
  });

  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
  final int? batchSize;
  final int? maxBatches;
  final bool dryRun;
  final DateTime? nowOverride;
  final List<String>? phases;
}

class AuditVerifyChainInput {
  const AuditVerifyChainInput({
    required this.scopeMode,
    this.tenantId,
    this.fromOccurredAt,
    this.toOccurredAt,
    this.maxRows,
    this.requireClean = false,
  });

  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
  final DateTime? fromOccurredAt;
  final DateTime? toOccurredAt;
  final int? maxRows;
  final bool requireClean;
}

class AuditSealBacklogInput {
  const AuditSealBacklogInput({
    required this.scopeMode,
    this.tenantId,
    this.batchSize,
    this.maxBatches,
  });

  final AuditAdminScopeMode scopeMode;
  final String? tenantId;
  final int? batchSize;
  final int? maxBatches;
}
