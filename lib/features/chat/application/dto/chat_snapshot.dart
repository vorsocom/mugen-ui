import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';

class ChatSnapshot {
  const ChatSnapshot({
    required this.conversationId,
    required this.messages,
    this.lastEventId,
  });

  final String conversationId;
  final String? lastEventId;
  final List<ChatMessageEntity> messages;

  factory ChatSnapshot.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    final messages = <ChatMessageEntity>[];
    if (rawMessages is List) {
      for (final item in rawMessages) {
        if (item is Map) {
          messages.add(
            ChatMessageEntity.fromJson(Map<String, dynamic>.from(item)),
          );
        }
      }
    }

    return ChatSnapshot(
      conversationId: json['conversation_id']?.toString() ?? '',
      lastEventId: _readNullableString(json['last_event_id']),
      messages: messages,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'conversation_id': conversationId,
      if (lastEventId != null) 'last_event_id': lastEventId,
      'messages': messages
          .map((message) => message.toJson())
          .toList(growable: false),
    };
  }
}

String? _readNullableString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}
