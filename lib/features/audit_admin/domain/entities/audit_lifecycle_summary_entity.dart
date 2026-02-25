class AuditLifecyclePhaseSummaryEntity {
  const AuditLifecyclePhaseSummaryEntity({
    required this.rowsProcessed,
    required this.remainingCount,
    required this.batches,
  });

  final int rowsProcessed;
  final int remainingCount;
  final int batches;
}

class AuditLifecycleSummaryEntity {
  const AuditLifecycleSummaryEntity({
    required this.dryRun,
    required this.now,
    required this.batchSize,
    required this.maxBatches,
    required this.phases,
    required this.totalProcessed,
  });

  final bool dryRun;
  final DateTime? now;
  final int batchSize;
  final int maxBatches;
  final Map<String, AuditLifecyclePhaseSummaryEntity> phases;
  final int totalProcessed;
}
