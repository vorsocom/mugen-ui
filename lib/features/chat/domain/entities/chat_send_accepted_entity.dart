class ChatSendAcceptedEntity {
  const ChatSendAcceptedEntity({
    required this.jobId,
    required this.conversationId,
    required this.acceptedAt,
  });

  final String jobId;
  final String conversationId;
  final DateTime acceptedAt;
}
