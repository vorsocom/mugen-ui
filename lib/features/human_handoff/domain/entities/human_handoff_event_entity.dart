class HumanHandoffEventEntity {
  const HumanHandoffEventEntity({
    required this.eventType,
    required this.tenantId,
    required this.sessionId,
    this.eventId,
    this.occurredAt,
    this.sequenceNo,
    this.deliveryStatus,
    this.deliveryError,
  });

  final String? eventId;
  final String eventType;
  final String tenantId;
  final String sessionId;
  final DateTime? occurredAt;
  final int? sequenceNo;
  final String? deliveryStatus;
  final String? deliveryError;

  bool get appendsTranscript =>
      eventType.toLowerCase().trim() == 'handoff.transcript_appended';
  bool get updatesSession =>
      eventType.toLowerCase().trim().startsWith('handoff.');
}
