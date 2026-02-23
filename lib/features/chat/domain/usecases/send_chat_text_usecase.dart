import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class SendChatTextUseCase {
  const SendChatTextUseCase(this._repository);

  final ChatRepository _repository;

  Future<Result<ChatSendAcceptedEntity>> call({
    required String conversationId,
    required String clientMessageId,
    required String text,
    Map<String, dynamic>? metadata,
  }) {
    return _repository.sendText(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      text: text,
      metadata: metadata,
    );
  }
}
