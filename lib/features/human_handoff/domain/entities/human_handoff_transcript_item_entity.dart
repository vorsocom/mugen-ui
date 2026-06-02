class HumanHandoffTranscriptItemEntity {
  const HumanHandoffTranscriptItemEntity({
    required this.sequenceNo,
    required this.role,
    required this.content,
    required this.source,
    this.messageId,
    this.traceId,
    this.occurredAt,
  });

  final int sequenceNo;
  final String role;
  final Object? content;
  final String source;
  final String? messageId;
  final String? traceId;
  final DateTime? occurredAt;

  bool get isUser => role.toLowerCase().trim() == 'user';
  bool get isHumanReply =>
      role.toLowerCase().trim() == 'assistant' &&
      source.toLowerCase().trim() == 'human_handoff';
}

class HumanHandoffTranscriptResultEntity {
  const HumanHandoffTranscriptResultEntity({
    required this.items,
    required this.count,
    required this.hasMore,
    this.latestSequenceNo,
  });

  final List<HumanHandoffTranscriptItemEntity> items;
  final int count;
  final int? latestSequenceNo;
  final bool hasMore;

  int? get resolvedLatestSequenceNo {
    if (latestSequenceNo != null) {
      return latestSequenceNo;
    }
    if (items.isEmpty) {
      return null;
    }
    return items
        .map((item) => item.sequenceNo)
        .reduce((value, element) => value > element ? value : element);
  }
}
