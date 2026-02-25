class AuditSealBacklogSummaryEntity {
  const AuditSealBacklogSummaryEntity({
    required this.rowsSealed,
    required this.remainingCount,
    required this.batches,
    required this.batchSize,
    required this.maxBatches,
  });

  final int rowsSealed;
  final int remainingCount;
  final int batches;
  final int batchSize;
  final int maxBatches;
}
