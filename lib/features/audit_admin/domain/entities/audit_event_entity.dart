class AuditEventEntity {
  const AuditEventEntity({
    required this.id,
    required this.rowVersion,
    required this.tenantId,
    required this.actorId,
    required this.entitySet,
    required this.entity,
    required this.entityId,
    required this.operation,
    required this.actionName,
    required this.occurredAt,
    required this.outcome,
    required this.requestId,
    required this.correlationId,
    required this.sourcePlugin,
    required this.changedFields,
    required this.beforeSnapshot,
    required this.afterSnapshot,
    required this.meta,
    required this.scopeKey,
    required this.scopeSeq,
    required this.prevEntryHash,
    required this.entryHash,
    required this.hashAlg,
    required this.hashKeyId,
    required this.beforeSnapshotHash,
    required this.afterSnapshotHash,
    required this.sealedAt,
    required this.retentionUntil,
    required this.redactionDueAt,
    required this.redactedAt,
    required this.redactionReason,
    required this.legalHoldAt,
    required this.legalHoldUntil,
    required this.legalHoldByUserId,
    required this.legalHoldReason,
    required this.legalHoldReleasedAt,
    required this.legalHoldReleasedByUserId,
    required this.legalHoldReleaseReason,
    required this.tombstonedAt,
    required this.tombstonedByUserId,
    required this.tombstoneReason,
    required this.purgeDueAt,
  });

  final String id;
  final int rowVersion;

  final String? tenantId;
  final String? actorId;

  final String entitySet;
  final String entity;
  final String? entityId;

  final String operation;
  final String? actionName;
  final DateTime occurredAt;
  final String outcome;

  final String? requestId;
  final String? correlationId;
  final String sourcePlugin;

  final List<String> changedFields;
  final Map<String, dynamic>? beforeSnapshot;
  final Map<String, dynamic>? afterSnapshot;
  final Map<String, dynamic>? meta;

  final String scopeKey;
  final int? scopeSeq;
  final String? prevEntryHash;
  final String? entryHash;
  final String hashAlg;
  final String? hashKeyId;
  final String? beforeSnapshotHash;
  final String? afterSnapshotHash;
  final DateTime? sealedAt;

  final DateTime? retentionUntil;
  final DateTime? redactionDueAt;
  final DateTime? redactedAt;
  final String? redactionReason;
  final DateTime? legalHoldAt;
  final DateTime? legalHoldUntil;
  final String? legalHoldByUserId;
  final String? legalHoldReason;
  final DateTime? legalHoldReleasedAt;
  final String? legalHoldReleasedByUserId;
  final String? legalHoldReleaseReason;
  final DateTime? tombstonedAt;
  final String? tombstonedByUserId;
  final String? tombstoneReason;
  final DateTime? purgeDueAt;

  bool get hasLegalHold {
    return legalHoldAt != null && legalHoldReleasedAt == null;
  }

  bool get isRedacted {
    return redactedAt != null;
  }

  bool get isTombstoned {
    return tombstonedAt != null;
  }
}
