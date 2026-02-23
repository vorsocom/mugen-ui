import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const double _chatPageMaxWidth = 960;
const Key _chatPageContentColumnKey = Key('chat-page-content-column');
const Key _composerInputFieldKey = Key('chat-composer-input');
const Key _composerAttachButtonKey = Key('chat-composer-attach-button');
const Key _composerSendButtonKey = Key('chat-composer-send-button');
const Key _composerModeToggleKey = Key('chat-composer-mode-toggle');
const Key _clearTranscriptButtonKey = Key('chat-clear-transcript-button');
const Key _clearTranscriptCancelButtonKey = Key(
  'chat-clear-transcript-cancel-button',
);
const Key _clearTranscriptConfirmButtonKey = Key(
  'chat-clear-transcript-confirm-button',
);
const Key _scrollToBottomButtonKey = Key('chat-scroll-to-bottom-button');
const Key _loadOlderMessagesButtonKey = Key('chat-load-older-button');
const String _userAttachmentCueKeyPrefix = 'chat-user-attachment-cue-';
const double _composerBottomReserveSpace = 24;
const double _scrollButtonMinScrollableExtent = 220;
const double _scrollButtonDistanceThreshold = 120;
const double _defaultTranscriptRowSpacing = 14;
const int _initialWindowSize = 80;
const int _windowChunkSize = 40;
const int _longMarkdownCharThreshold = 4000;
const int _longMarkdownLineThreshold = 120;
const int _collapsedMarkdownPreviewCharLimit = 1400;
const int _collapsedMarkdownPreviewLineLimit = 24;
const double _uploadedImageThumbnailSize = 120;

enum _TranscriptRowKind { loadOlder, message, thinking }

class _TranscriptRowItem {
  const _TranscriptRowItem.loadOlder()
    : kind = _TranscriptRowKind.loadOlder,
      message = null;

  const _TranscriptRowItem.message(this.message)
    : kind = _TranscriptRowKind.message;

  const _TranscriptRowItem.thinking()
    : kind = _TranscriptRowKind.thinking,
      message = null;

  final _TranscriptRowKind kind;
  final ChatMessageEntity? message;
}

const EdgeInsets _chatBubblePadding = EdgeInsets.symmetric(
  horizontal: 12,
  vertical: 8,
);
const double _chatInlineMetaGap = 6;

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key}); // coverage:ignore-line

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _composerController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _temporaryAnchorKey = GlobalKey(
    debugLabel: 'chat-transcript-anchor',
  );
  final Set<String> _expandedMarkdownMessageIds = <String>{};
  int _lastTranscriptCount = 0;
  String? _lastAssistantRenderSignature;
  bool _assistantRenderTrackingReady = false;
  bool _showScrollToBottomButton = false;
  bool _isLoadingOlderWindow = false;
  int _visibleStartIndex = 0;
  String? _windowConversationId;
  String? _temporaryAnchorMessageId;

  @override
  void initState() {
    super.initState();
    _composerController.addListener(_handleComposerChanged);
    _scrollController.addListener(_handleScrollChanged);
    Future<void>.microtask(() {
      ref.read(chatControllerProvider.notifier).ensureStreaming();
    });
  }

  void _handleComposerChanged() {
    if (!mounted) {
      return;
    }
    setState(() {});
  }

  void _handleScrollChanged() {
    _updateScrollToBottomButtonVisibility();
  }

  void _updateScrollToBottomButtonVisibility() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    final shouldShow =
        position.maxScrollExtent > _scrollButtonMinScrollableExtent &&
        distanceFromBottom > _scrollButtonDistanceThreshold;
    if (shouldShow == _showScrollToBottomButton) {
      return;
    }
    setState(() {
      _showScrollToBottomButton = shouldShow;
    });
  }

  @override
  void dispose() {
    _composerController.removeListener(_handleComposerChanged);
    _composerController.dispose();
    _scrollController.removeListener(_handleScrollChanged);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    final controller = ref.read(chatControllerProvider.notifier);
    final theme = Theme.of(context);
    _syncVisibleWindow(state);
    _pruneExpandedMarkdownIds(state.messages);
    final showThinkingBubble = state.isConnected && state.isAssistantThinking;
    final transcriptCount =
        state.messages.length + (showThinkingBubble ? 1 : 0);
    final visibleMessages = _visibleMessages(state.messages);
    final hasHiddenOlderMessages = _visibleStartIndex > 0;
    final transcriptRows = _buildTranscriptRows(
      visibleMessages: visibleMessages,
      hasHiddenOlderMessages: hasHiddenOlderMessages,
      showThinkingBubble: showThinkingBubble,
    );
    final transcriptRowCount = transcriptRows.length;
    final transcriptListChildCount = transcriptRowCount == 0
        ? 0
        : transcriptRowCount * 2 - 1;
    final composerText = _composerController.text;
    final composerError = controller.composerValidationError(composerText);
    final trimmedComposerText = composerText.trim();
    final inlineComposerError =
        (state.errorMessage != null && state.errorMessage!.trim().isNotEmpty)
        ? state.errorMessage! // coverage:ignore-line
        : ((state.attachments.isNotEmpty || trimmedComposerText.isNotEmpty)
              ? composerError
              : null);
    final canSubmit = !state.isSending && composerError == null;
    final canClearTranscript = state.messages.isNotEmpty;
    final latestAssistantMessage = _latestAssistantMessage(state.messages);
    final latestAssistantSignature = _assistantRenderSignature(
      latestAssistantMessage,
      latestAssistantMessage == null
          ? null
          : state.mediaResources[latestAssistantMessage.id],
    );
    final shouldAutoFollowOnNewMessage = _isNearBottom();
    final newestMessage = state.messages.isEmpty ? null : state.messages.last;
    final skipBottomFollowForLargeAssistant =
        newestMessage?.role == ChatMessageRole.assistant &&
        _isLargeAssistantResponse(newestMessage!);

    if (_lastTranscriptCount != transcriptCount) {
      _lastTranscriptCount = transcriptCount;
      if (shouldAutoFollowOnNewMessage && !skipBottomFollowForLargeAssistant) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          unawaited(_scrollToBottom());
        });
      }
    }
    if (!_assistantRenderTrackingReady) {
      _assistantRenderTrackingReady = true;
      _lastAssistantRenderSignature = latestAssistantSignature;
    } else if (latestAssistantSignature != null &&
        latestAssistantSignature != _lastAssistantRenderSignature) {
      _lastAssistantRenderSignature = latestAssistantSignature;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (latestAssistantMessage == null) {
          return;
        }
        _autoScrollForAssistantRender(
          transcript: state.messages,
          assistantMessage: latestAssistantMessage,
        );
      });
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updateScrollToBottomButtonVisibility();
    });

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : _chatPageMaxWidth;
        final contentWidth = availableWidth <= _chatPageMaxWidth
            ? availableWidth
            : _chatPageMaxWidth;

        return SizedBox.expand(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: _chatPageContentColumnKey,
              width: contentWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: transcriptRowCount == 0
                              ? Center(
                                  child: Text(
                                    'Start the conversation.',
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                )
                              : ListView.custom(
                                  controller: _scrollController,
                                  cacheExtent: 480,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 18,
                                  ),
                                  childrenDelegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index.isOdd) {
                                        return const SizedBox(
                                          height: _defaultTranscriptRowSpacing,
                                        );
                                      }
                                      final rowIndex = index ~/ 2;
                                      final row = transcriptRows[rowIndex];
                                      if (row.kind ==
                                          _TranscriptRowKind.loadOlder) {
                                        return _LoadOlderMessagesButton(
                                          key: _loadOlderMessagesButtonKey,
                                          isLoading: _isLoadingOlderWindow,
                                          onPressed: _isLoadingOlderWindow
                                              ? null
                                              : () => _loadOlderWindow(
                                                  state.messages,
                                                ),
                                        );
                                      }

                                      if (row.kind ==
                                          _TranscriptRowKind.thinking) {
                                        return const _AssistantThinkingBubble();
                                      }

                                      final message = row.message!;
                                      final mediaResource =
                                          state.mediaResources[message.id];
                                      final rowKey =
                                          _temporaryAnchorMessageId ==
                                              message.id
                                          ? _temporaryAnchorKey
                                          : ValueKey<String>(
                                              'chat-message-${message.id}',
                                            );
                                      return KeyedSubtree(
                                        key: rowKey,
                                        child: _ChatMessageBubble(
                                          message: message,
                                          mediaResource: mediaResource,
                                          isAssistantMarkdownExpanded:
                                              _expandedMarkdownMessageIds
                                                  .contains(message.id),
                                          onToggleAssistantMarkdownExpanded:
                                              () => _toggleMarkdownExpansion(
                                                message.id,
                                              ),
                                          onEnsureMediaLoaded: () {
                                            controller.ensureMediaLoaded(
                                              message.id,
                                            );
                                          },
                                          onRetryMediaLoad: () {
                                            controller.retryMediaLoad(
                                              message.id,
                                            );
                                          },
                                          onDownloadMedia: () {
                                            controller.downloadMediaToDevice(
                                              message.id,
                                            );
                                          },
                                        ),
                                      );
                                    },
                                    childCount: transcriptListChildCount,
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: true,
                                    addSemanticIndexes: false,
                                  ),
                                ),
                        ),
                        if (_showScrollToBottomButton)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Material(
                                  color: Colors.white,
                                  elevation: 2,
                                  borderRadius: BorderRadius.circular(20),
                                  child: InkWell(
                                    key: _scrollToBottomButtonKey,
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: _scrollToBottom,
                                    child: const Padding(
                                      padding: EdgeInsets.all(8),
                                      child: Icon(
                                        Icons.keyboard_arrow_down_rounded,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(
                      14,
                      10,
                      14,
                      14 + _composerBottomReserveSpace,
                    ),
                    decoration: BoxDecoration(color: Colors.white),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: AppUiPalette.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Focus(
                                onKeyEvent: (_, event) {
                                  if (event is! KeyDownEvent) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (event.logicalKey !=
                                      LogicalKeyboardKey.enter) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (HardwareKeyboard
                                      .instance
                                      .isShiftPressed) {
                                    return KeyEventResult.ignored;
                                  }
                                  if (!canSubmit) {
                                    return KeyEventResult.handled;
                                  }

                                  _submitComposer(controller); // coverage:ignore-line
                                  return KeyEventResult.handled;
                                },
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    8,
                                    0,
                                    8,
                                    10,
                                  ),
                                  child: TextField(
                                    key: _composerInputFieldKey,
                                    controller: _composerController,
                                    minLines: 1,
                                    maxLines: 6,
                                    textInputAction: TextInputAction.newline,
                                    decoration: InputDecoration(
                                      hintText: 'Type a message',
                                      hintStyle: TextStyle(
                                        color: AppUiPalette.textMuted,
                                      ),
                                      filled: false,
                                      fillColor: Colors.transparent,
                                      hoverColor: Colors.transparent,
                                      focusColor: Colors.transparent,
                                      border: InputBorder.none,
                                      enabledBorder: InputBorder.none,
                                      focusedBorder: InputBorder.none,
                                      errorBorder: InputBorder.none,
                                      focusedErrorBorder: InputBorder.none,
                                      disabledBorder: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
                              if (state.attachments.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _ComposerModeToggle(
                                  key: _composerModeToggleKey,
                                  current: state.compositionMode,
                                  onChanged: state.isSending
                                      ? null
                                      : controller.setCompositionMode,
                                ),
                                const SizedBox(height: 8),
                                _ComposerAttachmentList(
                                  attachments: state.attachments,
                                  compositionMode: state.compositionMode,
                                  isSending: state.isSending,
                                  onRemove: controller.removeAttachment,
                                  onCaptionChanged:
                                      controller.updateAttachmentCaption,
                                ),
                              ],
                              if (inlineComposerError != null &&
                                  inlineComposerError.trim().isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(
                                  inlineComposerError,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.red.shade700,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              const _ComposerDivider(),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  IconButton(
                                    key: _composerAttachButtonKey,
                                    tooltip: 'Attach file',
                                    onPressed: state.isSending
                                        ? null
                                        : controller.attachFromPicker,
                                    icon: const Icon(Icons.attach_file),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    key: _composerSendButtonKey,
                                    tooltip: 'Send message',
                                    onPressed: canSubmit
                                        ? () => _submitComposer(controller)
                                        : null,
                                    style: IconButton.styleFrom(
                                      backgroundColor: Colors.black,
                                      foregroundColor: Colors.white,
                                      disabledBackgroundColor:
                                          AppUiPalette.border,
                                      disabledForegroundColor:
                                          AppUiPalette.textSecondary,
                                    ),
                                    icon: state.isSending
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.send_rounded,
                                            size: 18,
                                          ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.center,
                          child: TextButton.icon(
                            key: _clearTranscriptButtonKey,
                            onPressed: canClearTranscript
                                ? () => _confirmAndClearTranscript(controller)
                                : null,
                            icon: const Icon(Icons.clear_all_rounded, size: 18),
                            label: const Text('Clear transcript'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _syncVisibleWindow(ChatControllerState state) {
    final conversationChanged = _windowConversationId != state.conversationId;
    if (conversationChanged) {
      _windowConversationId = state.conversationId;
      _visibleStartIndex = _initialVisibleStart(state.messages.length);
      _expandedMarkdownMessageIds.clear();
      _temporaryAnchorMessageId = null;
      _assistantRenderTrackingReady = false;
      _lastAssistantRenderSignature = null;
    }

    if (state.messages.isEmpty) {
      _visibleStartIndex = 0;
      return;
    }

    if (_visibleStartIndex < 0 || _visibleStartIndex > state.messages.length) {
      _visibleStartIndex = _initialVisibleStart(state.messages.length); // coverage:ignore-line
    }
  }

  int _initialVisibleStart(int messageCount) {
    if (messageCount <= _initialWindowSize) {
      return 0;
    }
    return messageCount - _initialWindowSize;
  }

  List<ChatMessageEntity> _visibleMessages(
    List<ChatMessageEntity> allMessages,
  ) {
    final clampedStart = _visibleStartIndex < 0
        ? 0
        : (_visibleStartIndex > allMessages.length
              ? allMessages.length // coverage:ignore-line
              : _visibleStartIndex);
    if (clampedStart == 0) {
      return allMessages;
    }
    return allMessages.sublist(clampedStart);
  }

  List<_TranscriptRowItem> _buildTranscriptRows({
    required List<ChatMessageEntity> visibleMessages,
    required bool hasHiddenOlderMessages,
    required bool showThinkingBubble,
  }) {
    final rows = <_TranscriptRowItem>[];
    if (hasHiddenOlderMessages) {
      rows.add(const _TranscriptRowItem.loadOlder());
    }
    for (final message in visibleMessages) {
      rows.add(_TranscriptRowItem.message(message));
    }
    if (showThinkingBubble) {
      rows.add(const _TranscriptRowItem.thinking());
    }
    return rows;
  }

  void _pruneExpandedMarkdownIds(List<ChatMessageEntity> messages) {
    if (_expandedMarkdownMessageIds.isEmpty) {
      return;
    }
    final active = messages.map((message) => message.id).toSet();
    _expandedMarkdownMessageIds.removeWhere((id) => !active.contains(id));
  }

  void _toggleMarkdownExpansion(String messageId) {
    setState(() {
      if (_expandedMarkdownMessageIds.contains(messageId)) {
        _expandedMarkdownMessageIds.remove(messageId); // coverage:ignore-line
      } else {
        _expandedMarkdownMessageIds.add(messageId);
      }
    });
  }

  Future<void> _loadOlderWindow(List<ChatMessageEntity> transcript) async {
    if (!mounted || _isLoadingOlderWindow || _visibleStartIndex <= 0) {
      return;
    }
    if (transcript.isEmpty) {
      return;
    }

    final currentStart = _visibleStartIndex > transcript.length // coverage:ignore-line
        ? transcript.length // coverage:ignore-line
        : _visibleStartIndex;
    final nextStart = math.max(0, currentStart - _windowChunkSize);
    if (nextStart == _visibleStartIndex) {
      return;
    }

    final hasScrollMetrics = _scrollController.hasClients;
    final beforePixels = hasScrollMetrics
        ? _scrollController.position.pixels
        : 0;
    final beforeMax = hasScrollMetrics
        ? _scrollController.position.maxScrollExtent
        : 0.0;

    setState(() {
      _isLoadingOlderWindow = true;
      _visibleStartIndex = nextStart;
    });
    await _waitForNextFrame();

    if (_scrollController.hasClients) {
      final afterMax = _scrollController.position.maxScrollExtent;
      final deltaMax = afterMax - beforeMax;
      final target = beforePixels + deltaMax;
      final clamped = target
          .clamp(
            _scrollController.position.minScrollExtent,
            _scrollController.position.maxScrollExtent,
          )
          .toDouble();
      _scrollController.jumpTo(clamped);
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _isLoadingOlderWindow = false;
    });
  }

  Future<void> _waitForNextFrame() {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      completer.complete();
    });
    return completer.future;
  }

  ChatMessageEntity? _latestAssistantMessage(List<ChatMessageEntity> messages) {
    for (var index = messages.length - 1; index >= 0; index--) {
      final message = messages[index];
      if (message.role == ChatMessageRole.assistant) {
        return message;
      }
    }
    return null;
  }

  String? _assistantRenderSignature(
    ChatMessageEntity? assistantMessage,
    ChatMediaResourceState? mediaResource,
  ) {
    if (assistantMessage == null) {
      return null;
    }
    final textLength = assistantMessage.text?.length ?? 0;
    final mediaSignature = mediaResource == null
        ? ''
        : '${mediaResource.isLoading}|'
              '${mediaResource.objectUrl ?? ''}|'
              '${mediaResource.errorMessage ?? ''}';
    return '${assistantMessage.id}|$textLength|'
        '${assistantMessage.status.name}|'
        '${assistantMessage.media?.url ?? ''}|'
        '$mediaSignature';
  }

  String? _findAnchorUserMessageId({
    required List<ChatMessageEntity> transcript,
    required ChatMessageEntity assistantMessage,
  }) {
    String? findByMatch(bool Function(ChatMessageEntity message) matches) {
      for (var index = transcript.length - 1; index >= 0; index--) {
        final message = transcript[index];
        if (message.role != ChatMessageRole.user) {
          continue;
        }
        if (matches(message)) {
          return message.id;
        }
      }
      return null;
    }

    final assistantClientMessageId = assistantMessage.clientMessageId?.trim();
    if (assistantClientMessageId != null &&
        assistantClientMessageId.isNotEmpty) {
      final userId = findByMatch(
        (message) => message.clientMessageId == assistantClientMessageId,
      );
      if (userId != null) {
        return userId;
      }
    }

    final assistantJobId = assistantMessage.jobId?.trim();
    if (assistantJobId != null && assistantJobId.isNotEmpty) {
      final userId = findByMatch((message) => message.jobId == assistantJobId);
      if (userId != null) {
        return userId;
      }
    }

    final assistantIndex = transcript.lastIndexWhere( // coverage:ignore-start
      (message) => message.id == assistantMessage.id,
    );
    if (assistantIndex <= 0) {
      return null;
    }
    for (var index = assistantIndex - 1; index >= 0; index--) {
      final message = transcript[index];
      if (message.role == ChatMessageRole.user) {
        return message.id;
      }
    }
    // coverage:ignore-end
    return null;
  }

  bool _isLargeAssistantResponse(ChatMessageEntity assistantMessage) {
    final text = assistantMessage.text;
    if (text == null || text.isEmpty) {
      return false;
    }
    return _isOversizedText(text);
  }

  Future<void> _ensureAnchorInWindow({
    required List<ChatMessageEntity> transcript,
    required String targetMessageId,
  }) async {
    final targetIndex = transcript.indexWhere(
      (message) => message.id == targetMessageId,
    );
    if (targetIndex < 0) {
      return;
    }

    var needsRebuild = false;
    if (targetIndex < _visibleStartIndex) { // coverage:ignore-start
      final nextStart = math.max(0, targetIndex - 2);
      if (nextStart != _visibleStartIndex) {
        _visibleStartIndex = nextStart;
        needsRebuild = true;
      }
    }
    // coverage:ignore-end

    if (_temporaryAnchorMessageId != targetMessageId) {
      _temporaryAnchorMessageId = targetMessageId;
      needsRebuild = true;
    }

    if (needsRebuild && mounted) {
      setState(() {});
      await _waitForNextFrame();
    }
  }

  void _clearTemporaryAnchor() {
    if (!mounted || _temporaryAnchorMessageId == null) {
      return;
    }
    setState(() {
      _temporaryAnchorMessageId = null;
    });
  }

  Future<void> _autoScrollForAssistantRender({
    required List<ChatMessageEntity> transcript,
    required ChatMessageEntity assistantMessage,
  }) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    if (!_isLargeAssistantResponse(assistantMessage)) {
      await _scrollToBottom(); // coverage:ignore-line
      return;
    }

    final anchorUserId = _findAnchorUserMessageId(
      transcript: transcript,
      assistantMessage: assistantMessage,
    );

    final targetMessageId = anchorUserId ?? assistantMessage.id; // coverage:ignore-line
    await _ensureAnchorInWindow(
      transcript: transcript,
      targetMessageId: targetMessageId,
    );
    if (!mounted) {
      return;
    }

    final targetContext = _temporaryAnchorKey.currentContext;
    if (targetContext == null || !targetContext.mounted) {
      _clearTemporaryAnchor(); // coverage:ignore-line
      if (anchorUserId == null) {
        await _scrollToBottom(); // coverage:ignore-line
      }
      return;
    }

    final desiredOffset = _offsetToReveal(
      context: targetContext,
      alignment: 0.06,
    );
    final anchorTopOffset = _offsetToReveal(context: targetContext);
    if (desiredOffset == null || anchorTopOffset == null) {
      if (anchorUserId == null) {
        await _scrollToBottom(); // coverage:ignore-line
      }
      _clearTemporaryAnchor(); // coverage:ignore-line
      return;
    }

    final position = _scrollController.position;
    var targetOffset = desiredOffset
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    if (anchorUserId != null) {
      final maxOffsetBeforePassingUser = anchorTopOffset
          .clamp(position.minScrollExtent, position.maxScrollExtent)
          .toDouble();
      if (targetOffset > maxOffsetBeforePassingUser) {
        targetOffset = maxOffsetBeforePassingUser;
      }
    }

    final distance = (position.pixels - targetOffset).abs();
    if (distance >= 1) {
      await _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
    _clearTemporaryAnchor();
  }

  double? _offsetToReveal({
    required BuildContext context,
    double alignment = 0,
  }) {
    if (!_scrollController.hasClients) {
      return null;
    }
    final renderObject = context.findRenderObject();
    if (renderObject == null || !renderObject.attached) {
      return null;
    }
    final viewport = RenderAbstractViewport.maybeOf(renderObject);
    if (viewport == null) {
      return null;
    }
    return viewport.getOffsetToReveal(renderObject, alignment).offset;
  }

  bool _isNearBottom() {
    if (!_scrollController.hasClients) {
      return true;
    }
    final distanceFromBottom =
        _scrollController.position.maxScrollExtent -
        _scrollController.position.pixels;
    return distanceFromBottom <= _scrollButtonDistanceThreshold;
  }

  Future<void> _scrollToBottom() async {
    if (!_scrollController.hasClients) {
      return;
    }
    await _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _submitComposer(ChatController controller) async {
    final sent = await controller.sendMessage(_composerController.text);
    if (sent) {
      _composerController.clear();
    }
  }

  Future<void> _confirmAndClearTranscript(ChatController controller) async {
    final confirmed = await showAppConfirmationDialog(
      context: context,
      title: 'Clear transcript?',
      message:
          'This clears only the local UI transcript. You must still send the '
          'backend clear command manually.',
      confirmLabel: 'Clear',
      cancelButtonKey: _clearTranscriptCancelButtonKey,
      confirmButtonKey: _clearTranscriptConfirmButtonKey,
      icon: Icons.delete_outline,
    );

    if (confirmed != true || !mounted) {
      return;
    }

    controller.clearTranscript();
    ref
        .read(snackBarDispatcherProvider)
        .showInContext(context, 'Transcript cleared locally.');
  }
}

class _ComposerModeToggle extends StatelessWidget {
  const _ComposerModeToggle({
    super.key,
    required this.current,
    required this.onChanged,
  });

  final ChatCompositionMode current;
  final ValueChanged<ChatCompositionMode>? onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ChatCompositionMode>(
      showSelectedIcon: false,
      segments: const <ButtonSegment<ChatCompositionMode>>[
        ButtonSegment<ChatCompositionMode>(
          value: ChatCompositionMode.messageWithAttachments,
          label: Text('Message + files'),
          icon: Icon(Icons.chat_bubble_outline_rounded),
        ),
        ButtonSegment<ChatCompositionMode>(
          value: ChatCompositionMode.attachmentWithCaption,
          label: Text('Caption per file'),
          icon: Icon(Icons.subtitles_outlined),
        ),
      ],
      selected: <ChatCompositionMode>{current},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) {
              if (selection.isEmpty) {
                return;
              }
              onChanged!(selection.first);
            },
    );
  }
}

class _ComposerAttachmentList extends StatelessWidget {
  const _ComposerAttachmentList({
    required this.attachments,
    required this.compositionMode,
    required this.isSending,
    required this.onRemove,
    required this.onCaptionChanged,
  });

  final List<ChatAttachmentDraft> attachments;
  final ChatCompositionMode compositionMode;
  final bool isSending;
  final ValueChanged<String> onRemove;
  final void Function({required String attachmentId, required String caption})
  onCaptionChanged;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return const SizedBox.shrink();
    }

    final requiresCaption =
        compositionMode == ChatCompositionMode.attachmentWithCaption;
    return Column(
      children: attachments
          .map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ComposerAttachmentTile(
                attachment: attachment,
                requiresCaption: requiresCaption,
                isSending: isSending,
                onRemove: () => onRemove(attachment.id), // coverage:ignore-line
                onCaptionChanged: (caption) {
                  onCaptionChanged(
                    attachmentId: attachment.id,
                    caption: caption,
                  );
                },
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ComposerAttachmentTile extends StatelessWidget {
  const _ComposerAttachmentTile({
    required this.attachment,
    required this.requiresCaption,
    required this.isSending,
    required this.onRemove,
    required this.onCaptionChanged,
  });

  final ChatAttachmentDraft attachment;
  final bool requiresCaption;
  final bool isSending;
  final VoidCallback onRemove;
  final ValueChanged<String> onCaptionChanged;

  @override
  Widget build(BuildContext context) {
    final title = attachment.mimeType.trim().isEmpty
        ? attachment.filename // coverage:ignore-line
        : '${attachment.filename} (${attachment.mimeType})';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_file, size: 18),
              const SizedBox(width: 6),
              Expanded(child: Text(title, overflow: TextOverflow.ellipsis)),
              IconButton(
                icon: const Icon(Icons.close, size: 16),
                onPressed: isSending ? null : onRemove,
                tooltip: 'Remove attachment',
              ),
            ],
          ),
          TextFormField(
            key: ValueKey<String>('chat-caption-${attachment.id}'),
            enabled: !isSending,
            initialValue: attachment.caption,
            onChanged: onCaptionChanged,
            decoration: InputDecoration(
              isDense: true,
              hintText: requiresCaption
                  ? 'Caption (required)'
                  : 'Caption (optional)',
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposerDivider extends StatelessWidget {
  const _ComposerDivider();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: SizedBox(
        width: 180,
        height: 1,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: <Color>[
                Colors.transparent,
                AppUiPalette.borderStrong,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadOlderMessagesButton extends StatelessWidget {
  const _LoadOlderMessagesButton({
    super.key,
    required this.isLoading,
    required this.onPressed,
  });

  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final label = isLoading
        ? 'Loading older messages...'
        : 'Load older messages';
    return Align(
      alignment: Alignment.center,
      child: TextButton(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _AssistantThinkingBubble extends StatefulWidget {
  const _AssistantThinkingBubble();

  @override
  State<_AssistantThinkingBubble> createState() =>
      _AssistantThinkingBubbleState();
}

class _AssistantThinkingBubbleState extends State<_AssistantThinkingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final blinkColor = Color.lerp(
            AppUiPalette.borderStrong,
            AppUiPalette.textPrimary,
            _controller.value,
          );
          return Text(
            'Assistant is thinking...',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontSize: 11, color: blinkColor),
          );
        },
      ),
    );
  }
}

class _ChatMessageBubble extends StatelessWidget {
  const _ChatMessageBubble({
    required this.message,
    required this.mediaResource,
    required this.isAssistantMarkdownExpanded,
    required this.onToggleAssistantMarkdownExpanded,
    required this.onEnsureMediaLoaded,
    required this.onRetryMediaLoad,
    required this.onDownloadMedia,
  });

  final ChatMessageEntity message;
  final ChatMediaResourceState? mediaResource;
  final bool isAssistantMarkdownExpanded;
  final VoidCallback onToggleAssistantMarkdownExpanded;
  final VoidCallback onEnsureMediaLoaded;
  final VoidCallback onRetryMediaLoad;
  final VoidCallback onDownloadMedia;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatMessageRole.user;
    final isAssistant = message.role == ChatMessageRole.assistant;
    final hasText = message.text != null && message.text!.isNotEmpty;
    final hasMedia = message.media != null;
    final bubbleColor = switch (message.role) {
      ChatMessageRole.user => AppUiPalette.accentSoft,
      ChatMessageRole.assistant => AppUiPalette.surfaceMuted,
      ChatMessageRole.error => Colors.red.shade50,
      ChatMessageRole.system => Colors.orange.shade50,
    };
    final align = isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final showRoleLabel =
        message.role == ChatMessageRole.system ||
        message.role == ChatMessageRole.error;

    final shouldLoadRemoteMedia =
        message.role == ChatMessageRole.assistant &&
        message.media != null &&
        message.media!.url.trim().isNotEmpty &&
        mediaResource == null;
    if (shouldLoadRemoteMedia) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        onEnsureMediaLoaded();
      });
    }

    return Column(
      crossAxisAlignment: align,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 760),
          padding: _chatBubblePadding,
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppUiPalette.border),
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showRoleLabel) ...[
                    _RoleLabel(role: message.role),
                    const SizedBox(height: 4),
                  ],
                  if (hasText) ...[
                    if (isAssistant)
                      _AssistantTextWithMeta(
                        text: message.text!,
                        createdAt: message.createdAt,
                        isMarkdownExpanded: isAssistantMarkdownExpanded,
                        onToggleMarkdownExpansion:
                            onToggleAssistantMarkdownExpanded,
                      )
                    else if (isUser)
                      _UserTextWithMeta(
                        text: message.text!,
                        createdAt: message.createdAt,
                        status: message.status,
                      )
                    else
                      _ChatMarkdownText(text: message.text!),
                  ],
                  if (hasMedia) ...[
                    const SizedBox(height: 6),
                    if (isUser) ...[
                      _UserAttachmentCue(
                        messageId: message.id,
                        media: message.media!,
                        messageType: message.type,
                      ),
                      const SizedBox(height: 6),
                    ],
                    _MediaPanel(
                      message: message,
                      mediaResource: mediaResource,
                      onRetryMediaLoad: onRetryMediaLoad,
                      onDownloadMedia: onDownloadMedia,
                    ),
                  ],
                  if (isAssistant && (!hasText || hasMedia)) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: _AssistantMessageMeta(
                        createdAt: message.createdAt,
                      ),
                    ),
                  ],
                  if (isUser && !hasText) ...[
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerRight,
                      widthFactor: 1,
                      child: _UserMessageMeta(
                        status: message.status,
                        createdAt: message.createdAt,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AssistantMessageMeta extends StatelessWidget {
  const _AssistantMessageMeta({required this.createdAt});

  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Text(
      _formatMessageTime(createdAt),
      textAlign: TextAlign.right,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        fontSize: 11,
        color: AppUiPalette.textSecondary,
      ),
    );
  }
}

class _AssistantTextWithMeta extends StatelessWidget {
  const _AssistantTextWithMeta({
    required this.text,
    required this.createdAt,
    required this.isMarkdownExpanded,
    required this.onToggleMarkdownExpansion,
  });

  final String text;
  final DateTime createdAt;
  final bool isMarkdownExpanded;
  final VoidCallback onToggleMarkdownExpansion;

  @override
  Widget build(BuildContext context) {
    final isMarkdown = _looksLikeMarkdown(text);
    if (isMarkdown) {
      final isLargeMarkdown = _isLargeAssistantMarkdown(text);
      if (isLargeMarkdown && !isMarkdownExpanded) {
        final previewText = _collapsedMarkdownPreview(text);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SelectableText(previewText),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggleMarkdownExpansion,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Show full response'),
              ),
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerRight,
              child: _AssistantMessageMeta(createdAt: createdAt),
            ),
          ],
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatMarkdownText(text: text),
          if (isLargeMarkdown) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: onToggleMarkdownExpansion,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Collapse'),
              ),
            ),
          ],
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: _AssistantMessageMeta(createdAt: createdAt),
          ),
        ],
      );
    }

    final assistantTextStyle = DefaultTextStyle.of(context).style;
    final assistantStrutStyle = StrutStyle.fromTextStyle(assistantTextStyle);
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final metaStyle = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 11,
      color: AppUiPalette.textSecondary,
    );
    final metaText = _formatMessageTime(createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metaPainter = TextPainter(
          text: TextSpan(text: metaText, style: metaStyle),
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final metaWidth = metaPainter.width;
        final rawTextMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - metaWidth - _chatInlineMetaGap
            : double.infinity;
        final textMaxWidth = rawTextMaxWidth < 0 ? 0.0 : rawTextMaxWidth;

        final textPainter = TextPainter(
          text: TextSpan(text: text, style: assistantTextStyle),
          strutStyle: assistantStrutStyle,
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: textMaxWidth);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textMaxWidth),
              child: SelectableText(
                text,
                style: assistantTextStyle,
                strutStyle: assistantStrutStyle,
              ),
            ),
            const SizedBox(width: _chatInlineMetaGap),
            Padding(
              padding: EdgeInsets.only(top: textPainter.height),
              child: _AssistantMessageMeta(createdAt: createdAt),
            ),
          ],
        );
      },
    );
  }
}

class _RoleLabel extends StatelessWidget {
  const _RoleLabel({required this.role});

  final ChatMessageRole role;

  @override
  Widget build(BuildContext context) {
    final label = switch (role) {
      ChatMessageRole.user => '',
      ChatMessageRole.assistant => '',
      ChatMessageRole.system => 'System',
      ChatMessageRole.error => 'Error',
    };
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }
}

class _UserTextWithMeta extends StatelessWidget {
  const _UserTextWithMeta({
    required this.text,
    required this.createdAt,
    required this.status,
  });

  final String text;
  final DateTime createdAt;
  final ChatMessageStatus status;

  @override
  Widget build(BuildContext context) {
    final isMarkdown = _looksLikeMarkdown(text);
    if (isMarkdown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ChatMarkdownText(text: text),
          const SizedBox(height: 2),
          Align(
            alignment: Alignment.centerRight,
            child: _UserMessageMeta(status: status, createdAt: createdAt),
          ),
        ],
      );
    }

    final userTextStyle = DefaultTextStyle.of(context).style;
    final userStrutStyle = StrutStyle.fromTextStyle(userTextStyle);
    final direction = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final metaStyle = Theme.of(context).textTheme.bodySmall;
    final metaText = _formatMessageTime(createdAt);

    return LayoutBuilder(
      builder: (context, constraints) {
        final metaPainter = TextPainter(
          text: TextSpan(text: metaText, style: metaStyle),
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: constraints.maxWidth);
        final iconAndGapWidth = status == ChatMessageStatus.delivered
            ? 20.0
            : 18.0;
        final metaWidth = metaPainter.width + iconAndGapWidth;
        final rawTextMaxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth - metaWidth - _chatInlineMetaGap
            : double.infinity;
        final textMaxWidth = rawTextMaxWidth < 0 ? 0.0 : rawTextMaxWidth;

        final textPainter = TextPainter(
          text: TextSpan(text: text, style: userTextStyle),
          strutStyle: userStrutStyle,
          textDirection: direction,
          textScaler: textScaler,
        )..layout(maxWidth: textMaxWidth);

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(maxWidth: textMaxWidth),
              child: SelectableText(
                text,
                style: userTextStyle,
                strutStyle: userStrutStyle,
              ),
            ),
            const SizedBox(width: _chatInlineMetaGap),
            Padding(
              padding: EdgeInsets.only(top: textPainter.height),
              child: _UserMessageMeta(status: status, createdAt: createdAt),
            ),
          ],
        );
      },
    );
  }
}

class _ChatMarkdownText extends StatelessWidget {
  const _ChatMarkdownText({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final baseStyle = DefaultTextStyle.of(context).style;
    return MarkdownBody(
      data: text,
      selectable: true,
      shrinkWrap: true,
      softLineBreak: true,
      styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
        p: baseStyle,
        code: baseStyle.copyWith(
          fontFamily: 'monospace',
          backgroundColor: AppUiPalette.surfaceStrong,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppUiPalette.surfaceStrong,
          borderRadius: BorderRadius.circular(6),
        ),
        blockquoteDecoration: BoxDecoration(
          color: AppUiPalette.surfaceMuted,
          border: Border(
            left: BorderSide(color: AppUiPalette.borderStrong, width: 3),
          ),
        ),
      ),
    );
  }
}

bool _looksLikeMarkdown(String text) {
  if (text.trim().isEmpty) {
    return false;
  }
  final markdownSignal = RegExp(
    r'(^|\n)\s{0,3}(#{1,6}\s|[-*+]\s|\d+\.\s|>|```)|(\*\*|__|`|\[.+\]\(.+\)|\n)',
    multiLine: true,
  );
  return markdownSignal.hasMatch(text);
}

bool _isLargeAssistantMarkdown(String text) {
  if (!_looksLikeMarkdown(text)) {
    return false;
  }
  return _isOversizedText(text);
}

bool _isOversizedText(String text) {
  final lineCount = '\n'.allMatches(text).length + 1;
  return text.length > _longMarkdownCharThreshold ||
      lineCount > _longMarkdownLineThreshold;
}

String _collapsedMarkdownPreview(String text) {
  final lines = text.split('\n');
  final visibleLines = lines.length > _collapsedMarkdownPreviewLineLimit
      ? lines.sublist(0, _collapsedMarkdownPreviewLineLimit)
      : lines;
  var preview = visibleLines.join('\n');
  if (preview.length > _collapsedMarkdownPreviewCharLimit) {
    preview = preview.substring(0, _collapsedMarkdownPreviewCharLimit); // coverage:ignore-line
  }

  if (preview.length < text.length || visibleLines.length < lines.length) {
    preview = '$preview\n…';
  }
  return preview;
}

class _UserMessageMeta extends StatelessWidget {
  const _UserMessageMeta({required this.status, required this.createdAt});

  final ChatMessageStatus status;
  final DateTime createdAt;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _formatMessageTime(createdAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(width: 4),
        _MessageStatusTick(status: status),
      ],
    );
  }
}

class _MessageStatusTick extends StatelessWidget {
  const _MessageStatusTick({required this.status});

  final ChatMessageStatus status;

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ChatMessageStatus.pending:
        return Icon(
          Icons.schedule,
          size: 14,
          color: AppUiPalette.textSecondary,
        );
      case ChatMessageStatus.accepted:
        return Icon(Icons.done, size: 14, color: AppUiPalette.textSecondary);
      case ChatMessageStatus.delivered:
        return Icon(Icons.done_all, size: 16, color: AppUiPalette.accent);
      case ChatMessageStatus.failed:
        return Icon(Icons.error_outline, size: 14, color: Colors.red.shade700);
    }
  }
}

String _formatMessageTime(DateTime timestamp) {
  final local = timestamp.toLocal();
  final hh = local.hour.toString().padLeft(2, '0');
  final mm = local.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class _MediaPanel extends StatelessWidget {
  const _MediaPanel({
    required this.message,
    required this.mediaResource,
    required this.onRetryMediaLoad,
    required this.onDownloadMedia,
  });

  final ChatMessageEntity message;
  final ChatMediaResourceState? mediaResource;
  final VoidCallback onRetryMediaLoad;
  final VoidCallback onDownloadMedia;

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    if (media == null) {
      return const SizedBox.shrink();
    }
    final mediaUrl = media.url.trim();

    final hasLocalPreview =
        mediaResource?.objectUrl != null &&
        mediaResource!.objectUrl!.trim().isNotEmpty;

    if (message.role == ChatMessageRole.user &&
        mediaUrl.isNotEmpty &&
        !hasLocalPreview) {
      return _MediaPreview(
        messageType: message.type,
        objectUrl: mediaUrl,
        mimeType: media.mimeType,
        filename: media.filename,
        useThumbnail: true,
      );
    }

    if (message.role == ChatMessageRole.user &&
        mediaUrl.isEmpty &&
        !hasLocalPreview) {
      return _AttachmentSummary(
        filename: media.filename ?? 'Attachment',
        mimeType: media.mimeType,
      );
    }

    if (mediaResource == null || mediaResource!.isLoading) {
      return Row(
        children: const [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 8),
          Text('Loading preview...'),
        ],
      );
    }

    if (mediaResource!.errorMessage != null &&
        mediaResource!.errorMessage!.isNotEmpty) {
      return Row(
        children: [
          Expanded(
            child: Text(
              mediaResource!.errorMessage!,
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          TextButton(onPressed: onRetryMediaLoad, child: const Text('Retry')),
        ],
      );
    }

    final objectUrl = mediaResource!.objectUrl;
    if (objectUrl == null || objectUrl.isEmpty) {
      return const Text('Media is unavailable.');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MediaPreview(
          messageType: message.type,
          objectUrl: objectUrl,
          mimeType: mediaResource!.mimeType,
          filename: mediaResource!.filename,
          textPreview: mediaResource!.textPreview,
          pdfPageAspectRatio: mediaResource!.pdfPageAspectRatio,
          spreadsheetPreview: mediaResource!.spreadsheetPreview,
          useThumbnail: message.role == ChatMessageRole.user,
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          widthFactor: 1,
          child: OutlinedButton.icon(
            onPressed: onDownloadMedia,
            icon: const Icon(Icons.download),
            label: Text(
              mediaResource!.filename?.trim().isNotEmpty ?? false
                  ? 'Download ${mediaResource!.filename}'
                  : 'Download',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }
}

class _AttachmentSummary extends StatelessWidget {
  const _AttachmentSummary({required this.filename, this.mimeType});

  final String filename;
  final String? mimeType;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiPalette.borderStrong),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              mimeType == null ? filename : '$filename (${mimeType!})',
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _UserAttachmentCue extends StatelessWidget {
  const _UserAttachmentCue({
    required this.messageId,
    required this.media,
    required this.messageType,
  });

  final String messageId;
  final ChatMediaEntity media;
  final ChatMessageType messageType;

  @override
  Widget build(BuildContext context) {
    final filename = media.filename?.trim();
    final typeLabel = switch (messageType) {
      ChatMessageType.image => 'image',
      ChatMessageType.audio => 'audio',
      ChatMessageType.video => 'video',
      ChatMessageType.file => 'file',
      ChatMessageType.text => 'attachment',
    };
    final label = (filename != null && filename.isNotEmpty)
        ? 'Attachment: $filename'
        : 'Attached $typeLabel';

    return Align(
      alignment: Alignment.centerLeft,
      widthFactor: 1,
      child: Container(
        key: ValueKey<String>('$_userAttachmentCueKeyPrefix$messageId'),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppUiPalette.surface,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppUiPalette.borderStrong),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.attach_file,
              size: 13,
              color: AppUiPalette.textSecondary,
            ),
            const SizedBox(width: 4),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 11,
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MediaPreview extends StatelessWidget {
  const _MediaPreview({
    required this.messageType,
    required this.objectUrl,
    this.mimeType,
    this.filename,
    this.textPreview,
    this.pdfPageAspectRatio,
    this.spreadsheetPreview,
    this.useThumbnail = false,
  });

  final ChatMessageType messageType;
  final String objectUrl;
  final String? mimeType;
  final String? filename;
  final String? textPreview;
  final double? pdfPageAspectRatio;
  final ChatSpreadsheetPreview? spreadsheetPreview;
  final bool useThumbnail;

  @override
  Widget build(BuildContext context) {
    final normalizedMime = _normalizeMimeType(mimeType);

    switch (messageType) {
      case ChatMessageType.image:
        if (useThumbnail) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              key: const Key('chat-image-thumbnail'),
              width: _uploadedImageThumbnailSize,
              height: _uploadedImageThumbnailSize,
              child: Image.network(
                objectUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) {
                  return const Text('Image preview unavailable.');
                },
              ),
            ),
          );
        }
        // coverage:ignore-start
        return ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: Image.network(
              objectUrl,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) {
                return const Text('Image preview unavailable.');
              },
            ),
          ),
        );
        // coverage:ignore-end
      case ChatMessageType.audio:
        return _HtmlPreview(
          tagName: 'audio',
          objectUrl: objectUrl,
          height: 54,
          configure: (element) { // coverage:ignore-start
            element.controls = true;
            element.src = objectUrl;
          },
          // coverage:ignore-end
        );
      case ChatMessageType.video:
        return _VideoPreview(objectUrl: objectUrl);
      case ChatMessageType.file:
        if (normalizedMime == 'application/pdf') {
          return _PdfPreviewCard(
            filename: filename,
            pageAspectRatio: pdfPageAspectRatio,
          );
        }
        if (_isSpreadsheetMimeType(normalizedMime, filename: filename)) {
          return _SpreadsheetFilePreview(preview: spreadsheetPreview);
        }
        if (_isTextMimeType(normalizedMime ?? '')) {
          return _TextFilePreview(previewText: textPreview);
        }
        return _UnsupportedFilePreview(filename: filename, mimeType: mimeType);
      case ChatMessageType.text:
        return const SizedBox.shrink();
    }
  }
}

class _TextFilePreview extends StatelessWidget {
  const _TextFilePreview({required this.previewText});

  static const double _minPreviewWidth = 220;
  static const double _maxPreviewWidth = 520;

  final String? previewText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final resolvedText = previewText;
    final textStyle = theme.textTheme.bodySmall?.copyWith(
      fontFamily: 'monospace',
      height: 1.35,
    );
    final contentText = resolvedText == null
        ? null
        : (resolvedText.isEmpty ? '(empty file)' : resolvedText);
    final previewWidth = _estimateTextPreviewWidth(
      context: context,
      text: contentText ?? 'Inline preview unavailable.',
      style: textStyle,
    );
    Widget content;
    if (contentText == null) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text(
          'Inline preview unavailable in secure mode.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
        ),
      );
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
          child: SelectableText(contentText, style: textStyle),
        ),
      );
    }

    return Container(
      width: previewWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: AppUiPalette.surfaceMuted,
              border: Border(bottom: BorderSide(color: AppUiPalette.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.description_outlined,
                  size: 14,
                  color: AppUiPalette.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  'Text file preview',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppUiPalette.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          content,
        ],
      ),
    );
  }
}

class _SpreadsheetFilePreview extends StatelessWidget {
  const _SpreadsheetFilePreview({required this.preview});

  static const double _previewWidth = 520;
  static const double _minColumnWidth = 90;
  static const double _maxColumnWidth = 160;

  final ChatSpreadsheetPreview? preview;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectivePreview = preview;
    final rows = effectivePreview?.rows ?? const <List<String>>[];

    Widget content;
    if (effectivePreview == null) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text(
          'Inline preview unavailable in secure mode.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
        ),
      );
    } else if (rows.isEmpty) {
      content = Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Text(
          '(empty sheet)',
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppUiPalette.textSecondary,
          ),
        ),
      );
    } else {
      content = ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 220),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Table(
              defaultColumnWidth: const IntrinsicColumnWidth(),
              border: TableBorder.all(
                color: AppUiPalette.border,
                width: 1,
                borderRadius: BorderRadius.circular(6),
              ),
              children: [
                for (var rowIndex = 0; rowIndex < rows.length; rowIndex += 1)
                  TableRow(
                    decoration: BoxDecoration(
                      color: rowIndex == 0
                          ? AppUiPalette.surfaceMuted
                          : Colors.white,
                    ),
                    children: [
                      for (final cellValue in rows[rowIndex])
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: _minColumnWidth,
                            maxWidth: _maxColumnWidth,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 6,
                            ),
                            child: Text(
                              cellValue,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      );
    }

    final sheetName = effectivePreview?.sheetName.trim().isNotEmpty ?? false
        ? effectivePreview!.sheetName.trim()
        : 'Sheet';
    final hasTruncation =
        effectivePreview != null &&
        (effectivePreview.truncatedRows || effectivePreview.truncatedColumns);

    return Container(
      width: _previewWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: const BoxDecoration(
              color: AppUiPalette.surfaceMuted,
              border: Border(bottom: BorderSide(color: AppUiPalette.border)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  size: 14,
                  color: AppUiPalette.textSecondary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Spreadsheet preview',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppUiPalette.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  sheetName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: AppUiPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          content,
          if (hasTruncation)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: Text(
                'Showing a trimmed worksheet preview.',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

double _estimateTextPreviewWidth({
  required BuildContext context,
  required String text,
  required TextStyle? style,
}) {
  final lines = text.split('\n');
  var longestLine = '';
  final sampleCount = math.min(lines.length, 40);
  for (var i = 0; i < sampleCount; i += 1) {
    final line = lines[i];
    if (line.length > longestLine.length) {
      longestLine = line;
    }
  }

  final probeText = longestLine.isEmpty ? '(empty file)' : longestLine;
  final painter = TextPainter(
    text: TextSpan(text: probeText, style: style),
    textDirection: Directionality.of(context),
    maxLines: 1,
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: _TextFilePreview._maxPreviewWidth);

  const sidePaddingAndChrome = 12 + 12 + 20;
  final rawWidth = painter.width + sidePaddingAndChrome;
  return rawWidth.clamp(
    _TextFilePreview._minPreviewWidth,
    _TextFilePreview._maxPreviewWidth,
  );
}

class _PdfPreviewCard extends StatelessWidget {
  const _PdfPreviewCard({this.filename, this.pageAspectRatio});

  static const double _previewWidth = 220;
  static const double _minPreviewHeight = 150;
  static const double _maxPreviewHeight = 320;
  static const double _defaultPageAspectRatio = 595 / 842;

  final String? filename;
  final double? pageAspectRatio;

  @override
  Widget build(BuildContext context) {
    final normalizedRatio = (pageAspectRatio != null && pageAspectRatio! > 0)
        ? pageAspectRatio!
        : _defaultPageAspectRatio;
    final height = (_previewWidth / normalizedRatio).clamp(
      _minPreviewHeight,
      _maxPreviewHeight,
    );

    return Container(
      width: _previewWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: _previewWidth,
            height: height,
            decoration: const BoxDecoration(
              color: AppUiPalette.surfaceMuted,
              border: Border(bottom: BorderSide(color: AppUiPalette.border)),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.picture_as_pdf_outlined,
                  size: 28,
                  color: AppUiPalette.textSecondary,
                ),
                const SizedBox(height: 6),
                Text(
                  'PDF Preview Disabled',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppUiPalette.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Secure mode',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppUiPalette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (filename != null && filename!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Text(
                filename!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _UnsupportedFilePreview extends StatelessWidget {
  const _UnsupportedFilePreview({this.filename, this.mimeType});

  final String? filename;
  final String? mimeType;

  @override
  Widget build(BuildContext context) {
    final effectiveLabel = filename?.trim().isNotEmpty ?? false
        ? filename!.trim() // coverage:ignore-line
        : (mimeType?.trim().isNotEmpty ?? false ? mimeType!.trim() : 'file');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppUiPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppUiPalette.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.insert_drive_file_outlined,
            size: 16,
            color: AppUiPalette.textSecondary,
          ),
          const SizedBox(width: 8),
          Text(
            'No inline preview: $effectiveLabel',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppUiPalette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  const _VideoPreview({required this.objectUrl});

  final String objectUrl;

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  static const double _maxWidth = 520;
  static const double _maxHeight = 420;
  static const double _minHeight = 180;
  static const double _defaultAspectRatio = 16 / 9;

  double _aspectRatio = _defaultAspectRatio;

  @override // coverage:ignore-start
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.objectUrl == widget.objectUrl) {
      return;
    }

    _aspectRatio = _defaultAspectRatio;
  }
  // coverage:ignore-end

  @override
  Widget build(BuildContext context) {
    final previewSize = _fitVideoPreviewSize(
      aspectRatio: _aspectRatio,
      maxWidth: _maxWidth,
      maxHeight: _maxHeight,
      minHeight: _minHeight,
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: previewSize.width,
        height: previewSize.height,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppUiPalette.border),
        ),
        child: _HtmlPreview(
          tagName: 'video',
          objectUrl: widget.objectUrl,
          width: previewSize.width,
          height: previewSize.height,
          configure: (element) { // coverage:ignore-start
            element.controls = true;
            element.preload = 'metadata';
            element.src = widget.objectUrl;
            element.style.width = '100%';
            element.style.height = '100%';
            element.style.objectFit = 'contain';
            element.style.backgroundColor = '#000';
            element.onloadedmetadata = (_) {
              final rawWidth = _parsePreviewDimension(element.videoWidth);
              final rawHeight = _parsePreviewDimension(element.videoHeight);
              if (rawWidth == null ||
                  rawHeight == null ||
                  rawWidth <= 0 ||
                  rawHeight <= 0) {
                return;
              }

              final ratio = (rawWidth / rawHeight).clamp(0.2, 5.0);
              if (!mounted || (ratio - _aspectRatio).abs() < 0.01) {
                return;
              }
              setState(() {
                _aspectRatio = ratio;
              });
            };
          },
          // coverage:ignore-end
        ),
      ),
    );
  }
}

double? _parsePreviewDimension(dynamic value) { // coverage:ignore-start
  if (value is num) {
    return value.toDouble();
  }

  return double.tryParse('$value');
}
// coverage:ignore-end

Size _fitVideoPreviewSize({
  required double aspectRatio,
  required double maxWidth,
  required double maxHeight,
  required double minHeight,
}) {
  final normalizedRatio = (aspectRatio.isFinite && aspectRatio > 0)
      ? aspectRatio
      : 16 / 9; // coverage:ignore-line

  var width = maxWidth;
  var height = width / normalizedRatio;

  if (height > maxHeight) {
    height = maxHeight;
    width = height * normalizedRatio; // coverage:ignore-line
  }

  if (height < minHeight) {
    height = minHeight;
    width = height * normalizedRatio; // coverage:ignore-line
    if (width > maxWidth) { // coverage:ignore-line
      width = maxWidth; // coverage:ignore-line
      height = width / normalizedRatio; // coverage:ignore-line
    }
  }

  return Size(width, height);
}

String? _normalizeMimeType(String? mimeType) {
  final value = mimeType?.split(';').first.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

bool _isTextMimeType(String normalizedMime) {
  if (normalizedMime.startsWith('text/')) {
    return true;
  }

  return normalizedMime == 'application/json' ||
      normalizedMime == 'application/xml' ||
      normalizedMime == 'application/javascript' ||
      normalizedMime == 'application/x-javascript';
}

bool _isSpreadsheetMimeType(String? normalizedMime, {String? filename}) {
  final normalizedFilename = filename?.trim().toLowerCase() ?? '';
  final hasSpreadsheetExtension =
      normalizedFilename.endsWith('.xlsx') ||
      normalizedFilename.endsWith('.xlsm');

  if (normalizedMime == null || normalizedMime.isEmpty) {
    return hasSpreadsheetExtension;
  }

  return normalizedMime ==
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' ||
      normalizedMime == 'application/vnd.ms-excel.sheet.macroenabled.12' ||
      hasSpreadsheetExtension;
}

class _HtmlPreview extends StatelessWidget {
  const _HtmlPreview({
    required this.tagName,
    required this.objectUrl,
    this.width = 520,
    required this.height,
    required this.configure,
  });

  final String tagName;
  final String objectUrl;
  final double width;
  final double height;
  final void Function(dynamic element) configure;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) {
      return const Text('Preview available on web builds.');
    }

    return SizedBox( // coverage:ignore-start
      height: height,
      width: width,
      child: HtmlElementView.fromTagName(
        tagName: tagName,
        onElementCreated: (element) => configure(element),
      ),
    );
    // coverage:ignore-end
  }
}
