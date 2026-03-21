class ChatSseEventEntity {
  const ChatSseEventEntity({
    required this.id,
    required this.event,
    required this.data,
  });

  final String? id;
  final String event;
  final Map<String, dynamic> data;
}
