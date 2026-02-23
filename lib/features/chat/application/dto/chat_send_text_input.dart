class ChatSendTextInput {
  const ChatSendTextInput({
    required this.conversationId,
    required this.clientMessageId,
    required this.text,
    this.metadata,
  });

  final String conversationId;
  final String clientMessageId;
  final String text;
  final Map<String, dynamic>? metadata;
}
