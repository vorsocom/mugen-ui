class AuditChainMismatchEntity {
  const AuditChainMismatchEntity({
    required this.id,
    required this.scopeKey,
    required this.scopeSeq,
    required this.reasons,
  });

  final String id;
  final String scopeKey;
  final int? scopeSeq;
  final List<String> reasons;
}

class AuditChainVerificationSummaryEntity {
  const AuditChainVerificationSummaryEntity({
    required this.isValid,
    required this.checkedRows,
    required this.mismatchCount,
    required this.mismatches,
  });

  final bool isValid;
  final int checkedRows;
  final int mismatchCount;
  final List<AuditChainMismatchEntity> mismatches;
}
