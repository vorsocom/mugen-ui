import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mugen_ui/features/auth/application/dto/update_own_profile_input.dart';
import 'package:mugen_ui/features/auth/domain/entities/own_profile_entity.dart';
import 'package:mugen_ui/features/auth/domain/repositories/auth_repository.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_attachment_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composed_part_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_download_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_send_accepted_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage.dart';
import 'package:mugen_ui/features/chat/presentation/platform/media_object_url.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';

void main() {
  test(
    'controller restores snapshot and starts stream with saved lastEventId',
    () async {
      final storage = _InMemoryChatLocalStorage();
      storage.setItem(
        'mugen_ui.chat.single.user-1.v1',
        jsonEncode(<String, dynamic>{
          'conversation_id': 'conv-restored',
          'last_event_id': '9',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'm1',
              'role': 'assistant',
              'type': 'text',
              'status': 'delivered',
              'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
              'text': 'restored',
            },
          ],
        }),
      );

      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: storage,
      );
      addTearDown(container.dispose);

      final state = container.read(chatControllerProvider);
      expect(state.conversationId, 'conv-restored');
      expect(state.lastEventId, '9');
      expect(state.messages.length, 1);
      expect(state.messages.first.text, 'restored');

      await Future<void>.delayed(Duration.zero);
      expect(repository.streamCalls, isNotEmpty);
      expect(repository.streamCalls.first.lastEventId, '9');
    },
  );

  test(
    'controller resets chat state when the authenticated user changes',
    () async {
      final storage = _InMemoryChatLocalStorage();
      storage.setItem(
        'mugen_ui.chat.single.user-2.v1',
        jsonEncode(<String, dynamic>{
          'conversation_id': 'conv-user-2',
          'last_event_id': '42',
          'messages': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'u2-message',
              'role': 'assistant',
              'type': 'text',
              'status': 'delivered',
              'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
              'text': 'restored for user 2',
            },
          ],
        }),
      );
      final authRepository = _FakeAuthRepository(
        const AuthSession(
          accessToken: 'token-1',
          refreshToken: 'refresh-1',
          userId: 'user-1',
          roles: <String>[],
        ),
      );
      authRepository.nextLoginSession = const AuthSession(
        accessToken: 'token-2',
        refreshToken: 'refresh-2',
        userId: 'user-2',
        roles: <String>[],
      );
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: storage,
        authRepository: authRepository,
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.failure(UnauthorizedFailure()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatControllerProvider).errorMessage,
        'Unauthorized request.',
      );

      final loggedIn = await container
          .read(authControllerProvider.notifier)
          .login(username: 'next', password: 'password');
      await Future<void>.delayed(Duration.zero);

      expect(loggedIn, isTrue);
      final state = container.read(chatControllerProvider);
      expect(state.conversationId, 'conv-user-2');
      expect(state.lastEventId, '42');
      expect(state.messages.single.text, 'restored for user 2');
      expect(state.errorMessage, isNull);
      expect(repository.streamCalls.last.conversationId, 'conv-user-2');
      expect(repository.streamCalls.last.lastEventId, '42');
    },
  );

  test(
    'late send failures do not write into a newer authenticated user',
    () async {
      final authRepository = _FakeAuthRepository(
        const AuthSession(
          accessToken: 'token-1',
          refreshToken: 'refresh-1',
          userId: 'user-1',
          roles: <String>[],
        ),
      );
      authRepository.nextLoginSession = const AuthSession(
        accessToken: 'token-2',
        refreshToken: 'refresh-2',
        userId: 'user-2',
        roles: <String>[],
      );
      final repository = _FakeChatRepository();
      repository.pendingSendTextCompleter =
          Completer<Result<ChatSendAcceptedEntity>>();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        authRepository: authRepository,
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final send = notifier.sendMessage('hello');
      await Future<void>.delayed(Duration.zero);
      expect(container.read(chatControllerProvider).isSending, isTrue);

      final loggedIn = await container
          .read(authControllerProvider.notifier)
          .login(username: 'next', password: 'password');
      await Future<void>.delayed(Duration.zero);
      repository.pendingSendTextCompleter!.complete(
        const Result<ChatSendAcceptedEntity>.failure(
          NetworkFailure('late failure'),
        ),
      );
      final sent = await send;

      expect(loggedIn, isTrue);
      expect(sent, isFalse);
      final state = container.read(chatControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.errorMessage, isNull);
      expect(state.isSending, isFalse);
    },
  );

  test('controller trims restored snapshot to retained message cap', () async {
    final storage = _InMemoryChatLocalStorage();
    storage.setItem(
      'mugen_ui.chat.single.user-1.v1',
      jsonEncode(<String, dynamic>{
        'conversation_id': 'conv-retained',
        'last_event_id': '99',
        'messages': List<Map<String, dynamic>>.generate(650, (index) {
          return <String, dynamic>{
            'id': 'm$index',
            'role': 'assistant',
            'type': 'text',
            'status': 'delivered',
            'created_at': DateTime.utc(2026, 1, 1).toIso8601String(),
            'text': 'message $index',
          };
        }),
      }),
    );

    final repository = _FakeChatRepository();
    final container = _buildContainer(repository: repository, storage: storage);
    addTearDown(container.dispose);

    final state = container.read(chatControllerProvider);
    expect(state.messages.length, kMaxRetainedMessages);
    expect(state.messages.first.id, 'm50');
    expect(state.messages.last.id, 'm649');
  });

  test(
    'snapshot persistence trims oversized payload and avoids uncaught storage errors',
    () async {
      final storage = _SizeLimitedChatLocalStorage(maxBytes: 1200);
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: storage,
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final sent = await notifier.sendMessage('x' * 5000);
      expect(sent, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 500));
      final persisted = storage.getItem('mugen_ui.chat.single.user-1.v1');
      expect(persisted, isNotNull);
      expect(persisted!.length <= 1200, isTrue);
      expect(storage.writeAttempts, greaterThan(0));
    },
  );

  test(
    'sending image attachment creates local transcript preview resource',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'medicine.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      await notifier.attachFromPicker();
      final sent = await notifier.sendMessage('test image');
      expect(sent, isTrue);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 2);
      expect(state.messages.first.type.name, 'text');
      final userMediaMessage = state.messages.last;
      expect(userMediaMessage.type.name, 'image');
      expect(userMediaMessage.media?.url, startsWith('data:image/png;base64,'));
      final mediaResource = state.mediaResources[userMediaMessage.id];
      expect(mediaResource, isNotNull);
      expect(mediaResource!.objectUrl, isNotEmpty);
      expect(mediaResource.mimeType, 'image/png');
      expect(mediaResource.filename, 'medicine.png');
    },
  );

  test(
    'sending xlsx attachment creates local spreadsheet preview resource',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'report.xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            bytes: _buildSampleXlsxBytes(),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      await notifier.attachFromPicker();
      final sent = await notifier.sendMessage('sheet preview');
      expect(sent, isTrue);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 2);
      expect(state.messages.last.type, ChatMessageType.file);
      final mediaResource = state.mediaResources[state.messages.last.id];
      expect(mediaResource, isNotNull);
      expect(mediaResource!.filename, 'report.xlsx');
      expect(mediaResource.spreadsheetPreview, isNotNull);
      expect(mediaResource.spreadsheetPreview!.sheetName, 'Sheet1');
      expect(mediaResource.spreadsheetPreview!.rows, isNotEmpty);
      expect(mediaResource.spreadsheetPreview!.rows.first.first, 'Name');
      expect(mediaResource.spreadsheetPreview!.rows[1][1], '42');
    },
  );

  test('attachFromPicker appends multiple files in selection order', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
      filePicker: _FixedChatFilePicker(<ChatPickedFile>[
        ChatPickedFile(
          filename: 'a.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(<int>[1]),
        ),
        ChatPickedFile(
          filename: 'b.png',
          mimeType: 'image/png',
          bytes: Uint8List.fromList(<int>[2, 3]),
        ),
      ]),
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);
    expect(
      container.read(chatControllerProvider).compositionMode,
      ChatCompositionMode.messageWithAttachments,
    );

    await notifier.attachFromPicker();
    final state = container.read(chatControllerProvider);
    expect(state.attachments.length, 2);
    expect(state.attachments[0].filename, 'a.txt');
    expect(state.attachments[1].filename, 'b.png');
  });

  test(
    'attachment_with_caption mode blocks send until every attachment has a caption',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'doc.txt',
            mimeType: 'text/plain',
            bytes: Uint8List.fromList(<int>[1, 2]),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.attachFromPicker();
      notifier.setCompositionMode(ChatCompositionMode.attachmentWithCaption);

      final sentWithoutCaption = await notifier.sendMessage('');
      expect(sentWithoutCaption, isFalse);
      expect(repository.sendComposedCallCount, 0);
      expect(
        container.read(chatControllerProvider).errorMessage,
        'Add a caption for each attachment in this mode.',
      );

      final attachmentId = container
          .read(chatControllerProvider)
          .attachments
          .single
          .id;
      notifier.updateAttachmentCaption(
        attachmentId: attachmentId,
        caption: 'caption now set',
      );
      final sentWithCaption = await notifier.sendMessage('');
      expect(sentWithCaption, isTrue);
      expect(repository.sendComposedCallCount, 1);
    },
  );

  test(
    'message_with_attachments sends structured parts and creates optimistic rows',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'one.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
          ChatPickedFile(
            filename: 'two.txt',
            mimeType: 'text/plain',
            bytes: Uint8List.fromList(<int>[4, 5]),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.attachFromPicker();
      final sent = await notifier.sendMessage('hello structured');
      expect(sent, isTrue);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 3);
      expect(state.messages[0].type, ChatMessageType.text);
      expect(state.messages[1].type, ChatMessageType.image);
      expect(state.messages[2].type, ChatMessageType.file);
      final sharedClientMessageId = state.messages.first.clientMessageId;
      expect(
        state.messages.every(
          (message) => message.clientMessageId == sharedClientMessageId,
        ),
        isTrue,
      );
      expect(
        state.messages.every(
          (message) => message.status == ChatMessageStatus.accepted,
        ),
        isTrue,
      );

      expect(repository.sendComposedCallCount, 1);
      final call = repository.lastComposedCall;
      expect(call, isNotNull);
      expect(call!.compositionMode, ChatCompositionMode.messageWithAttachments);
      expect(call.parts.length, 3);
      expect(call.parts[0].type, ChatComposedPartType.text);
      expect(call.parts[0].text, 'hello structured');
      expect(call.parts[1].type, ChatComposedPartType.attachment);
      expect(call.parts[2].type, ChatComposedPartType.attachment);
      expect(call.attachments.length, 2);
      expect(call.attachments[0].filename, 'one.png');
      expect(call.attachments[1].filename, 'two.txt');
    },
  );

  test(
    'ack and message events update all optimistic rows sharing the same client id',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'one.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3]),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.attachFromPicker();
      final sent = await notifier.sendMessage('correlate');
      expect(sent, isTrue);

      var state = container.read(chatControllerProvider);
      expect(state.messages.length, 2);
      final clientMessageId = state.messages.first.clientMessageId;
      expect(clientMessageId, isNotNull);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'corr-1',
            event: 'ack',
            data: <String, dynamic>{
              'client_message_id': clientMessageId,
              'job_id': 'job-corr',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      expect(
        state.messages.every(
          (message) => message.status == ChatMessageStatus.accepted,
        ),
        isTrue,
      );

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'corr-2',
            event: 'message',
            data: <String, dynamic>{
              'job_id': 'job-corr',
              'client_message_id': clientMessageId,
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'assistant finished',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      final userRows = state.messages
          .where((message) => message.role == ChatMessageRole.user)
          .toList(growable: false);
      expect(
        userRows.every(
          (message) => message.status == ChatMessageStatus.delivered,
        ),
        isTrue,
      );
      expect(state.messages.last.text, 'assistant finished');
    },
  );

  test(
    'ack event updates optimistic message and duplicate event ids are ignored',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamControllers, isNotEmpty);

      final sent = await notifier.sendMessage('hello');
      expect(sent, isTrue);
      var state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      final clientMessageId = state.messages.first.clientMessageId;
      expect(clientMessageId, isNotNull);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: '1',
            event: 'ack',
            data: <String, dynamic>{
              'client_message_id': clientMessageId,
              'job_id': 'ack-job',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      expect(state.messages.first.jobId, 'ack-job');
      expect(state.messages.first.status.name, 'accepted');
      expect(state.lastEventId, '1');

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: '1',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'duplicate',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
    },
  );

  test(
    'controller handles stream reset signal and accepts versioned cursor ids',
    () async {
      final storage = _InMemoryChatLocalStorage();
      storage.setItem(
        'mugen_ui.chat.single.user-1.v1',
        jsonEncode(<String, dynamic>{
          'conversation_id': 'conv-reset',
          'last_event_id': '120',
          'messages': <Map<String, dynamic>>[],
        }),
      );

      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: storage,
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamCalls.first.lastEventId, '120');

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          const ChatSseEventEntity(
            id: 'v3:gen-new:0',
            event: 'system',
            data: <String, dynamic>{
              'signal': 'stream_reset',
              'message': 'Event stream cursor reset.',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      var state = container.read(chatControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.hasReplayNotice, isTrue);
      expect(state.replayNoticeText, 'Replay resynced');
      expect(state.replayNoticeReason, 'event replay resynced');
      expect(state.replayNoticeEventId, 'v3:gen-new:0');

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          const ChatSseEventEntity(
            id: 'v3:gen-new:1',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'fresh after restart',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.text, 'fresh after restart');
      expect(state.lastEventId, 'v3:gen-new:1');
    },
  );

  testWidgets('replay notice auto-clears after ten seconds', (tester) async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await tester.pump();

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: 'v3:gen-notice:1',
          event: 'system',
          data: <String, dynamic>{
            'signal': 'stream_reset',
            'reason': 'stale_cursor',
          },
        ),
      ),
    );
    await tester.pump();

    var state = container.read(chatControllerProvider);
    expect(state.hasReplayNotice, isTrue);
    expect(state.replayNoticeReason, 'stale_cursor');

    await tester.pump(const Duration(seconds: 11));
    state = container.read(chatControllerProvider);
    expect(state.hasReplayNotice, isFalse);
    expect(state.replayNoticeText, isNull);
    expect(state.replayNoticeReason, isNull);
  });

  test(
    'duplicate versioned event ids are ignored within same generation',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      final event = const ChatSseEventEntity(
        id: 'v3:gen-a:2',
        event: 'message',
        data: <String, dynamic>{
          'message': <String, dynamic>{'type': 'text', 'content': 'hello once'},
        },
      );

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(event),
      );
      await Future<void>.delayed(Duration.zero);
      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(event),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.text, 'hello once');
    },
  );

  test(
    'event ids from a new generation are not treated as duplicates',
    () async {
      final storage = _InMemoryChatLocalStorage();
      storage.setItem(
        'mugen_ui.chat.single.user-1.v1',
        jsonEncode(<String, dynamic>{
          'conversation_id': 'conv-gen-switch',
          'last_event_id': 'v3:gen-old:99',
          'messages': <Map<String, dynamic>>[],
        }),
      );

      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: storage,
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          const ChatSseEventEntity(
            id: 'v3:gen-new:1',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'new generation message',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.first.text, 'new generation message');
      expect(state.lastEventId, 'v3:gen-new:1');
    },
  );

  test('thinking start and stop toggle assistant thinking indicator', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '21',
          event: 'thinking',
          data: <String, dynamic>{'state': 'start', 'job_id': 'job-21'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    var state = container.read(chatControllerProvider);
    expect(state.isAssistantThinking, isTrue);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '22',
          event: 'thinking',
          data: <String, dynamic>{'state': 'stop', 'job_id': 'job-21'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    state = container.read(chatControllerProvider);
    expect(state.isAssistantThinking, isFalse);
  });

  test(
    'thinking stop marks outgoing message delivered for command-like flows',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final sent = await notifier.sendMessage('...');
      expect(sent, isTrue);
      final clientMessageId = container
          .read(chatControllerProvider)
          .messages
          .first
          .clientMessageId;
      expect(clientMessageId, isNotNull);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-cmd:1',
            event: 'ack',
            data: <String, dynamic>{
              'client_message_id': clientMessageId,
              'job_id': 'job-cmd-1',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatControllerProvider).messages.first.status.name,
        'accepted',
      );

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-cmd:2',
            event: 'thinking',
            data: <String, dynamic>{
              'state': 'start',
              'job_id': 'job-cmd-1',
              'client_message_id': 'ignored-by-job-match',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatControllerProvider).isAssistantThinking,
        isTrue,
      );

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-cmd:3',
            event: 'thinking',
            data: <String, dynamic>{
              'state': 'stop',
              'job_id': 'job-cmd-1',
              'client_message_id': 'ignored-by-job-match',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.isAssistantThinking, isFalse);
      expect(state.messages.first.status.name, 'delivered');
      expect(state.messages.length, 1);
    },
  );

  test('thinking start is cleared by matching message event job id', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '31',
          event: 'thinking',
          data: <String, dynamic>{'state': 'start', 'job_id': 'job-31'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(chatControllerProvider).isAssistantThinking, isTrue);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '32',
          event: 'message',
          data: <String, dynamic>{
            'job_id': 'job-31',
            'message': <String, dynamic>{'type': 'text', 'content': 'done'},
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.isAssistantThinking, isFalse);
    expect(state.messages.last.text, 'done');
  });

  test(
    'thinking start is cleared by matching system event client id',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          const ChatSseEventEntity(
            id: '41',
            event: 'thinking',
            data: <String, dynamic>{
              'state': 'start',
              'client_message_id': 'client-41',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatControllerProvider).isAssistantThinking,
        isTrue,
      );

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          const ChatSseEventEntity(
            id: '42',
            event: 'system',
            data: <String, dynamic>{
              'client_message_id': 'client-41',
              'message': 'processing complete',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.isAssistantThinking, isFalse);
      expect(state.messages.last.text, 'processing complete');
    },
  );

  test('thinking start is cleared by matching error event job id', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '51',
          event: 'thinking',
          data: <String, dynamic>{'state': 'start', 'job_id': 'job-51'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(chatControllerProvider).isAssistantThinking, isTrue);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '52',
          event: 'error',
          data: <String, dynamic>{'job_id': 'job-51', 'error': 'failed'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.isAssistantThinking, isFalse);
    expect(state.messages.last.errorMessage, 'failed');
  });

  test('message event marks outgoing message delivered by job id', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final sent = await notifier.sendMessage('hello');
    expect(sent, isTrue);
    final clientMessageId = container
        .read(chatControllerProvider)
        .messages
        .first
        .clientMessageId;
    expect(clientMessageId, isNotNull);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '11',
          event: 'ack',
          data: <String, dynamic>{
            'client_message_id': clientMessageId,
            'job_id': 'job-11',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '12',
          event: 'message',
          data: <String, dynamic>{
            'job_id': 'job-11',
            'message': <String, dynamic>{
              'type': 'text',
              'content': 'assistant reply',
            },
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.first.status.name, 'delivered');
    expect(state.messages.last.text, 'assistant reply');
    expect(state.lastEventId, '12');
  });

  test(
    'duplicate assistant event with different event ids is appended once',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      const payload = <String, dynamic>{
        'job_id': 'job-dup',
        'client_message_id': 'client-dup',
        'message': <String, dynamic>{
          'type': 'text',
          'content': 'assistant replayed reply',
        },
      };
      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(id: '301', event: 'message', data: payload),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(id: '302', event: 'message', data: payload),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.single.text, 'assistant replayed reply');
    },
  );

  test(
    'human handoff message with null job id renders as assistant without acking pending user',
    () async {
      final repository = _FakeChatRepository();
      repository.pendingSendTextCompleter =
          Completer<Result<ChatSendAcceptedEntity>>();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      final sendFuture = notifier.sendMessage('Need a human');
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'hh-1',
            event: 'message',
            data: <String, dynamic>{
              'job_id': null,
              'conversation_id': 'conv-test',
              'client_message_id': 'human-msg-1',
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'Human operator response',
              },
              'human_handoff': <String, dynamic>{
                'metadata': <String, dynamic>{},
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.messages, hasLength(2));
      expect(state.messages.first.role, ChatMessageRole.user);
      expect(state.messages.first.status, ChatMessageStatus.pending);
      expect(state.messages.last.role, ChatMessageRole.assistant);
      expect(state.messages.last.text, 'Human operator response');
      expect(state.messages.last.jobId, isNull);
      expect(state.messages.last.clientMessageId, 'human-msg-1');

      repository.pendingSendTextCompleter!.complete(
        Result<ChatSendAcceptedEntity>.success(
          ChatSendAcceptedEntity(
            jobId: 'job-send',
            conversationId: 'conv',
            acceptedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );
      await sendFuture;
    },
  );

  test(
    'human handoff duplicate client message id is appended once across event ids',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'hh-101',
            event: 'message',
            data: <String, dynamic>{
              'job_id': null,
              'client_message_id': 'human-msg-dup',
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'first delivery',
              },
              'human_handoff': <String, dynamic>{
                'metadata': <String, dynamic>{},
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'hh-102',
            event: 'message',
            data: <String, dynamic>{
              'job_id': null,
              'client_message_id': 'human-msg-dup',
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'duplicate delivery',
              },
              'human_handoff': <String, dynamic>{
                'metadata': <String, dynamic>{},
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final messages = container.read(chatControllerProvider).messages;
      expect(messages, hasLength(1));
      expect(messages.single.text, 'first delivery');
    },
  );

  test('assistant messages with distinct content are both appended', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '311',
          event: 'message',
          data: <String, dynamic>{
            'job_id': 'job-same',
            'client_message_id': 'client-same',
            'message': <String, dynamic>{
              'type': 'text',
              'content': 'first response',
            },
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '312',
          event: 'message',
          data: <String, dynamic>{
            'job_id': 'job-same',
            'client_message_id': 'client-same',
            'message': <String, dynamic>{
              'type': 'text',
              'content': 'second response',
            },
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.length, 2);
    expect(state.messages.first.text, 'first response');
    expect(state.messages.last.text, 'second response');
  });

  test('duplicate system rows are appended once', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    const data = <String, dynamic>{
      'job_id': 'job-system',
      'client_message_id': 'client-system',
      'message': 'processing complete',
    };
    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(id: '321', event: 'system', data: data),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(id: '322', event: 'system', data: data),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.length, 1);
    expect(state.messages.single.role.name, 'system');
    expect(state.messages.single.text, 'processing complete');
  });

  test('duplicate error rows are appended once', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    const data = <String, dynamic>{
      'job_id': 'job-error',
      'client_message_id': 'client-error',
      'error': 'failure detail',
    };
    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(id: '331', event: 'error', data: data),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(id: '332', event: 'error', data: data),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.length, 1);
    expect(state.messages.single.role.name, 'error');
    expect(state.messages.single.errorMessage, 'failure detail');
  });

  test(
    'message event falls back to single open outgoing when correlation mismatches',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final sent = await notifier.sendMessage('...');
      expect(sent, isTrue);
      final clientMessageId = container
          .read(chatControllerProvider)
          .messages
          .first
          .clientMessageId;
      expect(clientMessageId, isNotNull);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-fallback:1',
            event: 'ack',
            data: <String, dynamic>{
              'client_message_id': clientMessageId,
              'job_id': 'job-fallback-1',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(chatControllerProvider).messages.first.status.name,
        'accepted',
      );

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-fallback:2',
            event: 'message',
            data: <String, dynamic>{
              'job_id': 'job-other',
              'client_message_id': 'client-other',
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'Context cleared.',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.messages.first.status.name, 'delivered');
      expect(state.messages.last.text, 'Context cleared.');
    },
  );

  test(
    'send completion does not downgrade delivered when sse message arrives first',
    () async {
      final repository = _FakeChatRepository();
      repository.pendingSendTextCompleter =
          Completer<Result<ChatSendAcceptedEntity>>();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamControllers, isNotEmpty);

      final notifier = container.read(chatControllerProvider.notifier);
      final sendFuture = notifier.sendMessage('...');
      await Future<void>.delayed(Duration.zero);

      final stateBefore = container.read(chatControllerProvider);
      expect(stateBefore.messages.length, 1);
      final clientMessageId = stateBefore.messages.first.clientMessageId;
      expect(clientMessageId, isNotNull);

      repository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'v3:gen-race:1',
            event: 'message',
            data: <String, dynamic>{
              'job_id': 'job-race',
              'client_message_id': clientMessageId,
              'message': <String, dynamic>{
                'type': 'text',
                'content': 'Context cleared.',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(chatControllerProvider).messages.first.status.name,
        'delivered',
      );

      repository.pendingSendTextCompleter!.complete(
        Result<ChatSendAcceptedEntity>.success(
          ChatSendAcceptedEntity(
            jobId: 'job-race',
            conversationId: 'conv',
            acceptedAt: DateTime.utc(2026, 1, 1),
          ),
        ),
      );

      final sent = await sendFuture;
      expect(sent, isTrue);
      await Future<void>.delayed(Duration.zero);

      final finalState = container.read(chatControllerProvider);
      expect(finalState.messages.first.status.name, 'delivered');
      expect(finalState.messages.last.text, 'Context cleared.');
    },
  );

  test('late ack does not downgrade delivered outgoing message', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final sent = await notifier.sendMessage('hello');
    expect(sent, isTrue);
    final clientMessageId = container
        .read(chatControllerProvider)
        .messages
        .first
        .clientMessageId;
    expect(clientMessageId, isNotNull);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '201',
          event: 'message',
          data: <String, dynamic>{
            'client_message_id': clientMessageId,
            'message': <String, dynamic>{
              'type': 'text',
              'content': 'assistant reply',
            },
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '202',
          event: 'ack',
          data: <String, dynamic>{
            'client_message_id': clientMessageId,
            'job_id': 'ack-late',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.first.status.name, 'delivered');
    expect(state.messages.first.jobId, 'ack-late');
  });

  test('system event marks outgoing message delivered by client id', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    final sent = await notifier.sendMessage('hello');
    expect(sent, isTrue);
    final clientMessageId = container
        .read(chatControllerProvider)
        .messages
        .first
        .clientMessageId;
    expect(clientMessageId, isNotNull);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: '13',
          event: 'system',
          data: <String, dynamic>{
            'client_message_id': clientMessageId,
            'message': 'processing complete',
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages.first.status.name, 'delivered');
    expect(state.messages.last.text, 'processing complete');
    expect(state.lastEventId, '13');
  });

  test('controller reconnects stream using latest event id', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);
    expect(repository.streamControllers.length, 1);

    repository.streamControllers.first.add(
      Result<ChatSseEventEntity>.success(
        const ChatSseEventEntity(
          id: '3',
          event: 'message',
          data: <String, dynamic>{
            'message': <String, dynamic>{'type': 'text', 'content': 'hello'},
          },
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    await repository.streamControllers.first.close();
    await Future<void>.delayed(const Duration(milliseconds: 1200));

    expect(repository.streamCalls.length >= 2, isTrue);
    expect(repository.streamCalls[1].lastEventId, '3');
  });

  test(
    'sendMessage restarts streaming after a session-expired stream stop',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamControllers.length, 1);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.failure(SessionExpiredFailure()),
      );
      await Future<void>.delayed(Duration.zero);

      final sent = await container
          .read(chatControllerProvider.notifier)
          .sendMessage('hi');
      expect(sent, isTrue);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(repository.streamCalls.length >= 2, isTrue);
    },
  );

  test(
    'draft/resource copyWith APIs apply overrides and clear optional fields',
    () {
      final draft = ChatAttachmentDraft(
        id: 'att-1',
        filename: 'report.pdf',
        mimeType: 'application/pdf',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        caption: 'Initial',
        metadata: const <String, dynamic>{'a': 1},
      );
      final updatedDraft = draft.copyWith(
        caption: 'Updated',
        metadata: const <String, dynamic>{'b': 2},
      );
      expect(updatedDraft.caption, 'Updated');
      expect(updatedDraft.metadata, const <String, dynamic>{'b': 2});
      expect(updatedDraft.filename, 'report.pdf');

      final mediaState = ChatMediaResourceState(
        isLoading: true,
        objectUrl: 'blob://1',
        mimeType: 'text/plain',
        filename: 'note.txt',
        textPreview: 'hello',
        pdfPageAspectRatio: 1.4,
        spreadsheetPreview: const ChatSpreadsheetPreview(
          sheetName: 'Sheet1',
          rows: <List<String>>[
            <String>['A'],
          ],
          truncatedRows: false,
          truncatedColumns: false,
        ),
        errorMessage: 'failed',
      );
      final cleared = mediaState.copyWith(
        isLoading: false,
        clearObjectUrl: true,
        clearMimeType: true,
        clearFilename: true,
        clearTextPreview: true,
        clearPdfPageAspectRatio: true,
        clearSpreadsheetPreview: true,
        clearErrorMessage: true,
      );
      expect(cleared.isLoading, isFalse);
      expect(cleared.objectUrl, isNull);
      expect(cleared.mimeType, isNull);
      expect(cleared.filename, isNull);
      expect(cleared.textPreview, isNull);
      expect(cleared.pdfPageAspectRatio, isNull);
      expect(cleared.spreadsheetPreview, isNull);
      expect(cleared.errorMessage, isNull);
    },
  );

  test(
    'PlatformChatFilePicker returns empty list on canceled selection',
    () async {
      final previous = _captureFilePickerPlatform();
      FilePicker.platform = _FakePlatformFilePicker(null);
      addTearDown(() {
        if (previous != null) {
          FilePicker.platform = previous;
        }
      });

      final picker = PlatformChatFilePicker();
      final files = await picker.pickFiles();
      expect(files, isEmpty);
    },
  );

  test(
    'PlatformChatFilePicker maps extensions and skips null/empty byte entries',
    () async {
      final previous = _captureFilePickerPlatform();
      FilePicker.platform = _FakePlatformFilePicker(
        FilePickerResult(<PlatformFile>[
          _platformFile('photo.jpg'),
          _platformFile('photo.jpeg'),
          _platformFile('photo.png'),
          _platformFile('photo.gif'),
          _platformFile('photo.webp'),
          _platformFile('photo.bmp'),
          _platformFile('vector.svg'),
          _platformFile('song.mp3'),
          _platformFile('song.wav'),
          _platformFile('song.ogg'),
          _platformFile('song.m4a'),
          _platformFile('movie.mp4'),
          _platformFile('movie.webm'),
          _platformFile('movie.mov'),
          _platformFile('movie.mkv'),
          _platformFile('doc.pdf'),
          _platformFile('doc.txt'),
          _platformFile('doc.json'),
          _platformFile('sheet.xlsx'),
          _platformFile('sheet.xlsm'),
          _platformFile('README'),
          _platformFile('unknown.bin'),
          _platformFile('skip-empty', bytes: Uint8List(0)),
          PlatformFile(name: 'skip-null', size: 1, bytes: null),
        ]),
      );
      addTearDown(() {
        if (previous != null) {
          FilePicker.platform = previous;
        }
      });

      final picker = PlatformChatFilePicker();
      final files = await picker.pickFiles();
      final mapped = Map<String, String>.fromEntries(
        files.map((file) => MapEntry(file.filename, file.mimeType)),
      );

      expect(files.length, 22);
      expect(mapped['photo.jpg'], 'image/jpeg');
      expect(mapped['photo.jpeg'], 'image/jpeg');
      expect(mapped['photo.png'], 'image/png');
      expect(mapped['photo.gif'], 'image/gif');
      expect(mapped['photo.webp'], 'image/webp');
      expect(mapped['photo.bmp'], 'image/bmp');
      expect(mapped['vector.svg'], 'image/svg+xml');
      expect(mapped['song.mp3'], 'audio/mpeg');
      expect(mapped['song.wav'], 'audio/wav');
      expect(mapped['song.ogg'], 'audio/ogg');
      expect(mapped['song.m4a'], 'audio/mp4');
      expect(mapped['movie.mp4'], 'video/mp4');
      expect(mapped['movie.webm'], 'video/webm');
      expect(mapped['movie.mov'], 'video/quicktime');
      expect(mapped['movie.mkv'], 'video/x-matroska');
      expect(mapped['doc.pdf'], 'application/pdf');
      expect(mapped['doc.txt'], 'text/plain');
      expect(mapped['doc.json'], 'application/json');
      expect(
        mapped['sheet.xlsx'],
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      expect(
        mapped['sheet.xlsm'],
        'application/vnd.ms-excel.sheet.macroenabled.12',
      );
      expect(mapped['README'], 'application/octet-stream');
      expect(mapped['unknown.bin'], 'application/octet-stream');
      expect(mapped.containsKey('skip-empty'), isFalse);
      expect(mapped.containsKey('skip-null'), isFalse);
    },
  );

  test(
    'attachment mutators enforce max limit, update caption, and clear/remove values',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        filePicker: _FixedChatFilePicker(
          List<ChatPickedFile>.generate(kMaxComposerAttachments + 2, (index) {
            return ChatPickedFile(
              filename: 'file-$index.txt',
              mimeType: 'text/plain',
              bytes: Uint8List.fromList(<int>[index + 1]),
            );
          }),
        ),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.attachFromPicker();

      var state = container.read(chatControllerProvider);
      expect(state.attachments.length, kMaxComposerAttachments);
      expect(
        state.errorMessage,
        'You can attach up to $kMaxComposerAttachments files per message.',
      );
      expect(notifier.composerValidationError(''), isNull);

      final firstId = state.attachments.first.id;
      final secondId = state.attachments[1].id;
      notifier.updateAttachmentCaption(
        attachmentId: firstId,
        caption: 'updated caption',
      );
      notifier.removeAttachment(secondId);
      state = container.read(chatControllerProvider);
      expect(
        state.attachments
            .firstWhere((attachment) => attachment.id == firstId)
            .caption,
        'updated caption',
      );
      expect(
        state.attachments.where((attachment) => attachment.id == secondId),
        isEmpty,
      );

      notifier.clearError();
      notifier.setCompositionMode(ChatCompositionMode.messageWithAttachments);
      notifier.setCompositionMode(ChatCompositionMode.attachmentWithCaption);
      state = container.read(chatControllerProvider);
      expect(state.errorMessage, isNull);
      expect(state.compositionMode, ChatCompositionMode.attachmentWithCaption);

      notifier.clearAttachment();
      state = container.read(chatControllerProvider);
      expect(state.attachments, isEmpty);
    },
  );

  test(
    'clearTranscript clears state and revokes retained media object URLs',
    () async {
      final repository = _FakeChatRepository();
      final mediaPlatform = _RecordingMediaPlatform();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        mediaPlatform: mediaPlatform,
        filePicker: _FixedChatFilePicker(<ChatPickedFile>[
          ChatPickedFile(
            filename: 'inline.png',
            mimeType: 'image/png',
            bytes: Uint8List.fromList(<int>[1, 2, 3, 4]),
          ),
        ]),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);
      await notifier.attachFromPicker();
      final sent = await notifier.sendMessage('image');
      expect(sent, isTrue);

      var state = container.read(chatControllerProvider);
      expect(state.messages, isNotEmpty);
      expect(state.mediaResources, isNotEmpty);

      notifier.clearTranscript();
      state = container.read(chatControllerProvider);
      expect(state.messages, isEmpty);
      expect(state.mediaResources, isEmpty);
      expect(state.attachments, isEmpty);
      expect(mediaPlatform.revokedUrls, isNotEmpty);
    },
  );

  test(
    'sendMessage marks optimistic row failed when sendText returns failure',
    () async {
      final repository = _FakeChatRepository();
      repository.sendTextResponse =
          const Result<ChatSendAcceptedEntity>.failure(
            NetworkFailure('send failed'),
          );
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero);

      final sent = await notifier.sendMessage('hello');
      expect(sent, isFalse);

      final state = container.read(chatControllerProvider);
      expect(state.messages.length, 1);
      expect(state.messages.single.status, ChatMessageStatus.failed);
      expect(state.messages.single.errorMessage, 'send failed');
      expect(state.errorMessage, 'send failed');
    },
  );

  test(
    'ensureMediaLoaded records failure and skips duplicate fetch when error is already cached',
    () async {
      final repository = _FakeChatRepository();
      repository.downloadMediaResponse =
          const Result<ChatMediaDownloadEntity>.failure(
            ApiFailure(500, 'download failed'),
          );
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'media-1',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'file',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/1',
                  'mime_type': 'text/plain',
                  'filename': 'note.txt',
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(chatControllerProvider);
      final assistantId = state.messages.last.id;
      expect(
        state.mediaResources[assistantId]?.errorMessage,
        'download failed',
      );
      expect(repository.downloadMediaCallCount, 1);

      await notifier.ensureMediaLoaded(assistantId);
      expect(repository.downloadMediaCallCount, 1);
    },
  );

  test(
    'retryMediaLoad revokes previous object URL and downloadMediaToDevice triggers browser download',
    () async {
      final repository = _FakeChatRepository();
      repository.downloadMediaResponse =
          Result<ChatMediaDownloadEntity>.success(
            ChatMediaDownloadEntity(
              bytes: Uint8List.fromList(utf8.encode('hello world')),
              mimeType: 'text/plain; charset=utf-8',
              filename: '   ',
            ),
          );
      final mediaPlatform = _RecordingMediaPlatform();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
        mediaPlatform: mediaPlatform,
      );
      addTearDown(container.dispose);

      final notifier = container.read(chatControllerProvider.notifier);
      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      await notifier.downloadMediaToDevice('missing-id');
      expect(mediaPlatform.downloads, isEmpty);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'media-2',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'file',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/2',
                  'mime_type': 'text/plain',
                  'filename': 'server-name.txt',
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      var state = container.read(chatControllerProvider);
      final assistantId = state.messages.last.id;
      final previousUrl = state.mediaResources[assistantId]?.objectUrl;
      expect(previousUrl, isNotNull);

      await notifier.retryMediaLoad(assistantId);
      state = container.read(chatControllerProvider);
      final reloadedUrl = state.mediaResources[assistantId]?.objectUrl;
      expect(reloadedUrl, isNotNull);
      expect(reloadedUrl, isNot(previousUrl));
      expect(mediaPlatform.revokedUrls, contains(previousUrl));
      expect(repository.downloadMediaCallCount, greaterThanOrEqualTo(2));

      await notifier.downloadMediaToDevice(assistantId);
      expect(mediaPlatform.downloads, hasLength(1));
      expect(mediaPlatform.downloads.single.url, reloadedUrl);
      expect(mediaPlatform.downloads.single.filename, 'download');
    },
  );

  test(
    'stream unauthorized failure stops loop and surfaces auth error',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamControllers, isNotEmpty);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.failure(UnauthorizedFailure()),
      );
      await Future<void>.delayed(Duration.zero);

      final state = container.read(chatControllerProvider);
      expect(state.isConnected, isFalse);
      expect(state.isConnecting, isFalse);
      expect(state.errorMessage, 'Unauthorized request.');
    },
  );

  test(
    '404 stream open failures reconnect without surfacing generic error',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repository.streamControllers.length, 1);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.failure(
          ApiFailure(404, 'conversation missing'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 1200));

      final state = container.read(chatControllerProvider);
      expect(state.errorMessage, isNull);
      expect(repository.streamCalls.length, greaterThanOrEqualTo(2));
    },
  );

  test(
    'system fallback text and media payload parsing handle mixed event shapes',
    () async {
      final repository = _FakeChatRepository();
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'sys-json',
            event: 'system',
            data: <String, dynamic>{'foo': 'bar'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      var state = container.read(chatControllerProvider);
      expect(state.messages.last.role, ChatMessageRole.system);
      expect(state.messages.last.text, contains('"foo":"bar"'));

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'img-int',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'image',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/int',
                  'mime_type': 'image/png',
                  'filename': 'img-int.png',
                  'expires_at': 1700000000,
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'img-num',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'image',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/num',
                  'mime_type': 'image/png',
                  'filename': 'img-num.png',
                  'expires_at': 1700000000.25,
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'img-string',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'image',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/string',
                  'mime_type': 'image/png',
                  'filename': 'img-string.png',
                  'expires_at': '1700000001',
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      final latestImage = state.messages.last;
      expect(latestImage.media, isNotNull);
      expect(latestImage.media!.url, '/api/core/web/v1/media/string');
      expect(latestImage.media!.expiresAt, isNotNull);

      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'img-raw',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'file',
                'content': 'non-map payload',
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      state = container.read(chatControllerProvider);
      expect(state.messages.last.type, ChatMessageType.file);
      expect(state.messages.last.media, isNull);
    },
  );

  test('provider factories resolve concrete defaults without overrides', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(chatLocalStorageProvider), isA<ChatLocalStorage>());
    expect(
      container.read(mediaObjectUrlPlatformProvider),
      isA<MediaObjectUrlPlatform>(),
    );
    expect(container.read(chatFilePickerProvider), isA<ChatFilePicker>());
    expect(container.read(chatRepositoryProvider), isA<ChatRepository>());
    expect(container.read(chatApplicationServiceProvider), isNotNull);
  });

  test('clearTranscript is a no-op when state is already empty', () async {
    final repository = _FakeChatRepository();
    final mediaPlatform = _RecordingMediaPlatform();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
      mediaPlatform: mediaPlatform,
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    notifier.clearTranscript();
    final state = container.read(chatControllerProvider);
    expect(state.messages, isEmpty);
    expect(state.mediaResources, isEmpty);
    expect(mediaPlatform.revokedUrls, isEmpty);
  });

  test('non-404 stream failures surface their error message', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.failure(
        ApiFailure(500, 'stream failed'),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));

    final state = container.read(chatControllerProvider);
    expect(state.errorMessage, 'stream failed');
  });

  test('unknown SSE event names are handled as system messages', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);

    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: 'mystery-1',
          event: 'mystery',
          data: <String, dynamic>{'message': 'mystery payload'},
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    final state = container.read(chatControllerProvider);
    expect(state.messages, hasLength(1));
    expect(state.messages.single.role, ChatMessageRole.system);
    expect(state.messages.single.text, 'mystery payload');
  });

  test(
    'error events mark outgoing rows failed by client id and fallback',
    () async {
      final byClientRepository = _FakeChatRepository();
      final byClientContainer = _buildContainer(
        repository: byClientRepository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(byClientContainer.dispose);

      final byClientNotifier = byClientContainer.read(
        chatControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      final sentByClient = await byClientNotifier.sendMessage('by-client');
      expect(sentByClient, isTrue);
      final clientMessageId = byClientContainer
          .read(chatControllerProvider)
          .messages
          .single
          .clientMessageId;
      expect(clientMessageId, isNotNull);

      byClientRepository.streamControllers.first.add(
        Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'err-client',
            event: 'error',
            data: <String, dynamic>{
              'client_message_id': clientMessageId,
              'error': 'client id failed',
            },
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final byClientState = byClientContainer.read(chatControllerProvider);
      final byClientUser = byClientState.messages.firstWhere(
        (message) => message.role == ChatMessageRole.user,
      );
      expect(byClientUser.status, ChatMessageStatus.failed);
      expect(byClientUser.eventId, 'err-client');

      final fallbackRepository = _FakeChatRepository();
      final fallbackContainer = _buildContainer(
        repository: fallbackRepository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(fallbackContainer.dispose);
      final fallbackNotifier = fallbackContainer.read(
        chatControllerProvider.notifier,
      );
      await Future<void>.delayed(Duration.zero);
      final sentFallback = await fallbackNotifier.sendMessage('fallback');
      expect(sentFallback, isTrue);

      fallbackRepository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: null,
            event: 'error',
            data: <String, dynamic>{'error': 'fallback failed'},
          ),
        ),
      );
      await Future<void>.delayed(Duration.zero);
      final fallbackState = fallbackContainer.read(chatControllerProvider);
      final fallbackUser = fallbackState.messages.firstWhere(
        (message) => message.role == ChatMessageRole.user,
      );
      expect(fallbackUser.status, ChatMessageStatus.failed);
    },
  );

  test('copyWith overrides cover direct field-update paths', () {
    final draft = ChatAttachmentDraft(
      id: 'draft-1',
      filename: 'first.txt',
      mimeType: 'text/plain',
      bytes: Uint8List.fromList(<int>[1]),
    );
    final updatedDraft = draft.copyWith(bytes: Uint8List.fromList(<int>[2, 3]));
    expect(updatedDraft.bytes, Uint8List.fromList(<int>[2, 3]));

    final resource = ChatMediaResourceState(
      isLoading: false,
      objectUrl: 'blob://a',
      mimeType: 'text/plain',
      filename: 'first.txt',
      textPreview: 'a',
      pdfPageAspectRatio: 1.0,
      spreadsheetPreview: const ChatSpreadsheetPreview(
        sheetName: 'Sheet',
        rows: <List<String>>[
          <String>['A'],
        ],
        truncatedRows: false,
        truncatedColumns: false,
      ),
      errorMessage: 'err',
    );
    final updatedResource = resource.copyWith(
      objectUrl: 'blob://b',
      mimeType: 'application/pdf',
      filename: 'second.pdf',
      textPreview: 'preview',
      pdfPageAspectRatio: 1.7,
      spreadsheetPreview: const ChatSpreadsheetPreview(
        sheetName: 'Sheet2',
        rows: <List<String>>[
          <String>['B'],
        ],
        truncatedRows: true,
        truncatedColumns: true,
      ),
      errorMessage: 'updated',
    );
    expect(updatedResource.objectUrl, 'blob://b');
    expect(updatedResource.mimeType, 'application/pdf');
    expect(updatedResource.filename, 'second.pdf');
    expect(updatedResource.textPreview, 'preview');
    expect(updatedResource.pdfPageAspectRatio, 1.7);
    expect(updatedResource.spreadsheetPreview?.sheetName, 'Sheet2');
    expect(updatedResource.errorMessage, 'updated');
  });

  test('pdf attachment sends with local preview ratio', () async {
    final repository = _FakeChatRepository();
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
      filePicker: _FixedChatFilePicker(<ChatPickedFile>[
        ChatPickedFile(
          filename: 'report.pdf',
          mimeType: 'application/pdf',
          bytes: _buildPdfWithMediaBoxBytes(),
        ),
      ]),
    );
    addTearDown(container.dispose);

    final notifier = container.read(chatControllerProvider.notifier);
    await Future<void>.delayed(Duration.zero);

    await notifier.attachFromPicker();
    final sent = await notifier.sendMessage('pdf');
    expect(sent, isTrue);

    final state = container.read(chatControllerProvider);
    final messageId = state.messages.last.id;
    expect(state.mediaResources[messageId]?.pdfPageAspectRatio, isNotNull);
  });

  test(
    'spreadsheet/media parsing covers boolean, formula, and truncation paths',
    () async {
      final repository = _FakeChatRepository();
      repository
          .downloadMediaResponse = Result<ChatMediaDownloadEntity>.success(
        ChatMediaDownloadEntity(
          bytes: _buildSpreadsheetBytesForEdgeCells(),
          mimeType:
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          filename: 'edge.xlsx',
        ),
      );
      final container = _buildContainer(
        repository: repository,
        storage: _InMemoryChatLocalStorage(),
      );
      addTearDown(container.dispose);

      container.read(chatControllerProvider);
      await Future<void>.delayed(Duration.zero);
      repository.streamControllers.first.add(
        const Result<ChatSseEventEntity>.success(
          ChatSseEventEntity(
            id: 'media-xlsx-edge',
            event: 'message',
            data: <String, dynamic>{
              'message': <String, dynamic>{
                'type': 'file',
                'content': <String, dynamic>{
                  'url': '/api/core/web/v1/media/edge',
                  'mime_type':
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  'filename': 'edge.xlsx',
                },
              },
            },
          ),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));

      final state = container.read(chatControllerProvider);
      final media = state.mediaResources[state.messages.last.id];
      expect(media, isNotNull);
      expect(media!.spreadsheetPreview, isNotNull);
      final rows = media.spreadsheetPreview!.rows;
      expect(rows, isNotEmpty);
      expect(rows.first, contains('TRUE'));
      expect(rows.first, contains('FALSE'));
      expect(rows.first.where((cell) => cell.startsWith('=')), isNotEmpty);
      expect(
        rows.first.where((cell) => cell.endsWith('...') && cell.length >= 120),
        isNotEmpty,
      );
    },
  );

  test('text preview generation trims long line+char payloads', () async {
    final repository = _FakeChatRepository();
    final longLine = List<String>.filled(80, 'abcdefghijklmnop').join();
    final longText = List<String>.generate(60, (_) => longLine).join('\n');
    repository.downloadMediaResponse = Result<ChatMediaDownloadEntity>.success(
      ChatMediaDownloadEntity(
        bytes: Uint8List.fromList(utf8.encode(longText)),
        mimeType: 'text/plain',
        filename: 'long.txt',
      ),
    );
    final container = _buildContainer(
      repository: repository,
      storage: _InMemoryChatLocalStorage(),
    );
    addTearDown(container.dispose);

    container.read(chatControllerProvider);
    await Future<void>.delayed(Duration.zero);
    repository.streamControllers.first.add(
      const Result<ChatSseEventEntity>.success(
        ChatSseEventEntity(
          id: 'media-long-text',
          event: 'message',
          data: <String, dynamic>{
            'message': <String, dynamic>{
              'type': 'file',
              'content': <String, dynamic>{
                'url': '/api/core/web/v1/media/long',
                'mime_type': 'text/plain',
                'filename': 'long.txt',
              },
            },
          },
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    final state = container.read(chatControllerProvider);
    final preview = state.mediaResources[state.messages.last.id]?.textPreview;
    expect(preview, isNotNull);
    expect(preview, contains('...'));
    expect(preview!.length, lessThanOrEqualTo(4100));
  });
}

Uint8List _buildSampleXlsxBytes() {
  const workbookXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook '
      'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
      '<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>'
      '</workbook>';
  const workbookRelsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships '
      'xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" '
      'Target="worksheets/sheet1.xml"/>'
      '</Relationships>';
  const sheetXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet '
      'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>'
      '<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c></row>'
      '<row r="2"><c r="A2" t="inlineStr"><is><t>CPU</t></is></c><c r="B2"><v>42</v></c></row>'
      '</sheetData>'
      '</worksheet>';
  const sharedStringsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<sst '
      'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
      'count="2" uniqueCount="2">'
      '<si><t>Name</t></si><si><t>Value</t></si>'
      '</sst>';

  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        workbookXml.length,
        utf8.encode(workbookXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/_rels/workbook.xml.rels',
        workbookRelsXml.length,
        utf8.encode(workbookRelsXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        sheetXml.length,
        utf8.encode(sheetXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/sharedStrings.xml',
        sharedStringsXml.length,
        utf8.encode(sharedStringsXml),
      ),
    );

  final zipped = ZipEncoder().encode(archive);
  if (zipped == null) {
    throw StateError('Could not build xlsx fixture');
  }
  return Uint8List.fromList(zipped);
}

Uint8List _buildPdfWithMediaBoxBytes() {
  const content =
      '%PDF-1.7\n'
      '1 0 obj\n'
      '<< /Type /Page /MediaBox [0 0 595 842] >>\n'
      'endobj\n'
      '%%EOF';
  return Uint8List.fromList(latin1.encode(content));
}

Uint8List _buildSpreadsheetBytesForEdgeCells() {
  const workbookXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<workbook '
      'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheets><sheet name="Sheet1" sheetId="1" id="rId1"/></sheets>'
      '</workbook>';
  final longInline = List<String>.filled(140, 'x').join();
  final worksheetXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<worksheet '
      'xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
      '<sheetData>'
      '<row r="1">'
      '<c r="A1" t="b"><v>1</v></c>'
      '<c r="B1" t="b"><v>0</v></c>'
      '<c r="C1"><f>SUM(1,2)</f></c>'
      '<c r="D1" t="inlineStr"><is><t>$longInline</t></is></c>'
      '</row>'
      '</sheetData>'
      '</worksheet>';

  final archive = Archive()
    ..addFile(
      ArchiveFile(
        'xl/workbook.xml',
        workbookXml.length,
        utf8.encode(workbookXml),
      ),
    )
    ..addFile(
      ArchiveFile(
        'xl/worksheets/sheet1.xml',
        worksheetXml.length,
        utf8.encode(worksheetXml),
      ),
    );

  final zipped = ZipEncoder().encode(archive);
  if (zipped == null) {
    throw StateError('Could not build spreadsheet edge fixture');
  }
  return Uint8List.fromList(zipped);
}

FilePicker? _captureFilePickerPlatform() {
  try {
    return FilePicker.platform;
  } catch (_) {
    return null;
  }
}

PlatformFile _platformFile(String name, {Uint8List? bytes}) {
  final payload = bytes ?? Uint8List.fromList(<int>[1]);
  return PlatformFile(name: name, size: payload.length, bytes: payload);
}

ProviderContainer _buildContainer({
  required _FakeChatRepository repository,
  required ChatLocalStorage storage,
  _FakeAuthRepository? authRepository,
  ChatFilePicker? filePicker,
  MediaObjectUrlPlatform? mediaPlatform,
}) {
  final overrides = <Override>[
    authRepositoryProvider.overrideWithValue(
      authRepository ??
          _FakeAuthRepository(
            const AuthSession(
              accessToken: 'token',
              refreshToken: 'refresh',
              userId: 'user-1',
              roles: <String>[],
            ),
          ),
    ),
    chatRepositoryProvider.overrideWithValue(repository),
    chatLocalStorageProvider.overrideWithValue(storage),
    mediaObjectUrlPlatformProvider.overrideWithValue(
      mediaPlatform ?? _NoopMediaPlatform(),
    ),
  ];
  if (filePicker != null) {
    overrides.add(chatFilePickerProvider.overrideWithValue(filePicker));
  }

  return ProviderContainer(overrides: overrides);
}

class _FixedChatFilePicker implements ChatFilePicker {
  _FixedChatFilePicker(this.results);

  final List<ChatPickedFile> results;

  @override
  Future<List<ChatPickedFile>> pickFiles() async {
    return results;
  }
}

class _FakeChatRepository implements ChatRepository {
  final List<_StreamCall> streamCalls = <_StreamCall>[];
  final List<StreamController<Result<ChatSseEventEntity>>> streamControllers =
      <StreamController<Result<ChatSseEventEntity>>>[];
  int sendComposedCallCount = 0;
  _ComposedCall? lastComposedCall;
  Completer<Result<ChatSendAcceptedEntity>>? pendingSendTextCompleter;
  int downloadMediaCallCount = 0;
  final List<_DownloadCall> downloadMediaCalls = <_DownloadCall>[];

  Result<ChatSendAcceptedEntity> sendTextResponse =
      Result<ChatSendAcceptedEntity>.success(
        ChatSendAcceptedEntity(
          jobId: 'job-send',
          conversationId: 'conv',
          acceptedAt: DateTime.utc(2026, 1, 1),
        ),
      );
  Result<ChatMediaDownloadEntity> downloadMediaResponse =
      Result<ChatMediaDownloadEntity>.success(
        ChatMediaDownloadEntity(
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
          mimeType: 'application/octet-stream',
          filename: 'download.bin',
        ),
      );

  @override
  Future<Result<ChatMediaDownloadEntity>> downloadMedia({
    required String mediaUrl,
    String? suggestedFilename,
    String? suggestedMimeType,
  }) async {
    downloadMediaCallCount += 1;
    downloadMediaCalls.add(
      _DownloadCall(
        mediaUrl: mediaUrl,
        suggestedFilename: suggestedFilename,
        suggestedMimeType: suggestedMimeType,
      ),
    );
    return downloadMediaResponse;
  }

  @override
  Future<Result<ChatSendAcceptedEntity>> sendText({
    required String conversationId,
    required String clientMessageId,
    required String text,
    Map<String, dynamic>? metadata,
  }) async {
    final pending = pendingSendTextCompleter;
    if (pending != null) {
      return pending.future;
    }
    return sendTextResponse;
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
    return Result<ChatSendAcceptedEntity>.success(
      ChatSendAcceptedEntity(
        jobId: 'job-upload',
        conversationId: conversationId,
        acceptedAt: DateTime.utc(2026, 1, 1),
      ),
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
    sendComposedCallCount += 1;
    lastComposedCall = _ComposedCall(
      conversationId: conversationId,
      clientMessageId: clientMessageId,
      compositionMode: compositionMode,
      parts: parts,
      attachments: attachments,
      metadata: metadata,
    );
    return Result<ChatSendAcceptedEntity>.success(
      ChatSendAcceptedEntity(
        jobId: 'job-composed',
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
    streamCalls.add(
      _StreamCall(conversationId: conversationId, lastEventId: lastEventId),
    );
    final controller = StreamController<Result<ChatSseEventEntity>>();
    streamControllers.add(controller);
    return controller.stream;
  }
}

class _StreamCall {
  const _StreamCall({required this.conversationId, required this.lastEventId});

  final String conversationId;
  final String? lastEventId;
}

class _DownloadCall {
  const _DownloadCall({
    required this.mediaUrl,
    required this.suggestedFilename,
    required this.suggestedMimeType,
  });

  final String mediaUrl;
  final String? suggestedFilename;
  final String? suggestedMimeType;
}

class _ComposedCall {
  const _ComposedCall({
    required this.conversationId,
    required this.clientMessageId,
    required this.compositionMode,
    required this.parts,
    required this.attachments,
    required this.metadata,
  });

  final String conversationId;
  final String clientMessageId;
  final ChatCompositionMode compositionMode;
  final List<ChatComposedPartEntity> parts;
  final List<ChatComposedAttachmentEntity> attachments;
  final Map<String, dynamic>? metadata;
}

class _InMemoryChatLocalStorage implements ChatLocalStorage {
  final Map<String, String> _values = <String, String>{};

  @override
  String? getItem(String key) {
    return _values[key];
  }

  @override
  void removeItem(String key) {
    _values.remove(key);
  }

  @override
  void setItem(String key, String value) {
    _values[key] = value;
  }
}

class _SizeLimitedChatLocalStorage implements ChatLocalStorage {
  _SizeLimitedChatLocalStorage({required this.maxBytes});

  final int maxBytes;
  final Map<String, String> _values = <String, String>{};
  int writeAttempts = 0;

  @override
  String? getItem(String key) {
    return _values[key];
  }

  @override
  void removeItem(String key) {
    _values.remove(key);
  }

  @override
  void setItem(String key, String value) {
    writeAttempts += 1;
    if (value.length > maxBytes) {
      throw StateError('value too large');
    }
    _values[key] = value;
  }
}

class _NoopMediaPlatform implements MediaObjectUrlPlatform {
  @override
  String createObjectUrl({required Uint8List bytes, required String mimeType}) {
    return 'blob://test';
  }

  @override
  void revokeObjectUrl(String url) {}

  @override
  void triggerDownload({required String url, required String filename}) {}
}

class _RecordingMediaPlatform implements MediaObjectUrlPlatform {
  final List<String> revokedUrls = <String>[];
  final List<_DownloadTrigger> downloads = <_DownloadTrigger>[];
  int _counter = 0;

  @override
  String createObjectUrl({required Uint8List bytes, required String mimeType}) {
    _counter += 1;
    return 'blob://recorded-$_counter';
  }

  @override
  void revokeObjectUrl(String url) {
    revokedUrls.add(url);
  }

  @override
  void triggerDownload({required String url, required String filename}) {
    downloads.add(_DownloadTrigger(url: url, filename: filename));
  }
}

class _DownloadTrigger {
  const _DownloadTrigger({required this.url, required this.filename});

  final String url;
  final String filename;
}

class _FakePlatformFilePicker extends FilePicker {
  _FakePlatformFilePicker(this.result);

  final FilePickerResult? result;

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._session);

  AuthSession? _session;
  AuthSession? nextLoginSession;

  @override
  Result<AuthSession?> currentSession() {
    return Result<AuthSession?>.success(_session);
  }

  @override
  Result<bool> hasRoles({
    required List<String> roles,
    String operator = 'and',
  }) {
    return const Result<bool>.success(true);
  }

  @override
  Future<Result<AuthSession>> login({
    required String username,
    required String password,
  }) async {
    final session =
        nextLoginSession ??
        AuthSession(
          accessToken: 'token-$username',
          refreshToken: 'refresh-$username',
          userId: username,
          roles: const <String>[],
        );
    _session = session;
    return Result<AuthSession>.success(session);
  }

  @override
  Future<Result<void>> logout() async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetOwnPassword({
    required String currentPassword,
    required String newPassword,
    required String confirmNewPassword,
  }) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<OwnProfileEntity>> fetchOwnProfile() async {
    return const Result<OwnProfileEntity>.failure(
      UnauthorizedFailure('Not implemented'),
    );
  }

  @override
  Future<Result<void>> updateOwnProfile(UpdateOwnProfileInput input) async {
    return const Result<void>.success(null);
  }
}
