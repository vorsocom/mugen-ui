import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_download_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_upload_usecase.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';

void main() {
  test('SendChatUploadUseCase delegates all upload parameters', () async {
    final repository = _FakeChatRepository();
    final useCase = SendChatUploadUseCase(repository);

    final response = await useCase(
      conversationId: 'conv-1',
      clientMessageId: 'client-1',
      filename: 'report.pdf',
      mimeType: 'application/pdf',
      bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
      text: 'attachment',
      metadata: <String, dynamic>{'origin': 'test'},
    );

    expect(response.isSuccess, isTrue);
    expect(repository.lastConversationId, 'conv-1');
    expect(repository.lastClientMessageId, 'client-1');
    expect(repository.lastFilename, 'report.pdf');
    expect(repository.lastMimeType, 'application/pdf');
    expect(repository.lastBytes, <int>[1, 2, 3, 4]);
    expect(repository.lastText, 'attachment');
    expect(repository.lastMetadata, <String, dynamic>{'origin': 'test'});
  });
}

class _FakeChatRepository implements ChatRepository {
  String? lastConversationId;
  String? lastClientMessageId;
  String? lastFilename;
  String? lastMimeType;
  List<int>? lastBytes;
  String? lastText;
  Map<String, dynamic>? lastMetadata;

  @override
  Future<Result<ChatMediaDownloadEntity>> downloadMedia({
    required String mediaUrl,
    String? suggestedFilename,
    String? suggestedMimeType,
  }) async {
    return const Result<ChatMediaDownloadEntity>.failure(
      UnexpectedFailure('not needed in this test'),
    );
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendComposed({
    required String conversationId,
    required String clientMessageId,
    required ChatCompositionMode compositionMode,
    required List<ChatComposedPartEntity> parts,
    required List<ChatComposedAttachmentEntity> attachments,
    Map<String, dynamic>? metadata,
  }) async {
    return const Result<ChatSendAcceptedEntity>.failure(
      UnexpectedFailure('not needed in this test'),
    );
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendText({
    required String conversationId,
    required String clientMessageId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    return const Result<ChatSendAcceptedEntity>.failure(
      UnexpectedFailure('not needed in this test'),
    );
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendUpload({
    required String conversationId,
    required String clientMessageId,
    required String filename,
    required String mimeType,
    required Uint8List bytes,
    String? text,
    Map<String, dynamic>? metadata,
  }) async {
    lastConversationId = conversationId;
    lastClientMessageId = clientMessageId;
    lastFilename = filename;
    lastMimeType = mimeType;
    lastBytes = bytes.toList(growable: false);
    lastText = text;
    lastMetadata = metadata;
    return Result<ChatSendAcceptedEntity>.success(
      ChatSendAcceptedEntity(
        jobId: 'job-1',
        conversationId: conversationId,
        acceptedAt: DateTime.utc(2026, 1, 1),
      ),
    );
  }

  @override
  Stream<Result<ChatSseEventEntity>> streamEvents({
    required String conversationId,
    String? lastEventId,
  }) {
    return const Stream<Result<ChatSseEventEntity>>.empty();
  }
}
