class HumanHandoffSessionEntity {
  const HumanHandoffSessionEntity({
    required this.id,
    required this.tenantId,
    required this.scopeKey,
    required this.platform,
    required this.status,
    this.channelId,
    this.roomId,
    this.senderId,
    this.conversationId,
    this.clientProfileId,
    this.serviceRouteKey,
    this.ownerUserId,
    this.reason,
    this.activatedAt,
    this.deactivatedAt,
    this.lastHumanReplyAt,
    this.lastUserMessageAt,
    this.lastTranscriptSequenceNo,
    this.lastDeliveryStatus,
    this.lastDeliveryError,
  });

  final String id;
  final String tenantId;
  final String scopeKey;
  final String platform;
  final String status;
  final String? channelId;
  final String? roomId;
  final String? senderId;
  final String? conversationId;
  final String? clientProfileId;
  final String? serviceRouteKey;
  final String? ownerUserId;
  final String? reason;
  final DateTime? activatedAt;
  final DateTime? deactivatedAt;
  final DateTime? lastHumanReplyAt;
  final DateTime? lastUserMessageAt;
  final int? lastTranscriptSequenceNo;
  final String? lastDeliveryStatus;
  final String? lastDeliveryError;

  bool get isActive => status.toLowerCase().trim() == 'active';
  bool get hasNewUserActivity {
    final userMessageAt = lastUserMessageAt;
    if (!isActive || userMessageAt == null) {
      return false;
    }
    final humanReplyAt = lastHumanReplyAt;
    return humanReplyAt == null || userMessageAt.isAfter(humanReplyAt);
  }

  bool get hasDeliveryFailure =>
      lastDeliveryStatus?.toLowerCase().trim() == 'failed' ||
      (lastDeliveryError?.trim().isNotEmpty ?? false);
}
