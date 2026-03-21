import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';

enum ChatMessageRole { user, assistant, system, error }

enum ChatMessageType { text, image, audio, video, file }

enum ChatMessageStatus { pending, accepted, delivered, failed }

class ChatMessageEntity {
  const ChatMessageEntity({
    required this.id,
    required this.role,
    required this.type,
    required this.status,
    required this.createdAt,
    this.text,
    this.media,
    this.clientMessageId,
    this.jobId,
    this.eventId,
    this.errorMessage,
  });

  final String id;
  final ChatMessageRole role;
  final ChatMessageType type;
  final ChatMessageStatus status;
  final DateTime createdAt;
  final String? text;
  final ChatMediaEntity? media;
  final String? clientMessageId;
  final String? jobId;
  final String? eventId;
  final String? errorMessage;

  bool get isMedia => type != ChatMessageType.text;

  ChatMessageEntity copyWith({
    String? id,
    ChatMessageRole? role,
    ChatMessageType? type,
    ChatMessageStatus? status,
    DateTime? createdAt,
    String? text,
    ChatMediaEntity? media,
    String? clientMessageId,
    String? jobId,
    String? eventId,
    String? errorMessage,
    bool clearText = false,
    bool clearMedia = false,
    bool clearClientMessageId = false,
    bool clearJobId = false,
    bool clearEventId = false,
    bool clearErrorMessage = false,
  }) {
    return ChatMessageEntity(
      id: id ?? this.id,
      role: role ?? this.role,
      type: type ?? this.type,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      text: clearText ? null : (text ?? this.text),
      media: clearMedia ? null : (media ?? this.media),
      clientMessageId: clearClientMessageId
          ? null
          : (clientMessageId ?? this.clientMessageId),
      jobId: clearJobId ? null : (jobId ?? this.jobId),
      eventId: clearEventId ? null : (eventId ?? this.eventId),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }

  factory ChatMessageEntity.fromJson(Map<String, dynamic> json) {
    return ChatMessageEntity(
      id: json['id']?.toString() ?? '',
      role: _parseRole(json['role']),
      type: _parseType(json['type']),
      status: _parseStatus(json['status']),
      createdAt: _parseDateTime(json['created_at']) ?? DateTime.now().toUtc(),
      text: _parseNullableString(json['text']),
      media: json['media'] is Map
          ? ChatMediaEntity.fromJson(
              Map<String, dynamic>.from(json['media'] as Map),
            )
          : null,
      clientMessageId: _parseNullableString(json['client_message_id']),
      jobId: _parseNullableString(json['job_id']),
      eventId: _parseNullableString(json['event_id']),
      errorMessage: _parseNullableString(json['error_message']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'role': role.name,
      'type': type.name,
      'status': status.name,
      'created_at': createdAt.toUtc().toIso8601String(),
      if (text != null) 'text': text,
      if (media != null) 'media': media!.toJson(),
      if (clientMessageId != null) 'client_message_id': clientMessageId,
      if (jobId != null) 'job_id': jobId,
      if (eventId != null) 'event_id': eventId,
      if (errorMessage != null) 'error_message': errorMessage,
    };
  }
}

ChatMessageRole _parseRole(Object? value) {
  switch (value?.toString().toLowerCase().trim()) {
    case 'user':
      return ChatMessageRole.user;
    case 'assistant':
      return ChatMessageRole.assistant;
    case 'error':
      return ChatMessageRole.error;
    case 'system':
    default:
      return ChatMessageRole.system;
  }
}

ChatMessageType _parseType(Object? value) {
  switch (value?.toString().toLowerCase().trim()) {
    case 'image':
      return ChatMessageType.image;
    case 'audio':
      return ChatMessageType.audio;
    case 'video':
      return ChatMessageType.video;
    case 'file':
      return ChatMessageType.file;
    case 'text':
    default:
      return ChatMessageType.text;
  }
}

ChatMessageStatus _parseStatus(Object? value) {
  switch (value?.toString().toLowerCase().trim()) {
    case 'accepted':
      return ChatMessageStatus.accepted;
    case 'delivered':
      return ChatMessageStatus.delivered;
    case 'failed':
      return ChatMessageStatus.failed;
    case 'pending':
    default:
      return ChatMessageStatus.pending;
  }
}

DateTime? _parseDateTime(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return DateTime.tryParse(normalized)?.toUtc();
}

String? _parseNullableString(Object? value) {
  final normalized = value?.toString().trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  return normalized;
}
