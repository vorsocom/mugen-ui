import 'dart:typed_data';

import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';

class ChatSendComposedInput {
  const ChatSendComposedInput({
    required this.conversationId,
    required this.clientMessageId,
    required this.compositionMode,
    required this.parts,
    required this.attachments,
    this.metadata,
  });

  final String conversationId;
  final String clientMessageId;
  final ChatCompositionMode compositionMode;
  final List<ChatSendComposedPartInput> parts;
  final List<ChatSendComposedAttachmentInput> attachments;
  final Map<String, dynamic>? metadata;
}

class ChatSendComposedPartInput {
  const ChatSendComposedPartInput._({
    required this.type,
    this.text,
    this.attachmentId,
    this.caption,
    this.metadata = const <String, dynamic>{},
  });

  const ChatSendComposedPartInput.text({required String text})
    : this._(type: ChatComposedPartType.text, text: text);

  const ChatSendComposedPartInput.attachment({
    required String attachmentId,
    String? caption,
    Map<String, dynamic> metadata = const <String, dynamic>{},
  }) : this._(
         type: ChatComposedPartType.attachment,
         attachmentId: attachmentId,
         caption: caption,
         metadata: metadata,
       );

  final ChatComposedPartType type;
  final String? text;
  final String? attachmentId;
  final String? caption;
  final Map<String, dynamic> metadata;

  ChatComposedPartEntity toEntity() {
    switch (type) {
      case ChatComposedPartType.text:
        return ChatComposedPartEntity.text(text: text ?? '');
      case ChatComposedPartType.attachment:
        return ChatComposedPartEntity.attachment(
          attachmentId: attachmentId ?? '',
          caption: caption,
          metadata: metadata,
        );
    }
  }
}

class ChatSendComposedAttachmentInput {
  const ChatSendComposedAttachmentInput({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.caption,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String filename;
  final String mimeType;
  final Uint8List bytes;
  final String? caption;
  final Map<String, dynamic> metadata;

  ChatComposedAttachmentEntity toEntity() {
    return ChatComposedAttachmentEntity(
      id: id,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
      caption: caption,
      metadata: metadata,
    );
  }
}
