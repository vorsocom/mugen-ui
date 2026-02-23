import 'dart:typed_data';

class ChatSendUploadInput {
  const ChatSendUploadInput({
    required this.conversationId,
    required this.clientMessageId,
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.text,
    this.metadata,
  });

  final String conversationId;
  final String clientMessageId;
  final String filename;
  final String mimeType;
  final Uint8List bytes;
  final String? text;
  final Map<String, dynamic>? metadata;
}
