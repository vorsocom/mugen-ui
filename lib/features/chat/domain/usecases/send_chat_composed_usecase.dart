import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class SendChatComposedUseCase {
  const SendChatComposedUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatSendAcceptedEntity>> call({
    required String conversationId,
    required String clientMessageId,
    required ChatCompositionMode compositionMode,
    required List<ChatComposedPartEntity> parts,
    required List<ChatComposedAttachmentEntity> attachments,
    Map<String, dynamic>? metadata,
  }) {
    return _repository.sendComposed(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      compositionMode: compositionMode,
      parts: parts,
      attachments: attachments,
      metadata: metadata,
    );
  }
}
