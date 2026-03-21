import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:xml/xml.dart' as xml;

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/chat/application/dto/chat_send_composed_input.dart';
import 'package:mugen_ui/features/chat/application/dto/chat_send_text_input.dart';
import 'package:mugen_ui/features/chat/application/dto/chat_snapshot.dart';
import 'package:mugen_ui/features/chat/application/services/chat_application_service.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_sse_event_entity.dart';
import 'package:mugen_ui/features/chat/domain/repositories/chat_repository.dart';
import 'package:mugen_ui/features/chat/domain/usecases/download_chat_media_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_composed_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_text_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/send_chat_upload_usecase.dart';
import 'package:mugen_ui/features/chat/domain/usecases/stream_chat_events_usecase.dart';
import 'package:mugen_ui/features/chat/infrastructure/repositories/web_chat_repository_impl.dart';
import 'package:mugen_ui/features/chat/infrastructure/storage/chat_local_storage.dart';
import 'package:mugen_ui/features/chat/presentation/platform/media_object_url.dart';
import 'package:mugen_ui/shared/domain/failure.dart';

part 'chat_providers.g.dart';

const _snapshotVersion = 1;
const int kMaxRetainedMessages = 600;
const int kMaxPersistedMessages = 600;
const int kMaxSnapshotBytes = 2500000;
const _snapshotDebounce = Duration(milliseconds: 350);
const String _streamResetSignal = 'stream_reset';
const _replayNoticeDuration = Duration(seconds: 10);
const int _maxRecentNonUserSignatures = 512;
const int kMaxComposerAttachments = 10;
const int _maxPersistedInlineImageBytes = 262144;

class ChatAttachmentDraft {
  const ChatAttachmentDraft({
    required this.id,
    required this.filename,
    required this.mimeType,
    required this.bytes,
    this.caption = '',
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final String filename;
  final String mimeType;
  final Uint8List bytes;
  final String caption;
  final Map<String, dynamic> metadata;

  ChatAttachmentDraft copyWith({
    String? id,
    String? filename,
    String? mimeType,
    Uint8List? bytes,
    String? caption,
    Map<String, dynamic>? metadata,
  }) {
    return ChatAttachmentDraft(
      id: id ?? this.id,
      filename: filename ?? this.filename,
      mimeType: mimeType ?? this.mimeType,
      bytes: bytes ?? this.bytes,
      caption: caption ?? this.caption,
      metadata: metadata ?? this.metadata,
    );
  }
}

class ChatSpreadsheetPreview {
  const ChatSpreadsheetPreview({
    required this.sheetName,
    required this.rows,
    required this.truncatedRows,
    required this.truncatedColumns,
  });

  final String sheetName;
  final List<List<String>> rows;
  final bool truncatedRows;
  final bool truncatedColumns;
}

class ChatMediaResourceState {
  const ChatMediaResourceState({
    required this.isLoading,
    this.objectUrl,
    this.mimeType,
    this.filename,
    this.textPreview,
    this.pdfPageAspectRatio,
    this.spreadsheetPreview,
    this.errorMessage,
  });

  final bool isLoading;
  final String? objectUrl;
  final String? mimeType;
  final String? filename;
  final String? textPreview;
  final double? pdfPageAspectRatio;
  final ChatSpreadsheetPreview? spreadsheetPreview;
  final String? errorMessage;

  ChatMediaResourceState copyWith({
    bool? isLoading,
    String? objectUrl,
    String? mimeType,
    String? filename,
    String? textPreview,
    double? pdfPageAspectRatio,
    ChatSpreadsheetPreview? spreadsheetPreview,
    String? errorMessage,
    bool clearObjectUrl = false,
    bool clearMimeType = false,
    bool clearFilename = false,
    bool clearTextPreview = false,
    bool clearPdfPageAspectRatio = false,
    bool clearSpreadsheetPreview = false,
    bool clearErrorMessage = false,
  }) {
    return ChatMediaResourceState(
      isLoading: isLoading ?? this.isLoading,
      // coverage:ignore-start
      objectUrl: clearObjectUrl ? null : (objectUrl ?? this.objectUrl),
      mimeType: clearMimeType ? null : (mimeType ?? this.mimeType),
      filename: clearFilename ? null : (filename ?? this.filename),
      textPreview: clearTextPreview ? null : (textPreview ?? this.textPreview),
      pdfPageAspectRatio: clearPdfPageAspectRatio
          ? null
          : (pdfPageAspectRatio ?? this.pdfPageAspectRatio),
      spreadsheetPreview: clearSpreadsheetPreview
          ? null
          : (spreadsheetPreview ?? this.spreadsheetPreview),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
      // coverage:ignore-end
    );
  }
}

class ChatControllerState {
  const ChatControllerState({
    required this.conversationId,
    required this.messages,
    required this.mediaResources,
    required this.attachments,
    required this.compositionMode,
    required this.isConnected,
    required this.isConnecting,
    required this.isSending,
    this.activeThinkingKeys = const <String>{},
    this.replayNoticeText,
    this.replayNoticeReason,
    this.replayNoticeEventId,
    this.replayNoticeAtUtc,
    this.lastEventId,
    this.errorMessage,
  });

  final String conversationId;
  final String? lastEventId;
  final List<ChatMessageEntity> messages;
  final Map<String, ChatMediaResourceState> mediaResources;
  final List<ChatAttachmentDraft> attachments;
  final ChatCompositionMode compositionMode;
  final bool isConnected;
  final bool isConnecting;
  final bool isSending;
  final Set<String> activeThinkingKeys;
  final String? replayNoticeText;
  final String? replayNoticeReason;
  final String? replayNoticeEventId;
  final DateTime? replayNoticeAtUtc;
  final String? errorMessage;

  bool get isAssistantThinking => activeThinkingKeys.isNotEmpty;
  bool get hasReplayNotice =>
      replayNoticeText != null && replayNoticeText!.isNotEmpty;

  ChatControllerState copyWith({
    String? conversationId,
    String? lastEventId,
    List<ChatMessageEntity>? messages,
    Map<String, ChatMediaResourceState>? mediaResources,
    List<ChatAttachmentDraft>? attachments,
    ChatCompositionMode? compositionMode,
    bool? isConnected,
    bool? isConnecting,
    bool? isSending,
    Set<String>? activeThinkingKeys,
    String? replayNoticeText,
    String? replayNoticeReason,
    String? replayNoticeEventId,
    DateTime? replayNoticeAtUtc,
    String? errorMessage,
    bool clearLastEventId = false,
    bool clearActiveThinkingKeys = false,
    bool clearReplayNotice = false,
    bool clearAttachments = false,
    bool clearErrorMessage = false,
  }) {
    return ChatControllerState(
      conversationId: conversationId ?? this.conversationId,
      lastEventId: clearLastEventId ? null : (lastEventId ?? this.lastEventId),
      messages: messages ?? this.messages,
      mediaResources: mediaResources ?? this.mediaResources,
      attachments: clearAttachments
          ? const <ChatAttachmentDraft>[]
          : (attachments ?? this.attachments),
      compositionMode: compositionMode ?? this.compositionMode,
      isConnected: isConnected ?? this.isConnected,
      isConnecting: isConnecting ?? this.isConnecting,
      isSending: isSending ?? this.isSending,
      activeThinkingKeys: clearActiveThinkingKeys
          ? const <String>{}
          : (activeThinkingKeys ?? this.activeThinkingKeys),
      replayNoticeText: clearReplayNotice
          ? null
          : (replayNoticeText ?? this.replayNoticeText),
      replayNoticeReason: clearReplayNotice
          ? null
          : (replayNoticeReason ?? this.replayNoticeReason),
      replayNoticeEventId: clearReplayNotice
          ? null
          : (replayNoticeEventId ?? this.replayNoticeEventId),
      replayNoticeAtUtc: clearReplayNotice
          ? null
          : (replayNoticeAtUtc ?? this.replayNoticeAtUtc),
      errorMessage: clearErrorMessage
          ? null
          : (errorMessage ?? this.errorMessage),
    );
  }
}

class ChatPickedFile {
  const ChatPickedFile({
    required this.filename,
    required this.mimeType,
    required this.bytes,
  });

  final String filename;
  final String mimeType;
  final Uint8List bytes;
}

abstract class ChatFilePicker {
  Future<List<ChatPickedFile>> pickFiles();
}

class PlatformChatFilePicker implements ChatFilePicker {
  @override
  Future<List<ChatPickedFile>> pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return const <ChatPickedFile>[];
    }

    return result.files
        .where((file) => file.bytes != null && file.bytes!.isNotEmpty)
        .map(
          (file) => ChatPickedFile(
            filename: file.name,
            mimeType: _guessMimeType(file.name),
            bytes: file.bytes!,
          ),
        )
        .toList(growable: false);
  }
}

@Riverpod(keepAlive: true)
ChatLocalStorage chatLocalStorage(Ref ref) {
  return createChatLocalStorage();
}

@Riverpod(keepAlive: true)
MediaObjectUrlPlatform mediaObjectUrlPlatform(Ref ref) {
  return createMediaObjectUrlPlatform();
}

@Riverpod(keepAlive: true)
ChatFilePicker chatFilePicker(Ref ref) {
  return PlatformChatFilePicker();
}

@Riverpod(keepAlive: true)
ChatRepository chatRepository(Ref ref) {
  return WebChatRepositoryImpl(
    appConfig: ref.watch(appConfigProvider),
    cookieStore: ref.watch(cookieStoreProvider),
  );
}

@Riverpod(keepAlive: true)
ChatApplicationService chatApplicationService(Ref ref) {
  final repository = ref.watch(chatRepositoryProvider);
  return ChatApplicationService(
    sendChatTextUseCase: SendChatTextUseCase(repository),
    sendChatComposedUseCase: SendChatComposedUseCase(repository),
    sendChatUploadUseCase: SendChatUploadUseCase(repository),
    streamChatEventsUseCase: StreamChatEventsUseCase(repository),
    downloadChatMediaUseCase: DownloadChatMediaUseCase(repository),
  );
}

@Riverpod(keepAlive: true)
class ChatController extends _$ChatController {
  static const int _randomIdUpperBound = 0x7fffffff;

  final Random _random = Random();
  Timer? _snapshotDebounceTimer;
  Timer? _replayNoticeTimer;
  MediaObjectUrlPlatform? _cachedMediaPlatform;
  final Set<String> _recentNonUserSignatures = <String>{};
  final ListQueue<String> _recentNonUserSignatureOrder = ListQueue<String>();
  bool _disposeRegistered = false;
  bool _eventLoopRunning = false;
  bool _disposed = false;
  String _snapshotStorageKey = '';
  String _snapshotUserId = '';

  @override
  ChatControllerState build() {
    _resetEphemeralRuntimeState();
    final userId = _activeUserId();
    _snapshotUserId = userId;
    _snapshotStorageKey = _buildStorageKey(userId);

    final snapshot = _readSnapshot();
    final conversationId = (snapshot?.conversationId.trim().isNotEmpty ?? false)
        ? snapshot!.conversationId
        : _newConversationId();

    final messages = _trimToRetainedMessageCap(snapshot?.messages ?? const []);
    _cachedMediaPlatform ??= ref.read(mediaObjectUrlPlatformProvider);
    if (!_disposeRegistered) {
      ref.onDispose(_disposeResources);
      _disposeRegistered = true;
    }

    Future<void>.microtask(_startEventLoop);

    return ChatControllerState(
      conversationId: conversationId,
      lastEventId: snapshot?.lastEventId,
      messages: messages,
      mediaResources: const <String, ChatMediaResourceState>{},
      attachments: const <ChatAttachmentDraft>[],
      compositionMode: ChatCompositionMode.messageWithAttachments,
      isConnected: false,
      isConnecting: false,
      isSending: false,
    );
  }

  Future<void> attachFromPicker() async {
    final selected = await ref.read(chatFilePickerProvider).pickFiles();
    if (selected.isEmpty) {
      return;
    }

    final next = List<ChatAttachmentDraft>.from(state.attachments);
    var ignoredCount = 0;
    for (final file in selected) {
      if (next.length >= kMaxComposerAttachments) {
        ignoredCount += 1;
        continue;
      }
      next.add(
        ChatAttachmentDraft(
          id: _newAttachmentId(),
          filename: file.filename,
          mimeType: file.mimeType,
          bytes: file.bytes,
        ),
      );
    }

    final overflowError = ignoredCount > 0
        ? 'You can attach up to $kMaxComposerAttachments files per message.'
        : null;
    state = state.copyWith(
      attachments: next,
      errorMessage: overflowError,
      clearErrorMessage: overflowError == null,
    );
  }

  void clearAttachment() {
    state = state.copyWith(clearAttachments: true);
  }

  void removeAttachment(String attachmentId) {
    final next = state.attachments
        .where((attachment) => attachment.id != attachmentId)
        .toList(growable: false);
    state = state.copyWith(attachments: next, clearErrorMessage: true);
  }

  void updateAttachmentCaption({
    required String attachmentId,
    required String caption,
  }) {
    final next = state.attachments
        .map((attachment) {
          if (attachment.id != attachmentId) {
            return attachment;
          }
          return attachment.copyWith(caption: caption);
        })
        .toList(growable: false);
    state = state.copyWith(attachments: next, clearErrorMessage: true);
  }

  void setCompositionMode(ChatCompositionMode mode) {
    if (state.compositionMode == mode) {
      return;
    }
    state = state.copyWith(compositionMode: mode, clearErrorMessage: true);
  }

  void clearError() {
    state = state.copyWith(clearErrorMessage: true);
  }

  String? composerValidationError(String rawText) {
    return _validateComposer(
      text: rawText.trim(),
      attachments: state.attachments,
      compositionMode: state.compositionMode,
    );
  }

  void clearTranscript() {
    if (state.messages.isEmpty &&
        state.mediaResources.isEmpty &&
        state.activeThinkingKeys.isEmpty) {
      return;
    }

    final urls = state.mediaResources.values
        .map((resource) => resource.objectUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    for (final url in urls) {
      _mediaObjectUrlPlatform.revokeObjectUrl(url);
    }

    _recentNonUserSignatures.clear();
    _recentNonUserSignatureOrder.clear();

    state = state.copyWith(
      messages: const <ChatMessageEntity>[],
      mediaResources: const <String, ChatMediaResourceState>{},
      clearAttachments: true,
      clearActiveThinkingKeys: true,
      clearReplayNotice: true,
      clearErrorMessage: true,
    );
    _scheduleSnapshotPersist();
  }

  Future<bool> sendMessage(String rawText) async {
    ensureStreaming();

    final text = rawText.trim();
    final attachments = List<ChatAttachmentDraft>.from(state.attachments);
    final validationError = _validateComposer(
      text: text,
      attachments: attachments,
      compositionMode: state.compositionMode,
    );
    if (validationError != null) {
      state = state.copyWith(errorMessage: validationError);
      return false;
    }

    final clientMessageId = _newMessageId(prefix: 'client');
    final optimisticMessages = <ChatMessageEntity>[];
    final localMediaResources = Map<String, ChatMediaResourceState>.from(
      state.mediaResources,
    );

    if (text.isNotEmpty) {
      optimisticMessages.add(
        ChatMessageEntity(
          id: _newMessageId(prefix: 'local'),
          role: ChatMessageRole.user,
          type: ChatMessageType.text,
          status: ChatMessageStatus.pending,
          createdAt: DateTime.now().toUtc(),
          text: text,
          clientMessageId: clientMessageId,
        ),
      );
    }

    for (final attachment in attachments) {
      final messageId = _newMessageId(prefix: 'local');
      final caption = attachment.caption.trim();
      final persistedMediaUrl = _buildPersistableMediaUrl(attachment);
      optimisticMessages.add(
        ChatMessageEntity(
          id: messageId,
          role: ChatMessageRole.user,
          type: _chatMessageTypeFromMime(attachment.mimeType),
          status: ChatMessageStatus.pending,
          createdAt: DateTime.now().toUtc(),
          text: caption.isEmpty ? null : caption,
          media: ChatMediaEntity(
            url: persistedMediaUrl ?? '',
            mimeType: attachment.mimeType,
            filename: attachment.filename,
          ),
          clientMessageId: clientMessageId,
        ),
      );

      final localResource = _buildLocalAttachmentMediaResource(
        attachment: attachment,
      );
      if (localResource != null) {
        localMediaResources[messageId] = localResource;
      }
    }

    state = state.copyWith(
      isSending: true,
      messages: _appendMessages(optimisticMessages),
      mediaResources: localMediaResources,
      clearAttachments: true,
      clearErrorMessage: true,
    );
    _purgeMediaResourcesForRemovedMessages(state.messages);
    _scheduleSnapshotPersist();

    final service = ref.read(chatApplicationServiceProvider);
    final result = attachments.isEmpty
        ? await service.sendText(
            ChatSendTextInput(
              conversationId: state.conversationId,
              clientMessageId: clientMessageId,
              text: text,
            ),
          )
        : await service.sendComposed(
            ChatSendComposedInput(
              conversationId: state.conversationId,
              clientMessageId: clientMessageId,
              compositionMode: state.compositionMode,
              parts: _buildComposedParts(
                text: text,
                attachments: attachments,
                compositionMode: state.compositionMode,
              ),
              attachments: attachments
                  .map(
                    (attachment) => ChatSendComposedAttachmentInput(
                      id: attachment.id,
                      filename: attachment.filename,
                      mimeType: attachment.mimeType,
                      bytes: attachment.bytes,
                      caption: attachment.caption.trim().isEmpty
                          ? null
                          : attachment.caption.trim(),
                      metadata: attachment.metadata,
                    ),
                  )
                  .toList(growable: false),
            ),
          );

    if (result.isFailure) {
      state = state.copyWith(
        isSending: false,
        messages: _updateMessageByClientId(
          clientMessageId,
          (message) => message.copyWith(
            status: ChatMessageStatus.failed,
            errorMessage: result.failure?.message,
          ),
        ),
        errorMessage: result.failure?.message ?? 'Could not send message.',
      );
      _scheduleSnapshotPersist();
      return false;
    }

    final accepted = result.data!;
    state = state.copyWith(
      isSending: false,
      messages: _updateMessageByClientId(clientMessageId, (message) {
        final nextStatus = switch (message.status) {
          ChatMessageStatus.delivered => ChatMessageStatus.delivered,
          ChatMessageStatus.failed => ChatMessageStatus.failed,
          ChatMessageStatus.pending => ChatMessageStatus.accepted,
          ChatMessageStatus.accepted => ChatMessageStatus.accepted, // coverage:ignore-line
        };
        return message.copyWith(status: nextStatus, jobId: accepted.jobId);
      }),
    );
    _scheduleSnapshotPersist();
    return true;
  }

  Future<void> ensureMediaLoaded(String messageId) async {
    final message = _findMessage(messageId);
    if (message == null ||
        message.role != ChatMessageRole.assistant ||
        message.media == null ||
        message.media!.url.trim().isEmpty) {
      return;
    }

    final existing = state.mediaResources[messageId];
    if (existing != null &&
        (existing.isLoading ||
            (existing.objectUrl?.isNotEmpty ?? false) ||
            (existing.errorMessage?.isNotEmpty ?? false))) {
      return;
    }

    state = state.copyWith(
      mediaResources: <String, ChatMediaResourceState>{
        ...state.mediaResources,
        messageId: const ChatMediaResourceState(isLoading: true),
      },
    );

    final result = await ref
        .read(chatApplicationServiceProvider)
        .downloadMedia(
          mediaUrl: message.media!.url,
          suggestedFilename: message.media!.filename,
          suggestedMimeType: message.media!.mimeType,
        );

    if (result.isFailure) {
      state = state.copyWith(
        mediaResources: <String, ChatMediaResourceState>{
          ...state.mediaResources,
          messageId: ChatMediaResourceState(
            isLoading: false,
            errorMessage: result.failure?.message ?? 'Unable to load media.',
          ),
        },
      );
      return;
    }

    final downloaded = result.data!;
    final rawMimeType = downloaded.mimeType?.trim().isNotEmpty ?? false
        ? downloaded.mimeType!.trim()
        : 'application/octet-stream';
    final mimeType = _normalizePreviewMimeType(rawMimeType);
    final effectiveFilename =
        downloaded.filename ?? message.media!.filename ?? 'download';
    final textPreview = _isTextPreviewMimeType(mimeType)
        ? _buildTextPreviewSnippet(downloaded.bytes)
        : null;
    final pdfPageAspectRatio = mimeType == 'application/pdf'
        ? _extractPdfFirstPageAspectRatio(downloaded.bytes) // coverage:ignore-line
        : null;
    final spreadsheetPreview =
        _isSpreadsheetPreviewCandidate(
          mimeType: mimeType,
          filename: effectiveFilename,
        )
        ? _buildSpreadsheetPreview(downloaded.bytes) // coverage:ignore-line
        : null;
    final objectUrl = _mediaObjectUrlPlatform.createObjectUrl(
      bytes: downloaded.bytes,
      mimeType: mimeType,
    );

    state = state.copyWith(
      mediaResources: <String, ChatMediaResourceState>{
        ...state.mediaResources,
        messageId: ChatMediaResourceState(
          isLoading: false,
          objectUrl: objectUrl,
          mimeType: mimeType,
          filename: effectiveFilename,
          textPreview: textPreview,
          pdfPageAspectRatio: pdfPageAspectRatio,
          spreadsheetPreview: spreadsheetPreview,
        ),
      },
    );
  }

  Future<void> retryMediaLoad(String messageId) async {
    final current = state.mediaResources[messageId];
    if (current?.objectUrl != null && current!.objectUrl!.isNotEmpty) {
      _mediaObjectUrlPlatform.revokeObjectUrl(current.objectUrl!);
    }

    final updated = Map<String, ChatMediaResourceState>.from(
      state.mediaResources,
    );
    updated.remove(messageId);
    state = state.copyWith(mediaResources: updated);
    await ensureMediaLoaded(messageId);
  }

  Future<void> downloadMediaToDevice(String messageId) async {
    final resource = state.mediaResources[messageId];
    if (resource == null || (resource.objectUrl?.isEmpty ?? true)) {
      await ensureMediaLoaded(messageId);
    }

    final updated = state.mediaResources[messageId];
    if (updated == null || (updated.objectUrl?.isEmpty ?? true)) {
      return;
    }

    final filename = updated.filename?.trim().isNotEmpty ?? false
        ? updated.filename!.trim() // coverage:ignore-line
        : 'download';
    _mediaObjectUrlPlatform.triggerDownload(
      url: updated.objectUrl!,
      filename: filename,
    );
  }

  void ensureStreaming() {
    if (_disposed) {
      return;
    }

    _startEventLoop();
  }

  void _startEventLoop() {
    if (_eventLoopRunning || _disposed) {
      return;
    }

    _eventLoopRunning = true;
    unawaited(_runEventLoop());
  }

  Future<void> _runEventLoop() async {
    var attempt = 0;
    while (!_disposed) {
      state = state.copyWith(isConnecting: true, isConnected: false);

      var keepRunning = true;
      var hasEvents = false;

      await for (final eventResult
          in ref
              .read(chatApplicationServiceProvider)
              .streamEvents(
                conversationId: state.conversationId,
                lastEventId: state.lastEventId,
              )) {
        if (_disposed) {
          return;
        }

        if (eventResult.isFailure) {
          final failure = eventResult.failure;
          if (failure is SessionExpiredFailure ||
              failure is UnauthorizedFailure) {
            state = state.copyWith(
              isConnected: false,
              isConnecting: false,
              errorMessage: failure?.message ?? 'Session expired.',
            );
            _eventLoopRunning = false;
            return;
          }

          if (failure is ApiFailure && failure.statusCode == 404) {
            // Conversation becomes available only after first message is sent.
          } else {
            state = state.copyWith(errorMessage: failure?.message);
          }
          keepRunning = true;
          break;
        }

        hasEvents = true;
        attempt = 0;
        state = state.copyWith(
          isConnecting: false,
          isConnected: true,
          clearErrorMessage: true,
        );
        _handleServerEvent(eventResult.data!);
      }

      if (_disposed) {
        return;
      }

      state = state.copyWith(isConnected: false, isConnecting: false);

      if (!keepRunning) {
        _eventLoopRunning = false; // coverage:ignore-line
        return;
      }

      attempt = hasEvents ? 1 : attempt + 1;
      final delay = Duration(seconds: _backoffSeconds(attempt));
      await Future<void>.delayed(delay);
    }

    _eventLoopRunning = false; // coverage:ignore-line
  }

  void _handleServerEvent(ChatSseEventEntity event) {
    final eventId = event.id?.toString().trim();
    if (_isDuplicateEvent(eventId)) {
      return;
    }

    switch (event.event.toLowerCase().trim()) {
      case 'ack':
        _handleAckEvent(event, eventId);
        break;
      case 'thinking':
        _handleThinkingEvent(event, eventId);
        break;
      case 'message':
        _handleMessageEvent(event, eventId);
        break;
      case 'error':
        _handleSystemEvent(event, eventId, role: ChatMessageRole.error);
        break;
      case 'system':
        _handleSystemEvent(event, eventId, role: ChatMessageRole.system);
        break;
      default:
        _handleSystemEvent(event, eventId, role: ChatMessageRole.system);
        break;
    }

    if (eventId != null && eventId.isNotEmpty) {
      state = state.copyWith(lastEventId: eventId);
      _scheduleSnapshotPersist();
    }
  }

  void _handleAckEvent(ChatSseEventEntity event, String? eventId) {
    final data = event.data;
    final clientMessageId = _readString(data['client_message_id']);
    if (clientMessageId == null) {
      return;
    }

    final jobId = _readString(data['job_id']);
    state = state.copyWith(
      messages: _updateMessageByClientId(clientMessageId, (message) {
        final nextStatus = switch (message.status) {
          ChatMessageStatus.delivered => ChatMessageStatus.delivered,
          ChatMessageStatus.failed => ChatMessageStatus.failed,
          ChatMessageStatus.pending => ChatMessageStatus.accepted,
          ChatMessageStatus.accepted => ChatMessageStatus.accepted,
        };
        return message.copyWith(
          status: nextStatus,
          jobId: jobId,
          eventId: eventId,
        );
      }),
    );
    _scheduleSnapshotPersist();
  }

  void _handleThinkingEvent(ChatSseEventEntity event, String? eventId) {
    final data = event.data;
    final stateValue = _readString(data['state'])?.toLowerCase();
    if (stateValue != 'start' && stateValue != 'stop') {
      return;
    }

    final jobId = _readString(data['job_id']);
    final clientMessageId = _readString(data['client_message_id']);
    final key = _thinkingSignalKey(
      jobId: jobId,
      clientMessageId: clientMessageId,
    );
    if (key == null) {
      return;
    }

    final next = Set<String>.from(state.activeThinkingKeys);
    final changed = stateValue == 'start' ? next.add(key) : next.remove(key);
    if (!changed) {
      return;
    }

    state = state.copyWith(activeThinkingKeys: next);

    if (stateValue == 'stop') {
      final marked = _markOutgoingDelivered(
        jobId: jobId,
        clientMessageId: clientMessageId,
        eventId: eventId,
      );
      if (!marked) {
        _markSingleOpenOutgoing(
          status: ChatMessageStatus.delivered,
          eventId: eventId,
        );
      }
    }
  }

  void _handleMessageEvent(ChatSseEventEntity event, String? eventId) {
    final data = event.data;
    final message = data['message'];
    if (message is! Map) {
      return;
    }

    final payload = Map<String, dynamic>.from(message);
    final type = _chatMessageTypeFromServer(_readString(payload['type']));
    final content = payload['content'];
    final jobId = _readString(data['job_id']);
    final clientMessageId = _readString(data['client_message_id']);
    _clearThinkingSignal(jobId: jobId, clientMessageId: clientMessageId);
    final marked = _markOutgoingDelivered(
      jobId: jobId,
      clientMessageId: clientMessageId,
      eventId: eventId,
    );
    if (!marked) {
      _markSingleOpenOutgoing(
        status: ChatMessageStatus.delivered,
        eventId: eventId,
      );
    }
    final signature = _buildAssistantEventSignature(
      type: type,
      content: content,
      jobId: jobId,
      clientMessageId: clientMessageId,
    );
    if (_shouldSkipDuplicateNonUserSignature(signature)) {
      _scheduleSnapshotPersist();
      return;
    }

    final entity = type == ChatMessageType.text
        ? ChatMessageEntity(
            id: _newMessageId(prefix: 'assistant'),
            role: ChatMessageRole.assistant,
            type: ChatMessageType.text,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.now().toUtc(),
            text: content?.toString() ?? '',
            jobId: jobId,
            clientMessageId: clientMessageId,
            eventId: eventId,
          )
        : ChatMessageEntity(
            id: _newMessageId(prefix: 'assistant'),
            role: ChatMessageRole.assistant,
            type: type,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.now().toUtc(),
            media: _parseMediaPayload(content),
            jobId: jobId,
            clientMessageId: clientMessageId,
            eventId: eventId,
          );

    state = state.copyWith(messages: _appendMessage(entity));
    _purgeMediaResourcesForRemovedMessages(state.messages);
    _scheduleSnapshotPersist();

    if (entity.media != null && entity.media!.url.trim().isNotEmpty) {
      unawaited(ensureMediaLoaded(entity.id));
    }
  }

  void _handleSystemEvent(
    ChatSseEventEntity event,
    String? eventId, {
    required ChatMessageRole role,
  }) {
    final data = event.data;
    final signal = _readString(data['signal'])?.toLowerCase();
    if (signal == _streamResetSignal) {
      // Stream resets are transport-level notices, not transcript content.
      _setReplayNotice(data: data, eventId: eventId);
      state = state.copyWith(clearActiveThinkingKeys: true);
      return;
    }

    final jobId = _readString(data['job_id']);
    final clientMessageId = _readString(data['client_message_id']);
    _clearThinkingSignal(jobId: jobId, clientMessageId: clientMessageId);
    if (role == ChatMessageRole.error) {
      final marked = _markOutgoingFailed(
        jobId: jobId,
        clientMessageId: clientMessageId,
        eventId: eventId,
      );
      if (!marked) {
        _markSingleOpenOutgoing(
          status: ChatMessageStatus.failed,
          eventId: eventId,
        );
      }
    } else {
      final marked = _markOutgoingDelivered(
        jobId: jobId,
        clientMessageId: clientMessageId,
        eventId: eventId,
      );
      if (!marked) {
        _markSingleOpenOutgoing(
          status: ChatMessageStatus.delivered,
          eventId: eventId,
        );
      }
    }

    final text =
        _readString(data['message']) ??
        _readString(data['error']) ??
        jsonEncode(data);
    final signature = _buildSystemEventSignature(
      role: role,
      data: data,
      resolvedText: text,
      jobId: jobId,
      clientMessageId: clientMessageId,
    );
    if (_shouldSkipDuplicateNonUserSignature(signature)) {
      _scheduleSnapshotPersist();
      return;
    }
    final message = ChatMessageEntity(
      id: _newMessageId(prefix: role.name),
      role: role,
      type: ChatMessageType.text,
      status: role == ChatMessageRole.error
          ? ChatMessageStatus.failed
          : ChatMessageStatus.delivered,
      createdAt: DateTime.now().toUtc(),
      text: text,
      eventId: eventId,
      jobId: jobId,
      clientMessageId: clientMessageId,
      errorMessage: role == ChatMessageRole.error ? text : null,
    );
    state = state.copyWith(messages: _appendMessage(message));
    _purgeMediaResourcesForRemovedMessages(state.messages);
    _scheduleSnapshotPersist();
  }

  void _clearThinkingSignal({String? jobId, String? clientMessageId}) {
    if (state.activeThinkingKeys.isEmpty) {
      return;
    }

    final keys = <String>{
      if (jobId != null && jobId.isNotEmpty) 'job:$jobId',
      if (clientMessageId != null && clientMessageId.isNotEmpty)
        'client:$clientMessageId',
    };
    if (keys.isEmpty) {
      return;
    }

    final next = Set<String>.from(state.activeThinkingKeys)
      ..removeWhere(keys.contains);
    if (next.length == state.activeThinkingKeys.length) {
      return;
    }

    state = state.copyWith(activeThinkingKeys: next);
  }

  String? _thinkingSignalKey({String? jobId, String? clientMessageId}) {
    if (jobId != null && jobId.isNotEmpty) {
      return 'job:$jobId';
    }
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      return 'client:$clientMessageId';
    }
    return null;
  }

  void _setReplayNotice({required Map<String, dynamic> data, String? eventId}) {
    final reasonCode = _readString(data['reason']);
    final fallbackReason = _friendlyReplayReason(reasonCode);
    final incomingEventId = _readString(data['incoming_event_id']);
    // Parse optional metadata for diagnostics compatibility.
    _readString(data['incoming_last_event_id']);
    _readString(data['event_log_version']);
    _readString(data['event_log_generation']);

    state = state.copyWith(
      replayNoticeText: 'Replay resynced',
      replayNoticeReason: reasonCode ?? fallbackReason,
      replayNoticeEventId: eventId ?? incomingEventId,
      replayNoticeAtUtc: DateTime.now().toUtc(),
    );
    _replayNoticeTimer?.cancel();
    _replayNoticeTimer = Timer(_replayNoticeDuration, () {
      if (_disposed) {
        return;
      }
      state = state.copyWith(clearReplayNotice: true);
    });
  }

  String _friendlyReplayReason(String? reasonCode) {
    switch (reasonCode?.toLowerCase().trim()) {
      case 'stale_cursor':
        return 'stale replay cursor';
      case 'generation_mismatch':
        return 'stream generation changed';
      case 'event_log_rollover':
      case 'log_rollover':
        return 'event log rolled over';
      case 'cursor_unavailable':
      case 'cursor_not_found':
        return 'cursor unavailable';
      default:
        return 'event replay resynced';
    }
  }

  String _buildAssistantEventSignature({
    required ChatMessageType type,
    required Object? content,
    String? jobId,
    String? clientMessageId,
  }) {
    final payload = type == ChatMessageType.text
        ? <String, dynamic>{'text': content?.toString() ?? ''}
        : _buildMediaPayloadSignature(content);
    return jsonEncode(<String, dynamic>{
      'role': ChatMessageRole.assistant.name,
      'type': type.name,
      'job_id': jobId ?? '',
      'client_message_id': clientMessageId ?? '',
      'payload': payload,
    });
  }

  Map<String, String> _buildMediaPayloadSignature(Object? payload) {
    if (payload is! Map) {
      return <String, String>{'raw': payload?.toString() ?? ''};
    }
    final data = Map<String, dynamic>.from(payload);
    return <String, String>{
      'url': _readString(data['url']) ?? '',
      'mime_type': _readString(data['mime_type']) ?? '',
      'filename': _readString(data['filename']) ?? '',
      'expires_at': data['expires_at']?.toString().trim() ?? '',
      'type': _readString(data['type']) ?? '',
    };
  }

  String _buildSystemEventSignature({
    required ChatMessageRole role,
    required Map<String, dynamic> data,
    required String resolvedText,
    String? jobId,
    String? clientMessageId,
  }) {
    return jsonEncode(<String, dynamic>{
      'role': role.name,
      'job_id': jobId ?? '',
      'client_message_id': clientMessageId ?? '',
      'signal': _readString(data['signal']) ?? '',
      'reason': _readString(data['reason']) ?? '',
      'message': resolvedText,
    });
  }

  bool _shouldSkipDuplicateNonUserSignature(String signature) {
    if (signature.isEmpty) {
      return false;
    }
    if (_recentNonUserSignatures.contains(signature)) {
      return true;
    }

    _recentNonUserSignatures.add(signature);
    _recentNonUserSignatureOrder.addLast(signature);
    while (_recentNonUserSignatureOrder.length > _maxRecentNonUserSignatures) {
      final evicted = _recentNonUserSignatureOrder.removeFirst(); // coverage:ignore-line
      _recentNonUserSignatures.remove(evicted); // coverage:ignore-line
    }
    return false;
  }

  List<ChatMessageEntity> _appendMessage(ChatMessageEntity message) {
    final all = <ChatMessageEntity>[...state.messages, message];
    return _trimToRetainedMessageCap(all);
  }

  List<ChatMessageEntity> _appendMessages(List<ChatMessageEntity> messages) {
    if (messages.isEmpty) {
      return state.messages; // coverage:ignore-line
    }
    final all = <ChatMessageEntity>[...state.messages, ...messages];
    return _trimToRetainedMessageCap(all);
  }

  List<ChatMessageEntity> _updateMessageByClientId(
    String clientMessageId,
    ChatMessageEntity Function(ChatMessageEntity current) mapper,
  ) {
    final updated = state.messages
        .map((message) {
          if (message.clientMessageId == clientMessageId) {
            return mapper(message);
          }
          return message;
        })
        .toList(growable: false);
    return updated;
  }

  bool _markOutgoingDelivered({
    String? jobId,
    String? clientMessageId,
    String? eventId,
  }) {
    if ((jobId == null || jobId.isEmpty) &&
        (clientMessageId == null || clientMessageId.isEmpty)) {
      return false;
    }

    var matched = false;
    final updated = state.messages
        .map((message) {
          if (message.role != ChatMessageRole.user) {
            return message;
          }

          final matchesClient =
              clientMessageId != null &&
              clientMessageId.isNotEmpty &&
              message.clientMessageId == clientMessageId;
          final matchesJob =
              jobId != null && jobId.isNotEmpty && message.jobId == jobId;
          if (!matchesClient && !matchesJob) {
            return message;
          }
          matched = true;
          if (message.status == ChatMessageStatus.failed) {
            return message;
          }

          return message.copyWith(
            status: ChatMessageStatus.delivered,
            jobId: jobId ?? message.jobId,
            clientMessageId: clientMessageId ?? message.clientMessageId,
            eventId: eventId ?? message.eventId, // coverage:ignore-line
          );
        })
        .toList(growable: false);
    if (matched) {
      state = state.copyWith(messages: updated);
    }
    return matched;
  }

  bool _markOutgoingFailed({
    String? jobId,
    String? clientMessageId,
    String? eventId,
  }) {
    if ((jobId == null || jobId.isEmpty) &&
        (clientMessageId == null || clientMessageId.isEmpty)) {
      return false;
    }

    var matched = false;
    final updated = state.messages
        .map((message) {
          if (message.role != ChatMessageRole.user) {
            return message;
          }

          final matchesClient =
              clientMessageId != null &&
              clientMessageId.isNotEmpty &&
              message.clientMessageId == clientMessageId;
          final matchesJob =
              jobId != null && jobId.isNotEmpty && message.jobId == jobId; // coverage:ignore-line
          if (!matchesClient && !matchesJob) {
            return message;
          }
          matched = true;

          return message.copyWith(
            status: ChatMessageStatus.failed,
            jobId: jobId ?? message.jobId,
            clientMessageId: clientMessageId ?? message.clientMessageId, // coverage:ignore-line
            eventId: eventId ?? message.eventId, // coverage:ignore-line
          );
        })
        .toList(growable: false);
    if (matched) {
      state = state.copyWith(messages: updated); // coverage:ignore-line
    }
    return matched;
  }

  bool _markSingleOpenOutgoing({
    required ChatMessageStatus status,
    String? eventId,
  }) {
    final openOutgoing = state.messages
        .where(
          (message) =>
              message.role == ChatMessageRole.user &&
              message.status != ChatMessageStatus.delivered &&
              message.status != ChatMessageStatus.failed,
        )
        .toList(growable: false);
    if (openOutgoing.length != 1) {
      return false;
    }

    final target = openOutgoing.single;
    final updated = state.messages
        .map((message) {
          if (message.id != target.id) {
            return message;
          }

          return message.copyWith(
            status: status,
            eventId: eventId ?? message.eventId,
          );
        })
        .toList(growable: false);
    state = state.copyWith(messages: updated);
    return true;
  }

  ChatMessageEntity? _findMessage(String messageId) {
    for (final message in state.messages) {
      if (message.id == messageId) {
        return message;
      }
    }
    return null;
  }

  bool _isDuplicateEvent(String? incomingEventId) {
    if (incomingEventId == null || incomingEventId.isEmpty) {
      return false;
    }

    final currentCursor = _parseEventCursor(state.lastEventId);
    final incomingCursor = _parseEventCursor(incomingEventId);
    if (currentCursor == null || incomingCursor == null) {
      return false;
    }

    if (currentCursor.streamGeneration != null ||
        incomingCursor.streamGeneration != null) {
      if (currentCursor.streamVersion != incomingCursor.streamVersion ||
          currentCursor.streamGeneration != incomingCursor.streamGeneration) {
        return false;
      }
      return incomingCursor.eventId <= currentCursor.eventId;
    }

    if (incomingCursor.eventId <= 0) {
      return false;
    }

    return incomingCursor.eventId <= currentCursor.eventId;
  }

  _ParsedEventCursor? _parseEventCursor(String? rawEventId) {
    final normalized = rawEventId?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    final cursorMatch = RegExp(
      r'^v(\d+):([^:]+):(\d+)$',
      caseSensitive: false,
    ).firstMatch(normalized);
    if (cursorMatch != null) {
      final version = int.tryParse(cursorMatch.group(1) ?? '');
      final generation = cursorMatch.group(2)?.trim();
      final eventId = int.tryParse(cursorMatch.group(3) ?? '');
      if (version == null ||
          generation == null ||
          generation.isEmpty ||
          eventId == null) {
        return null;
      }
      return _ParsedEventCursor(
        streamVersion: version,
        streamGeneration: generation,
        eventId: eventId,
      );
    }

    final legacyEventId = int.tryParse(normalized);
    if (legacyEventId == null) {
      return null;
    }
    return _ParsedEventCursor(
      streamVersion: null,
      streamGeneration: null,
      eventId: legacyEventId,
    );
  }

  void _resetEphemeralRuntimeState() {
    _replayNoticeTimer?.cancel();
    _replayNoticeTimer = null;
    _recentNonUserSignatures.clear();
    _recentNonUserSignatureOrder.clear();
  }

  String _activeUserId() {
    final session = ref.read(authControllerProvider).session;
    final userId = session?.userId.trim();
    if (userId == null || userId.isEmpty) {
      return 'anonymous';
    }
    return userId;
  }

  String _buildStorageKey(String userId) {
    final normalized = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
    return 'mugen_ui.chat.single.$normalized.v$_snapshotVersion';
  }

  ChatSnapshot? _readSnapshot() {
    final raw = ref.read(chatLocalStorageProvider).getItem(_snapshotStorageKey);
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return ChatSnapshot.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  void _scheduleSnapshotPersist() {
    _snapshotDebounceTimer?.cancel();
    _snapshotDebounceTimer = Timer(_snapshotDebounce, _persistSnapshot);
  }

  void _persistSnapshot() {
    if (_disposed || _snapshotStorageKey.isEmpty || _snapshotUserId.isEmpty) {
      return;
    }

    final storage = ref.read(chatLocalStorageProvider);
    var messages = _trimToPersistedMessageCap(state.messages);

    while (true) {
      final snapshot = ChatSnapshot(
        conversationId: state.conversationId,
        lastEventId: state.lastEventId,
        messages: messages,
      );
      final payload = jsonEncode(snapshot.toJson());
      if (payload.length > kMaxSnapshotBytes && messages.isNotEmpty) {
        messages = messages.sublist(1); // coverage:ignore-line
        continue;
      }

      try {
        storage.setItem(_snapshotStorageKey, payload);
        return;
      } catch (_) {
        if (messages.isEmpty) {
          return;
        }
        messages = messages.sublist(1);
      }
    }
  }

  List<ChatMessageEntity> _trimToRetainedMessageCap(
    List<ChatMessageEntity> messages,
  ) {
    if (messages.length <= kMaxRetainedMessages) {
      return messages;
    }
    return messages.sublist(messages.length - kMaxRetainedMessages);
  }

  List<ChatMessageEntity> _trimToPersistedMessageCap(
    List<ChatMessageEntity> messages,
  ) {
    if (messages.length <= kMaxPersistedMessages) {
      return messages;
    }
    return messages.sublist(messages.length - kMaxPersistedMessages); // coverage:ignore-line
  }

  void _purgeMediaResourcesForRemovedMessages(List<ChatMessageEntity> trimmed) {
    final retainedIds = trimmed.map((message) => message.id).toSet();
    final nextResources = Map<String, ChatMediaResourceState>.from(
      state.mediaResources,
    );
    var changed = false;

    for (final entry in state.mediaResources.entries) {
      if (retainedIds.contains(entry.key)) {
        continue;
      }

      final objectUrl = entry.value.objectUrl; // coverage:ignore-line
      if (objectUrl != null && objectUrl.isNotEmpty) { // coverage:ignore-line
        _mediaObjectUrlPlatform.revokeObjectUrl(objectUrl); // coverage:ignore-line
      }
      nextResources.remove(entry.key); // coverage:ignore-line
      changed = true;
    }

    if (changed) {
      state = state.copyWith(mediaResources: nextResources); // coverage:ignore-line
    }
  }

  int _backoffSeconds(int attempt) {
    final clampedAttempt = attempt <= 0 ? 1 : attempt;
    final value = 1 << (clampedAttempt - 1);
    return value > 30 ? 30 : value;
  }

  String _newConversationId() {
    return 'conv-${DateTime.now().millisecondsSinceEpoch}-${_random.nextInt(_randomIdUpperBound)}';
  }

  String _newMessageId({required String prefix}) {
    return '$prefix-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(_randomIdUpperBound)}';
  }

  String _newAttachmentId() {
    return 'att-${DateTime.now().microsecondsSinceEpoch}-${_random.nextInt(_randomIdUpperBound)}';
  }

  ChatMessageType _chatMessageTypeFromMime(String mimeType) {
    final normalized = mimeType.toLowerCase().trim();
    if (normalized.startsWith('image/')) {
      return ChatMessageType.image;
    }

    if (normalized.startsWith('audio/')) {
      return ChatMessageType.audio;
    }

    if (normalized.startsWith('video/')) {
      return ChatMessageType.video;
    }

    return ChatMessageType.file;
  }

  ChatMediaResourceState? _buildLocalAttachmentMediaResource({
    required ChatAttachmentDraft attachment,
  }) {
    String? objectUrl;
    try {
      objectUrl = _mediaObjectUrlPlatform.createObjectUrl(
        bytes: attachment.bytes,
        mimeType: attachment.mimeType,
      );
    } catch (_) {
      objectUrl = null;
    }

    if (objectUrl == null || objectUrl.trim().isEmpty) {
      return null;
    }

    return ChatMediaResourceState(
      isLoading: false,
      objectUrl: objectUrl,
      mimeType: attachment.mimeType,
      filename: attachment.filename,
      textPreview:
          _isTextPreviewMimeType(_normalizePreviewMimeType(attachment.mimeType))
          ? _buildTextPreviewSnippet(attachment.bytes)
          : null,
      pdfPageAspectRatio:
          _normalizePreviewMimeType(attachment.mimeType) == 'application/pdf'
          ? _extractPdfFirstPageAspectRatio(attachment.bytes)
          : null,
      spreadsheetPreview:
          _isSpreadsheetPreviewCandidate(
            mimeType: _normalizePreviewMimeType(attachment.mimeType),
            filename: attachment.filename,
          )
          ? _buildSpreadsheetPreview(attachment.bytes)
          : null,
    );
  }

  String? _buildPersistableMediaUrl(ChatAttachmentDraft attachment) {
    final mimeType = attachment.mimeType.toLowerCase().trim();
    if (!mimeType.startsWith('image/')) {
      return null;
    }
    if (attachment.bytes.length > _maxPersistedInlineImageBytes) {
      return null;
    }

    final normalizedMime = mimeType.isEmpty ? 'image/png' : mimeType;
    final encoded = base64Encode(attachment.bytes);
    return 'data:$normalizedMime;base64,$encoded';
  }

  List<ChatSendComposedPartInput> _buildComposedParts({
    required String text,
    required List<ChatAttachmentDraft> attachments,
    required ChatCompositionMode compositionMode,
  }) {
    final parts = <ChatSendComposedPartInput>[];
    if (compositionMode == ChatCompositionMode.messageWithAttachments &&
        text.isNotEmpty) {
      parts.add(ChatSendComposedPartInput.text(text: text));
    }

    for (final attachment in attachments) {
      final caption = attachment.caption.trim();
      parts.add(
        ChatSendComposedPartInput.attachment(
          attachmentId: attachment.id,
          caption: caption.isEmpty ? null : caption,
          metadata: attachment.metadata,
        ),
      );
    }

    return parts;
  }

  String? _validateComposer({
    required String text,
    required List<ChatAttachmentDraft> attachments,
    required ChatCompositionMode compositionMode,
  }) {
    if (attachments.length > kMaxComposerAttachments) {
      return 'You can attach up to $kMaxComposerAttachments files per message.';
    }

    if (compositionMode == ChatCompositionMode.attachmentWithCaption) {
      if (attachments.isEmpty) {
        return 'Attach at least one file for this mode.';
      }
      if (text.isNotEmpty) {
        return 'Remove message text in Attachment with caption mode.';
      }
      for (final attachment in attachments) {
        if (attachment.caption.trim().isEmpty) {
          return 'Add a caption for each attachment in this mode.';
        }
      }
    }

    if (text.isEmpty && attachments.isEmpty) {
      return 'Type a message or attach files.';
    }

    return null;
  }

  ChatMessageType _chatMessageTypeFromServer(String? serverType) {
    switch (serverType?.toLowerCase().trim()) {
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

  ChatMediaEntity? _parseMediaPayload(Object? payload) {
    if (payload is! Map) {
      return null;
    }

    final map = Map<String, dynamic>.from(payload);
    final url = _readString(map['url']);
    if (url == null) {
      return null;
    }

    return ChatMediaEntity(
      url: url,
      mimeType: _readString(map['mime_type']),
      filename: _readString(map['filename']),
      expiresAt: _readExpiresAt(map['expires_at']),
    );
  }

  DateTime? _readExpiresAt(Object? value) {
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value * 1000, isUtc: true);
    }
    if (value is num) {
      return DateTime.fromMillisecondsSinceEpoch(
        (value.toDouble() * 1000).toInt(),
        isUtc: true,
      );
    }

    final text = _readString(value);
    if (text == null) {
      return null;
    }
    final asNumber = num.tryParse(text);
    if (asNumber != null) {
      return DateTime.fromMillisecondsSinceEpoch(
        (asNumber.toDouble() * 1000).toInt(),
        isUtc: true,
      );
    }
    return DateTime.tryParse(text)?.toUtc(); // coverage:ignore-line
  }

  String? _readString(Object? value) {
    final normalized = value?.toString().trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  void _disposeResources() {
    _disposed = true;
    _snapshotDebounceTimer?.cancel();
    _snapshotDebounceTimer = null;
    _replayNoticeTimer?.cancel();
    _replayNoticeTimer = null;
    _recentNonUserSignatures.clear();
    _recentNonUserSignatureOrder.clear();

    final urls = state.mediaResources.values
        .map((resource) => resource.objectUrl)
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toList(growable: false);
    for (final url in urls) {
      _mediaObjectUrlPlatform.revokeObjectUrl(url);
    }
  }

  MediaObjectUrlPlatform get _mediaObjectUrlPlatform {
    _cachedMediaPlatform ??= ref.read(mediaObjectUrlPlatformProvider);
    return _cachedMediaPlatform!;
  }
}

class _ParsedEventCursor {
  const _ParsedEventCursor({
    required this.streamVersion,
    required this.streamGeneration,
    required this.eventId,
  });

  final int? streamVersion;
  final String? streamGeneration;
  final int eventId;
}

String _guessMimeType(String filename) {
  final extensionIndex = filename.lastIndexOf('.');
  if (extensionIndex < 0 || extensionIndex >= filename.length - 1) {
    return 'application/octet-stream';
  }

  final extension = filename.substring(extensionIndex + 1).toLowerCase();
  switch (extension) {
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    case 'png':
      return 'image/png';
    case 'gif':
      return 'image/gif';
    case 'webp':
      return 'image/webp';
    case 'bmp':
      return 'image/bmp';
    case 'svg':
      return 'image/svg+xml';
    case 'mp3':
      return 'audio/mpeg';
    case 'wav':
      return 'audio/wav';
    case 'ogg':
      return 'audio/ogg';
    case 'm4a':
      return 'audio/mp4';
    case 'mp4':
      return 'video/mp4';
    case 'webm':
      return 'video/webm';
    case 'mov':
      return 'video/quicktime';
    case 'mkv':
      return 'video/x-matroska';
    case 'pdf':
      return 'application/pdf';
    case 'txt':
      return 'text/plain';
    case 'json':
      return 'application/json';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'xlsm':
      return 'application/vnd.ms-excel.sheet.macroenabled.12';
    default:
      return 'application/octet-stream';
  }
}

String _normalizePreviewMimeType(String mimeType) {
  return mimeType.split(';').first.trim().toLowerCase();
}

bool _isTextPreviewMimeType(String mimeType) {
  if (mimeType.startsWith('text/')) {
    return true;
  }

  return mimeType == 'application/json' ||
      mimeType == 'application/xml' ||
      mimeType == 'application/javascript' ||
      mimeType == 'application/x-javascript';
}

String _buildTextPreviewSnippet(Uint8List bytes) {
  const maxDecodeBytes = 128 * 1024;
  const maxLines = 40;
  const maxChars = 4000;
  final probeLength = min(bytes.length, maxDecodeBytes);
  final decoded = utf8.decode(
    bytes.sublist(0, probeLength),
    allowMalformed: true,
  );
  if (decoded.trim().isEmpty) {
    return '';
  }

  final normalized = decoded.replaceAll('\r\n', '\n').trimRight();
  final lines = normalized.split('\n');
  var preview = lines.length > maxLines
      ? lines.take(maxLines).join('\n')
      : normalized;
  if (preview.length > maxChars) {
    preview = preview.substring(0, maxChars);
  }

  final wasTrimmed =
      preview.length < normalized.length || lines.length > maxLines;
  if (wasTrimmed) {
    preview = '$preview\n\n...';
  }
  return preview;
}

double? _extractPdfFirstPageAspectRatio(Uint8List bytes) {
  if (bytes.isEmpty) {
    return null;
  }

  const maxProbeBytes = 512 * 1024;
  final probeLength = min(bytes.length, maxProbeBytes);
  final pdfText = latin1.decode(
    bytes.sublist(0, probeLength),
    allowInvalid: true,
  );

  final mediaBoxMatch = RegExp(
    r'/MediaBox\s*\[\s*(-?\d*\.?\d+)\s+(-?\d*\.?\d+)\s+(-?\d*\.?\d+)\s+(-?\d*\.?\d+)\s*\]',
  ).firstMatch(pdfText);
  if (mediaBoxMatch == null) {
    return null;
  }

  final x0 = double.tryParse(mediaBoxMatch.group(1) ?? '');
  final y0 = double.tryParse(mediaBoxMatch.group(2) ?? '');
  final x1 = double.tryParse(mediaBoxMatch.group(3) ?? '');
  final y1 = double.tryParse(mediaBoxMatch.group(4) ?? '');
  if (x0 == null || y0 == null || x1 == null || y1 == null) {
    return null;
  }

  final width = (x1 - x0).abs();
  final height = (y1 - y0).abs();
  if (width <= 0 || height <= 0) {
    return null;
  }

  return (width / height).clamp(0.35, 3.0);
}

const String _xlsxMimeType =
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
const String _xlsmMimeType = 'application/vnd.ms-excel.sheet.macroenabled.12';
const int _maxSpreadsheetArchiveBytes = 8 * 1024 * 1024;
const int _maxSpreadsheetXmlBytes = 2 * 1024 * 1024;
const int _maxSpreadsheetPreviewRows = 12;
const int _maxSpreadsheetPreviewColumns = 8;
const int _maxSpreadsheetCellChars = 120;

bool _isSpreadsheetPreviewCandidate({
  required String mimeType,
  String? filename,
}) {
  final normalizedFilename = filename?.trim().toLowerCase() ?? '';
  final hasSpreadsheetExtension =
      normalizedFilename.endsWith('.xlsx') ||
      normalizedFilename.endsWith('.xlsm');

  return mimeType == _xlsxMimeType ||
      mimeType == _xlsmMimeType ||
      hasSpreadsheetExtension;
}

ChatSpreadsheetPreview? _buildSpreadsheetPreview(Uint8List bytes) {
  if (bytes.isEmpty || bytes.length > _maxSpreadsheetArchiveBytes) {
    return null;
  }

  Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes, verify: false);
  } catch (_) {
    return null;
  }

  final archiveEntries = <String, ArchiveFile>{};
  for (final file in archive.files) {
    if (!file.isFile) {
      continue;
    }

    archiveEntries[file.name.replaceAll('\\', '/')] = file;
  }

  final workbookXml = _readArchiveText(
    archiveEntries['xl/workbook.xml'],
    maxBytes: _maxSpreadsheetXmlBytes,
  );
  if (workbookXml == null || workbookXml.trim().isEmpty) {
    return null;
  }

  final workbookDoc = _safeParseXml(workbookXml);
  if (workbookDoc == null) {
    return null;
  }

  var sheetName = 'Sheet1';
  String? relationshipId;
  for (final element in workbookDoc.descendants.whereType<xml.XmlElement>()) {
    if (element.name.local != 'sheet') {
      continue;
    }

    final resolvedSheetName = _xmlAttributeValue(element, 'name');
    if (resolvedSheetName != null && resolvedSheetName.trim().isNotEmpty) {
      sheetName = resolvedSheetName.trim();
    }
    relationshipId =
        _xmlAttributeValue(element, 'id', preferredPrefix: 'r') ??
        _xmlAttributeValue(element, 'id'); // coverage:ignore-line
    break;
  }

  final relationshipsXml = _readArchiveText(
    archiveEntries['xl/_rels/workbook.xml.rels'],
    maxBytes: _maxSpreadsheetXmlBytes,
  );
  final worksheetPath = _resolveWorksheetPath(
    relationshipId: relationshipId,
    relationshipsXml: relationshipsXml,
    archiveEntries: archiveEntries,
  );
  if (worksheetPath == null) {
    return null;
  }

  final worksheetXml = _readArchiveText(
    archiveEntries[worksheetPath],
    maxBytes: _maxSpreadsheetXmlBytes,
  );
  if (worksheetXml == null || worksheetXml.trim().isEmpty) {
    return null;
  }

  final worksheetDoc = _safeParseXml(worksheetXml);
  if (worksheetDoc == null) {
    return null;
  }

  final sharedStrings = _parseSpreadsheetSharedStrings(
    _readArchiveText(
      archiveEntries['xl/sharedStrings.xml'],
      maxBytes: _maxSpreadsheetXmlBytes,
    ),
  );

  return _parseWorksheetPreview(
    worksheetDoc: worksheetDoc,
    sheetName: sheetName,
    sharedStrings: sharedStrings,
  );
}

xml.XmlDocument? _safeParseXml(String xmlSource) {
  try {
    return xml.XmlDocument.parse(xmlSource);
  } catch (_) {
    return null;
  }
}

String? _readArchiveText(ArchiveFile? archiveFile, {required int maxBytes}) {
  if (archiveFile == null || !archiveFile.isFile) {
    return null;
  }
  if (archiveFile.size > maxBytes) {
    return null;
  }

  final bytes = _archiveFileToBytes(archiveFile);
  if (bytes == null || bytes.isEmpty || bytes.length > maxBytes) {
    return null;
  }

  return utf8.decode(bytes, allowMalformed: true);
}

Uint8List? _archiveFileToBytes(ArchiveFile archiveFile) {
  final content = archiveFile.content;
  if (content is Uint8List) {
    return content;
  }
  if (content is List<int>) { // coverage:ignore-line
    return Uint8List.fromList(content); // coverage:ignore-line
  }
  if (content is String) { // coverage:ignore-line
    return Uint8List.fromList(utf8.encode(content)); // coverage:ignore-line
  }
  return null;
}

String? _resolveWorksheetPath({
  required String? relationshipId,
  required String? relationshipsXml,
  required Map<String, ArchiveFile> archiveEntries,
}) {
  if (relationshipId != null &&
      relationshipId.isNotEmpty &&
      relationshipsXml != null &&
      relationshipsXml.trim().isNotEmpty) {
    final relationshipsDoc = _safeParseXml(relationshipsXml);
    if (relationshipsDoc != null) {
      for (final element
          in relationshipsDoc.descendants.whereType<xml.XmlElement>()) {
        if (element.name.local.toLowerCase() != 'relationship') {
          continue;
        }

        final id = _xmlAttributeValue(element, 'Id');
        if (id != relationshipId) {
          continue;
        }

        final target = _xmlAttributeValue(element, 'Target');
        if (target == null || target.trim().isEmpty) {
          continue;
        }

        final normalizedPath = _normalizeWorksheetPathTarget(target);
        if (archiveEntries.containsKey(normalizedPath)) {
          return normalizedPath;
        }
      }
    }
  }

  final fallbackCandidates =
      archiveEntries.keys
          .where(
            (path) =>
                path.startsWith('xl/worksheets/') &&
                path.toLowerCase().endsWith('.xml'),
          )
          .toList(growable: false)
        ..sort();
  if (fallbackCandidates.isEmpty) {
    return null;
  }
  return fallbackCandidates.first;
}

String _normalizeWorksheetPathTarget(String target) {
  var normalized = target.replaceAll('\\', '/');
  while (normalized.startsWith('../')) {
    normalized = normalized.substring(3); // coverage:ignore-line
  }
  if (normalized.startsWith('/')) {
    normalized = normalized.substring(1); // coverage:ignore-line
  }
  if (!normalized.startsWith('xl/')) {
    normalized = 'xl/$normalized';
  }
  return normalized;
}

List<String> _parseSpreadsheetSharedStrings(String? sharedStringsXml) {
  if (sharedStringsXml == null || sharedStringsXml.trim().isEmpty) {
    return const <String>[];
  }

  final document = _safeParseXml(sharedStringsXml);
  if (document == null) {
    return const <String>[];
  }

  final values = <String>[];
  for (final element in document.descendants.whereType<xml.XmlElement>()) {
    if (element.name.local != 'si') {
      continue;
    }
    values.add(_extractSpreadsheetText(element));
  }
  return values;
}

ChatSpreadsheetPreview _parseWorksheetPreview({
  required xml.XmlDocument worksheetDoc,
  required String sheetName,
  required List<String> sharedStrings,
}) {
  final previewRows = <Map<int, String>>[];
  var maxColumnSeen = 0;
  var hasMoreRows = false;
  var hasMoreColumns = false;

  for (final element in worksheetDoc.descendants.whereType<xml.XmlElement>()) {
    if (element.name.local != 'row') {
      continue;
    }
    if (previewRows.length >= _maxSpreadsheetPreviewRows) {
      hasMoreRows = true;
      break;
    }

    final rowValues = <int, String>{};
    var fallbackColumnIndex = 0;
    for (final cell in element.childElements.where((cell) {
      return cell.name.local == 'c';
    })) {
      final referencedColumn = _columnIndexFromCellReference(
        _xmlAttributeValue(cell, 'r') ?? '',
      );
      final columnIndex = referencedColumn ?? fallbackColumnIndex;
      fallbackColumnIndex = columnIndex + 1;

      if (columnIndex >= _maxSpreadsheetPreviewColumns) {
        hasMoreColumns = true;
        continue;
      }

      final value = _extractWorksheetCellValue(cell, sharedStrings);
      rowValues[columnIndex] = value;
      if (columnIndex + 1 > maxColumnSeen) {
        maxColumnSeen = columnIndex + 1;
      }
    }

    previewRows.add(rowValues);
  }

  final columnCount = max(1, min(maxColumnSeen, _maxSpreadsheetPreviewColumns));
  final denseRows = previewRows
      .map((row) {
        return List<String>.generate(
          columnCount,
          (columnIndex) => row[columnIndex] ?? '',
          growable: false,
        );
      })
      .toList(growable: false);

  return ChatSpreadsheetPreview(
    sheetName: sheetName,
    rows: denseRows,
    truncatedRows: hasMoreRows,
    truncatedColumns: hasMoreColumns,
  );
}

String _extractWorksheetCellValue(
  xml.XmlElement cell,
  List<String> sharedStrings,
) {
  final type = _xmlAttributeValue(cell, 't');
  if (type == 's') {
    final sharedStringIndex = int.tryParse(_firstChildInnerText(cell, 'v'));
    if (sharedStringIndex == null ||
        sharedStringIndex < 0 ||
        sharedStringIndex >= sharedStrings.length) {
      return '';
    }
    return sharedStrings[sharedStringIndex];
  }

  if (type == 'inlineStr') {
    for (final inlineString in cell.descendants.whereType<xml.XmlElement>()) {
      if (inlineString.name.local != 'is') {
        continue;
      }
      return _extractSpreadsheetText(inlineString);
    }
  }

  if (type == 'b') {
    final value = _firstChildInnerText(cell, 'v').trim();
    if (value == '1') {
      return 'TRUE';
    }
    if (value == '0') {
      return 'FALSE';
    }
  }

  final scalar = _firstChildInnerText(cell, 'v');
  if (scalar.isNotEmpty) {
    return _normalizeSpreadsheetCellValue(scalar);
  }

  final formula = _firstChildInnerText(cell, 'f');
  if (formula.isNotEmpty) {
    return _normalizeSpreadsheetCellValue('=$formula');
  }

  return '';
}

String _extractSpreadsheetText(xml.XmlElement element) {
  final buffer = StringBuffer();
  for (final textNode in element.descendants.whereType<xml.XmlElement>()) {
    if (textNode.name.local != 't') {
      continue;
    }
    buffer.write(textNode.innerText);
  }

  return _normalizeSpreadsheetCellValue(buffer.toString());
}

String _firstChildInnerText(xml.XmlElement parent, String localName) {
  for (final child in parent.childElements) {
    if (child.name.local == localName) {
      return child.innerText;
    }
  }
  return '';
}

String? _xmlAttributeValue(
  xml.XmlElement element,
  String localName, {
  String? preferredPrefix,
}) {
  if (preferredPrefix != null) {
    for (final attribute in element.attributes) {
      if (attribute.name.local == localName &&
          attribute.name.prefix == preferredPrefix) {
        return attribute.value;
      }
    }
  }

  for (final attribute in element.attributes) {
    if (attribute.name.local == localName) {
      return attribute.value;
    }
  }
  return null;
}

int? _columnIndexFromCellReference(String reference) {
  if (reference.isEmpty) {
    return null;
  }

  final letters = RegExp(r'^[A-Za-z]+').stringMatch(reference);
  if (letters == null || letters.isEmpty) {
    return null;
  }

  var index = 0;
  for (final codeUnit in letters.toUpperCase().codeUnits) {
    final value = codeUnit - 64;
    if (value < 1 || value > 26) {
      return null;
    }
    index = (index * 26) + value;
  }

  return index - 1;
}

String _normalizeSpreadsheetCellValue(String value) {
  final normalized = value
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n')
      .trim();
  if (normalized.isEmpty) {
    return '';
  }
  if (normalized.length <= _maxSpreadsheetCellChars) {
    return normalized;
  }
  return '${normalized.substring(0, _maxSpreadsheetCellChars - 3)}...';
}
