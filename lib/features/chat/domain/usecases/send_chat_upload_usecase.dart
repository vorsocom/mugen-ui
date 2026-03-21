import 'dart:typed_data';

import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class SendChatUploadUseCase {
  const SendChatUploadUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatSendAcceptedEntity>> call({
    required String conversationId,
    required String clientMessageId,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    String? text,
    Map<String, dynamic>? metadata,
  }) {
    return _repository.sendUpload(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      filename: filename,
      mimeType: mimeType,
      bytes: bytes,
      text: text,
      metadata: metadata,
    );
  }
}
