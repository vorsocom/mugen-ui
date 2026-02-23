import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class StreamChatEventsUseCase {
  const StreamChatEventsUseCase(this._repository);

  final ChatRepository _repository;

  Stream<Result<ChatSseEventEntity>> call({
    required String conversationId,
    String? lastEventId,
  }) {
    return _repository.streamEvents(
      conversationId: conversationId,
      lastEventId: lastEventId,
    );
  }
}
