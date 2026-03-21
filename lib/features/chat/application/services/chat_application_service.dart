import 'package:mugen_ui/features/chat/application/dto/chat_send_composed_input.dart';
import 'package:mugen_ui/features/chat/application/dto/chat_send_text_input.dart';
import 'package:mugen_ui/features/chat/application/dto/chat_send_upload_input.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_download_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/usecases/download_chat_media_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_composed_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_text_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_upload_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/stream_chat_events_usecase.dart';
import 'package:mugen_ui/shared/domain/result.dart';

class ChatApplicationService {
  const ChatApplicationService({
    required SendChatTextUseCase sendChatTextUseCase,
    required SendChatUploadUseCase sendChatUploadUseCase,
    required SendChatComposedUseCase sendChatComposedUseCase,
    required StreamChatEventsUseCase streamChatEventsUseCase,
    required DownloadChatMediaUseCase downloadChatMediaUseCase,
  }) : _sendChatTextUseCase = sendChatTextUseCase,
       _sendChatUploadUseCase = sendChatUploadUseCase,
       _sendChatComposedUseCase = sendChatComposedUseCase,
       _streamChatEventsUseCase = streamChatEventsUseCase,
       _downloadChatMediaUseCase = downloadChatMediaUseCase;

  final SendChatTextUseCase _sendChatTextUseCase;
  final SendChatUploadUseCase _sendChatUploadUseCase;
  final SendChatComposedUseCase _sendChatComposedUseCase;
  final StreamChatEventsUseCase _streamChatEventsUseCase;
  final DownloadChatMediaUseCase _downloadChatMediaUseCase;

  Future<Result<ChatSendAcceptedEntity>> sendText(ChatSendTextInput input) {
    return _sendChatTextUseCase(
      conversationId: input.conversationId,
      clientMessageId: input.clientMessageId,
      text: input.text,
      metadata: input.metadata,
    );
  }

  Future<Result<ChatSendAcceptedEntity>> sendUpload(ChatSendUploadInput input) {
    return _sendChatUploadUseCase(
      conversationId: input.conversationId,
      clientMessageId: input.clientMessageId,
      filename: input.filename,
      mimeType: input.mimeType,
      bytes: input.bytes,
      text: input.text,
      metadata: input.metadata,
    );
  }

  Future<Result<ChatSendAcceptedEntity>> sendComposed(
    ChatSendComposedInput input,
  ) {
    return _sendChatComposedUseCase(
      conversationId: input.conversationId,
      clientMessageId: input.clientMessageId,
      compositionMode: input.compositionMode,
      parts: input.parts.map((part) => part.toEntity()).toList(growable: false),
      attachments: input.attachments
          .map((attachment) => attachment.toEntity())
          .toList(growable: false),
      metadata: input.metadata,
    );
  }

  Stream<Result<ChatSseEventEntity>> streamEvents({
    required String conversationId,
    String? lastEventId,
  }) {
    return _streamChatEventsUseCase(
      conversationId: conversationId,
      lastEventId: lastEventId,
    );
  }

  Future<Result<ChatMediaDownloadEntity>> downloadMedia({
    required String mediaUrl,
    String? suggestedFilename,
    String? suggestedMimeType,
  }) {
    return _downloadChatMediaUseCase(
      mediaUrl: mediaUrl,
      suggestedFilename: suggestedFilename,
      suggestedMimeType: suggestedMimeType,
    );
  }
}
