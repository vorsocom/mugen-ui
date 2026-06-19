import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_media_entity.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/presentation/pages/chat_page.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

const Key _composerAttachButtonKey = Key('chat-composer-attach-button');
const Key _composerSendButtonKey = Key('chat-composer-send-button');
const Key _composerInputFieldKey = Key('chat-composer-input');
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

void main() {
  testWidgets('send button is disabled while sending', (tester) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: true,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );

    final input = find.byKey(_composerInputFieldKey);
    await tester.enterText(input, 'sending');
    await tester.pump();

    final sendButton = tester.widget<IconButton>(
      find.byKey(_composerSendButtonKey),
    );
    expect(sendButton.onPressed, isNull);
  });

  testWidgets('send button enables only after typing a message', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );

    var sendButton = tester.widget<IconButton>(
      find.byKey(_composerSendButtonKey),
    );
    expect(sendButton.onPressed, isNull);

    await tester.enterText(find.byKey(_composerInputFieldKey), 'hello');
    await tester.pumpAndSettle();

    sendButton = tester.widget<IconButton>(find.byKey(_composerSendButtonKey));
    expect(sendButton.onPressed, isNotNull);
  });

  testWidgets('chat errors render as an alert above the composer', (
    tester,
  ) async {
    const errorMessage =
        "403 Forbidden: You don't have the permission to access the requested resource.";
    final controller = _TestChatController(
      initialState: const ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
        errorMessage: errorMessage,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );

    expect(find.byType(AppErrorAlert), findsOneWidget);
    expect(find.text(errorMessage), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(AppErrorAlert)).dy,
      lessThan(tester.getTopLeft(find.byKey(_composerInputFieldKey)).dy),
    );
  });

  testWidgets('attachment can be selected and sent with text', (tester) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );

    await tester.tap(find.byKey(_composerAttachButtonKey));
    await tester.pumpAndSettle();
    expect(find.textContaining('mock.txt'), findsOneWidget);

    await tester.enterText(find.byKey(_composerInputFieldKey), 'with file');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_composerSendButtonKey));
    await tester.pumpAndSettle();

    expect(find.text('with file'), findsOneWidget);
    expect(find.byTooltip('Remove attachment'), findsNothing);
  });

  testWidgets('text and attachment rows render without connector linkage', (
    tester,
  ) async {
    const clientMessageId = 'client-attach-pair';
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[
          ChatMessageEntity(
            id: 'user-text-1',
            role: ChatMessageRole.user,
            type: ChatMessageType.text,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 5),
            text: 'Text with attachment',
            clientMessageId: clientMessageId,
          ),
          ChatMessageEntity(
            id: 'user-image-1',
            role: ChatMessageRole.user,
            type: ChatMessageType.image,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 5),
            media: const ChatMediaEntity(
              url: '',
              mimeType: 'image/png',
              filename: 'photo.png',
            ),
            clientMessageId: clientMessageId,
          ),
        ],
        mediaResources: const <String, ChatMediaResourceState>{
          'user-image-1': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://photo',
            mimeType: 'image/png',
            filename: 'photo.png',
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text with attachment'), findsOneWidget);
    expect(find.textContaining('Attachment: photo.png'), findsOneWidget);
    expect(
      find.byKey(
        const ValueKey<String>('chat-attachment-link-arrow-user-text-1'),
      ),
      findsNothing,
    );
  });

  testWidgets(
    'caption mode keeps send disabled until attachment caption is provided',
    (tester) async {
      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[],
          mediaResources: <String, ChatMediaResourceState>{},
          attachments: <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );

      await tester.tap(find.byKey(_composerAttachButtonKey));
      await tester.pumpAndSettle();

      expect(find.byKey(_composerModeToggleKey), findsOneWidget);
      await tester.tap(find.text('Caption per file'));
      await tester.pumpAndSettle();

      var sendButton = tester.widget<IconButton>(
        find.byKey(_composerSendButtonKey),
      );
      expect(sendButton.onPressed, isNull);

      await tester.enterText(
        find.byKey(const ValueKey('chat-caption-att-1')),
        'Attachment caption',
      );
      await tester.pumpAndSettle();

      sendButton = tester.widget<IconButton>(
        find.byKey(_composerSendButtonKey),
      );
      expect(sendButton.onPressed, isNotNull);
    },
  );

  testWidgets('pressing Enter sends message', (tester) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );

    final input = find.byKey(_composerInputFieldKey);
    await tester.tap(input);
    await tester.pumpAndSettle();
    await tester.enterText(input, 'hello enter');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();

    expect(find.text('hello enter'), findsOneWidget);
  });

  testWidgets('initial render shows only recent transcript window', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: _buildManyAssistantMessages(120, prefix: 'window'),
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('window message 0'), findsNothing);
    expect(find.text('window message 119'), findsOneWidget);
  });

  testWidgets('load older prepends chunk while preserving viewport anchor', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: _buildManyAssistantMessages(121, prefix: 'older'),
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(_loadOlderMessagesButtonKey), findsOneWidget);

    final beforePixels = scrollable.position.pixels;
    final beforeMax = scrollable.position.maxScrollExtent;

    await tester.tap(find.byKey(_loadOlderMessagesButtonKey));
    await tester.pumpAndSettle();

    final afterPixels = scrollable.position.pixels;
    final afterMax = scrollable.position.maxScrollExtent;
    final expectedAfter = beforePixels + (afterMax - beforeMax);
    expect((afterPixels - expectedAfter).abs(), lessThan(80));

    scrollable.position.jumpTo(scrollable.position.minScrollExtent);
    await tester.pumpAndSettle();
    expect(find.byKey(_loadOlderMessagesButtonKey), findsOneWidget);
    await tester.tap(find.byKey(_loadOlderMessagesButtonKey));
    await tester.pumpAndSettle();
    expect(find.byKey(_loadOlderMessagesButtonKey), findsNothing);
  });

  testWidgets('long assistant response auto-scrolls to user prompt region', (
    tester,
  ) async {
    final transcript = _buildScrollableTranscript();
    const promptClientMessageId = 'client-latest';
    transcript.add(
      ChatMessageEntity(
        id: 'user-latest',
        role: ChatMessageRole.user,
        type: ChatMessageType.text,
        status: ChatMessageStatus.delivered,
        createdAt: DateTime.utc(2026, 1, 1, 14, 0),
        text: 'Latest user prompt',
        clientMessageId: promptClientMessageId,
      ),
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: transcript,
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    controller.appendMessage(
      ChatMessageEntity(
        id: 'assistant-long',
        role: ChatMessageRole.assistant,
        type: ChatMessageType.text,
        status: ChatMessageStatus.delivered,
        createdAt: DateTime.utc(2026, 1, 1, 14, 1),
        text: List<String>.generate(220, (index) => 'Line $index').join('\n'),
        clientMessageId: promptClientMessageId,
      ),
    );
    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).first,
    );
    final distanceFromBottom =
        scrollable.position.maxScrollExtent - scrollable.position.pixels;
    expect(distanceFromBottom, greaterThan(120));
    final transcriptRect = tester.getRect(find.byType(ListView));
    final latestPromptRect = tester.getRect(find.text('Latest user prompt'));
    expect(latestPromptRect.top, greaterThanOrEqualTo(transcriptRect.top - 2));
    expect(latestPromptRect.top, lessThanOrEqualTo(transcriptRect.top + 120));
    expect(find.byKey(_scrollToBottomButtonKey), findsOneWidget);
  });

  testWidgets('scroll-to-bottom button appears after scrolling up', (
    tester,
  ) async {
    final messages = List<ChatMessageEntity>.generate(50, (index) {
      return ChatMessageEntity(
        id: 'assistant-$index',
        role: ChatMessageRole.assistant,
        type: ChatMessageType.text,
        status: ChatMessageStatus.delivered,
        createdAt: DateTime.utc(2026, 1, 1, 12, index % 60),
        text: 'message $index ' * 12,
      );
    });
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: messages,
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_scrollToBottomButtonKey), findsNothing);

    await tester.drag(find.byType(ListView), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(find.byKey(_scrollToBottomButtonKey), findsOneWidget);

    await tester.tap(find.byKey(_scrollToBottomButtonKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_scrollToBottomButtonKey), findsNothing);
  });

  testWidgets('large assistant markdown collapses until expanded', (
    tester,
  ) async {
    final largeMarkdown = List<String>.generate(
      140,
      (index) => '- markdown line $index',
    ).join('\n');
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[
          ChatMessageEntity(
            id: 'assistant-large-markdown',
            role: ChatMessageRole.assistant,
            type: ChatMessageType.text,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 2),
            text: largeMarkdown,
          ),
        ],
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Show full response'), findsOneWidget);
    expect(find.byType(MarkdownBody), findsNothing);

    final expandButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Show full response'),
    );
    expandButton.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('Collapse'), findsOneWidget);
  });

  testWidgets('thinking indicator is visible when connected and active', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
        activeThinkingKeys: <String>{'job:42'},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pump();

    expect(find.text('Assistant is thinking...'), findsOneWidget);
  });

  testWidgets('thinking indicator is hidden while disconnected', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[],
        mediaResources: <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: false,
        isConnecting: false,
        isSending: false,
        activeThinkingKeys: <String>{'job:42'},
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pump();

    expect(find.text('Assistant is thinking...'), findsNothing);
  });

  testWidgets(
    'expanded layout constrains chat content to a centered 960px column',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[],
          mediaResources: <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedColumn = find.byKey(
        const Key('chat-page-content-column'),
      );
      expect(constrainedColumn, findsOneWidget);

      final rect = tester.getRect(constrainedColumn);
      expect(rect.width, 960);
      expect(rect.center.dx, moreOrLessEquals(800, epsilon: 0.01));
    },
  );

  testWidgets(
    'narrow layout keeps chat content full-width without overflow cap',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(700, 900));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[],
          mediaResources: <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      final constrainedColumn = find.byKey(
        const Key('chat-page-content-column'),
      );
      expect(constrainedColumn, findsOneWidget);

      final rect = tester.getRect(constrainedColumn);
      expect(rect.width, 700);
      expect(rect.center.dx, moreOrLessEquals(350, epsilon: 0.01));
    },
  );

  testWidgets(
    'assistant shows content and timestamp, user shows tick metadata',
    (tester) async {
      final messages = <ChatMessageEntity>[
        ChatMessageEntity(
          id: 'user-1',
          role: ChatMessageRole.user,
          type: ChatMessageType.text,
          status: ChatMessageStatus.delivered,
          createdAt: DateTime.utc(2026, 1, 1, 12, 0),
          text: 'user text',
        ),
        ChatMessageEntity(
          id: 'assistant-1',
          role: ChatMessageRole.assistant,
          type: ChatMessageType.text,
          status: ChatMessageStatus.delivered,
          createdAt: DateTime.utc(2026, 1, 1, 12, 1),
          text: 'assistant text',
        ),
      ];
      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: messages,
          mediaResources: const <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('user text'), findsOneWidget);
      expect(find.text('assistant text'), findsOneWidget);
      expect(find.byIcon(Icons.done_all), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.data != null &&
              RegExp(r'^\d{2}:\d{2}$').hasMatch(widget.data!),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Accepted'), findsNothing);
      expect(find.text('Delivered'), findsNothing);
    },
  );

  testWidgets('assistant media row shows secure PDF card and download action', (
    tester,
  ) async {
    final mediaMessage = ChatMessageEntity(
      id: 'assistant-1',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.file,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1),
      media: const ChatMediaEntity(
        url: '/api/core/web/v1/media/token',
        mimeType: 'application/pdf',
        filename: 'report.pdf',
      ),
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[mediaMessage],
        mediaResources: const <String, ChatMediaResourceState>{
          'assistant-1': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://report',
            mimeType: 'application/pdf',
            filename: 'report.pdf',
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('PDF Preview Disabled'), findsOneWidget);
    expect(find.textContaining('Download report.pdf'), findsOneWidget);
  });

  testWidgets('assistant text file row renders file preview card', (
    tester,
  ) async {
    final mediaMessage = ChatMessageEntity(
      id: 'assistant-text-file-1',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.file,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1),
      media: const ChatMediaEntity(
        url: '/api/core/web/v1/media/token-text',
        mimeType: 'text/plain',
        filename: 'sample.txt',
      ),
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[mediaMessage],
        mediaResources: const <String, ChatMediaResourceState>{
          'assistant-text-file-1': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://sample-text',
            mimeType: 'text/plain',
            filename: 'sample.txt',
            textPreview: 'This is a test file.',
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Text file preview'), findsOneWidget);
    expect(find.text('This is a test file.'), findsOneWidget);
    expect(find.textContaining('Download sample.txt'), findsOneWidget);
  });

  testWidgets('assistant xlsx file row renders spreadsheet preview card', (
    tester,
  ) async {
    final mediaMessage = ChatMessageEntity(
      id: 'assistant-xlsx-file-1',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.file,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1),
      media: const ChatMediaEntity(
        url: '/api/core/web/v1/media/token-xlsx',
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
        filename: 'sample.xlsx',
      ),
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[mediaMessage],
        mediaResources: const <String, ChatMediaResourceState>{
          'assistant-xlsx-file-1': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://sample-xlsx',
            mimeType:
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            filename: 'sample.xlsx',
            spreadsheetPreview: ChatSpreadsheetPreview(
              sheetName: 'Sheet1',
              rows: <List<String>>[
                <String>['Name', 'Value'],
                <String>['CPU', '42'],
              ],
              truncatedRows: false,
              truncatedColumns: false,
            ),
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Spreadsheet preview'), findsOneWidget);
    expect(find.text('Sheet1'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(find.text('CPU'), findsOneWidget);
    expect(find.textContaining('Download sample.xlsx'), findsOneWidget);
  });

  testWidgets('video preview uses web element on browser builds', (
    tester,
  ) async {
    final mediaMessage = ChatMessageEntity(
      id: 'assistant-video-1',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.video,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1),
      media: const ChatMediaEntity(
        url: '/api/core/web/v1/media/token-video',
        mimeType: 'video/mp4',
        filename: 'sample.mp4',
      ),
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[mediaMessage],
        mediaResources: const <String, ChatMediaResourceState>{
          'assistant-video-1': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://sample-video',
            mimeType: 'video/mp4',
            filename: 'sample.mp4',
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    if (kIsWeb) {
      expect(find.text('Preview available on web builds.'), findsNothing);
    } else {
      expect(find.text('Preview available on web builds.'), findsOneWidget);
    }
    expect(find.textContaining('Download sample.mp4'), findsOneWidget);
  });

  testWidgets('markdown text renders with MarkdownBody inside bubble', (
    tester,
  ) async {
    final markdownMessage = ChatMessageEntity(
      id: 'assistant-md-1',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.text,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1, 12, 2),
      text: '**bold** item\n- one',
    );

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[markdownMessage],
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(MarkdownBody), findsOneWidget);
    expect(find.text('one'), findsOneWidget);
  });

  testWidgets(
    'user image with inline data url renders preview after reload state restore',
    (tester) async {
      const inlinePng =
          'data:image/png;base64,'
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO6s8kQAAAAASUVORK5CYII=';
      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[
            ChatMessageEntity(
              id: 'user-image-inline',
              role: ChatMessageRole.user,
              type: ChatMessageType.image,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1),
              media: const ChatMediaEntity(
                url: inlinePng,
                mimeType: 'image/png',
                filename: 'inline.png',
              ),
            ),
          ],
          mediaResources: const <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Loading preview...'), findsNothing);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byKey(const Key('chat-image-thumbnail')), findsOneWidget);
      expect(
        find.byKey(
          const ValueKey<String>(
            '${_userAttachmentCueKeyPrefix}user-image-inline',
          ),
        ),
        findsOneWidget,
      );
      expect(find.text('Attachment: inline.png'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('chat-image-thumbnail'))),
        const Size(120, 120),
      );
    },
  );

  testWidgets('assistant media rows trigger ensure/retry/download callbacks', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1400, 1400));
    addTearDown(() async {
      await tester.binding.setSurfaceSize(null);
    });

    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[
          ChatMessageEntity(
            id: 'assistant-load',
            role: ChatMessageRole.assistant,
            type: ChatMessageType.file,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 10),
            media: const ChatMediaEntity(
              url: '/api/core/web/v1/media/load',
              mimeType: 'application/pdf',
              filename: 'load.pdf',
            ),
          ),
          ChatMessageEntity(
            id: 'assistant-error',
            role: ChatMessageRole.assistant,
            type: ChatMessageType.file,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 11),
            media: const ChatMediaEntity(
              url: '/api/core/web/v1/media/error',
              mimeType: 'application/pdf',
              filename: 'error.pdf',
            ),
          ),
          ChatMessageEntity(
            id: 'assistant-ready',
            role: ChatMessageRole.assistant,
            type: ChatMessageType.file,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 12),
            media: const ChatMediaEntity(
              url: '/api/core/web/v1/media/ready',
              mimeType: 'application/pdf',
              filename: 'report.pdf',
            ),
          ),
        ],
        mediaResources: const <String, ChatMediaResourceState>{
          'assistant-error': ChatMediaResourceState(
            isLoading: false,
            errorMessage: 'load failed',
          ),
          'assistant-ready': ChatMediaResourceState(
            isLoading: false,
            objectUrl: 'blob://ready',
            mimeType: 'application/pdf',
            filename: 'report.pdf',
            pdfPageAspectRatio: 1.2,
          ),
        },
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pump();

    expect(controller.ensureMediaLoadedCallCount, 1);
    expect(controller.lastEnsureMediaLoadedMessageId, 'assistant-load');
    expect(find.text('load failed'), findsOneWidget);

    final retryButton = tester.widget<TextButton>(
      find.widgetWithText(TextButton, 'Retry'),
    );
    retryButton.onPressed!.call();
    await tester.pump();
    expect(controller.retryMediaLoadCallCount, 1);
    expect(controller.lastRetryMediaLoadMessageId, 'assistant-error');

    final downloadButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Download report.pdf'),
    );
    downloadButton.onPressed!.call();
    await tester.pump();
    expect(controller.downloadMediaCallCount, 1);
    expect(controller.lastDownloadMediaMessageId, 'assistant-ready');
  });

  testWidgets(
    'system/error role labels and markdown user statuses render expected indicators',
    (tester) async {
      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[
            ChatMessageEntity(
              id: 'system-1',
              role: ChatMessageRole.system,
              type: ChatMessageType.text,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 0),
              text: '**Maintenance** active',
            ),
            ChatMessageEntity(
              id: 'error-1',
              role: ChatMessageRole.error,
              type: ChatMessageType.text,
              status: ChatMessageStatus.failed,
              createdAt: DateTime.utc(2026, 1, 1, 12, 1),
              text: '`Failure` detail',
            ),
            ChatMessageEntity(
              id: 'user-pending-md',
              role: ChatMessageRole.user,
              type: ChatMessageType.text,
              status: ChatMessageStatus.pending,
              createdAt: DateTime.utc(2026, 1, 1, 12, 2),
              text: '- pending',
            ),
            ChatMessageEntity(
              id: 'user-accepted-md',
              role: ChatMessageRole.user,
              type: ChatMessageType.text,
              status: ChatMessageStatus.accepted,
              createdAt: DateTime.utc(2026, 1, 1, 12, 3),
              text: '- accepted',
            ),
            ChatMessageEntity(
              id: 'user-failed-md',
              role: ChatMessageRole.user,
              type: ChatMessageType.text,
              status: ChatMessageStatus.failed,
              createdAt: DateTime.utc(2026, 1, 1, 12, 4),
              text: '- failed',
            ),
          ],
          mediaResources: const <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Error'), findsOneWidget);
      expect(find.byIcon(Icons.schedule), findsOneWidget);
      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    },
  );

  testWidgets(
    'user and assistant file previews render summary, type cues, and fallback cards',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 2600));
      addTearDown(() async {
        await tester.binding.setSurfaceSize(null);
      });

      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: <ChatMessageEntity>[
            ChatMessageEntity(
              id: 'user-summary',
              role: ChatMessageRole.user,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 20),
              media: const ChatMediaEntity(
                url: '',
                mimeType: 'application/msword',
                filename: 'draft.docx',
              ),
            ),
            ChatMessageEntity(
              id: 'user-audio',
              role: ChatMessageRole.user,
              type: ChatMessageType.audio,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 21),
              media: const ChatMediaEntity(
                url: 'blob://audio',
                mimeType: 'audio/wav',
              ),
            ),
            ChatMessageEntity(
              id: 'user-video',
              role: ChatMessageRole.user,
              type: ChatMessageType.video,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 22),
              media: const ChatMediaEntity(
                url: 'blob://video',
                mimeType: 'video/mp4',
              ),
            ),
            ChatMessageEntity(
              id: 'user-file',
              role: ChatMessageRole.user,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 23),
              media: const ChatMediaEntity(
                url: 'blob://bin',
                mimeType: 'application/octet-stream',
              ),
            ),
            ChatMessageEntity(
              id: 'user-text-with-media',
              role: ChatMessageRole.user,
              type: ChatMessageType.text,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 24),
              media: const ChatMediaEntity(
                url: 'blob://text',
                mimeType: 'application/octet-stream',
              ),
            ),
            ChatMessageEntity(
              id: 'assistant-text-null',
              role: ChatMessageRole.assistant,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 25),
              media: const ChatMediaEntity(
                url: '/media/text-null',
                mimeType: 'text/plain',
                filename: 'notes.txt',
              ),
            ),
            ChatMessageEntity(
              id: 'assistant-sheet-null',
              role: ChatMessageRole.assistant,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 26),
              media: const ChatMediaEntity(
                url: '/media/sheet-null',
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                filename: 'null.xlsx',
              ),
            ),
            ChatMessageEntity(
              id: 'assistant-sheet-empty',
              role: ChatMessageRole.assistant,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 27),
              media: const ChatMediaEntity(
                url: '/media/sheet-empty',
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                filename: 'empty.xlsx',
              ),
            ),
            ChatMessageEntity(
              id: 'assistant-sheet-trim',
              role: ChatMessageRole.assistant,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 28),
              media: const ChatMediaEntity(
                url: '/media/sheet-trim',
                mimeType:
                    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                filename: 'trim.xlsx',
              ),
            ),
            ChatMessageEntity(
              id: 'assistant-unsupported',
              role: ChatMessageRole.assistant,
              type: ChatMessageType.file,
              status: ChatMessageStatus.delivered,
              createdAt: DateTime.utc(2026, 1, 1, 12, 29),
              media: const ChatMediaEntity(
                url: '/media/unsupported',
                mimeType: 'application/octet-stream',
              ),
            ),
          ],
          mediaResources: const <String, ChatMediaResourceState>{
            'assistant-text-null': ChatMediaResourceState(
              isLoading: false,
              objectUrl: 'blob://text-null',
              mimeType: 'text/plain',
              filename: 'notes.txt',
              textPreview: null,
            ),
            'assistant-sheet-null': ChatMediaResourceState(
              isLoading: false,
              objectUrl: 'blob://sheet-null',
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              filename: 'null.xlsx',
              spreadsheetPreview: null,
            ),
            'assistant-sheet-empty': ChatMediaResourceState(
              isLoading: false,
              objectUrl: 'blob://sheet-empty',
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              filename: 'empty.xlsx',
              spreadsheetPreview: ChatSpreadsheetPreview(
                sheetName: 'Sheet1',
                rows: <List<String>>[],
                truncatedRows: false,
                truncatedColumns: false,
              ),
            ),
            'assistant-sheet-trim': ChatMediaResourceState(
              isLoading: false,
              objectUrl: 'blob://sheet-trim',
              mimeType:
                  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              filename: 'trim.xlsx',
              spreadsheetPreview: ChatSpreadsheetPreview(
                sheetName: 'Sheet1',
                rows: <List<String>>[
                  <String>['ColA'],
                  <String>['Value'],
                ],
                truncatedRows: true,
                truncatedColumns: false,
              ),
            ),
            'assistant-unsupported': ChatMediaResourceState(
              isLoading: false,
              objectUrl: 'blob://unsupported',
              mimeType: 'application/octet-stream',
            ),
          },
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('draft.docx'), findsWidgets);
      expect(find.text('Attached audio'), findsOneWidget);
      expect(find.text('Attached video'), findsOneWidget);
      expect(find.text('Attached file'), findsOneWidget);
      expect(find.text('Attached attachment'), findsOneWidget);
      expect(
        find.text('No inline preview: application/octet-stream'),
        findsWidgets,
      );
      expect(
        find.text('Inline preview unavailable in secure mode.'),
        findsWidgets,
      );
      expect(find.text('(empty sheet)'), findsOneWidget);
      expect(find.text('Showing a trimmed worksheet preview.'), findsOneWidget);
    },
  );

  testWidgets(
    'long assistant response uses job-id anchor when client id is absent',
    (tester) async {
      final transcript = _buildScrollableTranscript();
      transcript.add(
        ChatMessageEntity(
          id: 'user-job-anchor',
          role: ChatMessageRole.user,
          type: ChatMessageType.text,
          status: ChatMessageStatus.delivered,
          createdAt: DateTime.utc(2026, 1, 1, 14, 0),
          text: 'Job anchored prompt',
          jobId: 'job-anchor',
        ),
      );

      final controller = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: transcript,
          mediaResources: const <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            chatControllerProvider.overrideWith(() => controller),
          ],
          child: const MaterialApp(home: Scaffold(body: ChatPage())),
        ),
      );
      await tester.pumpAndSettle();

      controller.appendMessage(
        ChatMessageEntity(
          id: 'assistant-job-anchor',
          role: ChatMessageRole.assistant,
          type: ChatMessageType.text,
          status: ChatMessageStatus.delivered,
          createdAt: DateTime.utc(2026, 1, 1, 14, 1),
          text: List<String>.generate(220, (index) => 'Line $index').join('\n'),
          jobId: 'job-anchor',
        ),
      );
      await tester.pumpAndSettle();

      final transcriptRect = tester.getRect(find.byType(ListView));
      final promptRect = tester.getRect(find.text('Job anchored prompt'));
      expect(promptRect.top, greaterThanOrEqualTo(transcriptRect.top - 2));
      expect(promptRect.top, lessThanOrEqualTo(transcriptRect.top + 120));
    },
  );

  testWidgets('clear transcript requires confirmation and can be cancelled', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[
          ChatMessageEntity(
            id: 'user-1',
            role: ChatMessageRole.user,
            type: ChatMessageType.text,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 0),
            text: 'Keep me',
          ),
        ],
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_clearTranscriptButtonKey));
    await tester.pumpAndSettle();
    expect(find.text('Clear transcript?'), findsOneWidget);

    await tester.tap(find.byKey(_clearTranscriptCancelButtonKey));
    await tester.pumpAndSettle();

    expect(controller.clearTranscriptCallCount, 0);
    expect(find.text('Keep me'), findsOneWidget);
  });

  testWidgets('clear transcript confirmation clears UI and shows alert', (
    tester,
  ) async {
    final controller = _TestChatController(
      initialState: ChatControllerState(
        conversationId: 'conv-test',
        messages: <ChatMessageEntity>[
          ChatMessageEntity(
            id: 'user-1',
            role: ChatMessageRole.user,
            type: ChatMessageType.text,
            status: ChatMessageStatus.delivered,
            createdAt: DateTime.utc(2026, 1, 1, 12, 0),
            text: 'Clear me',
          ),
        ],
        mediaResources: const <String, ChatMediaResourceState>{},
        attachments: const <ChatAttachmentDraft>[],
        compositionMode: ChatCompositionMode.messageWithAttachments,
        isConnected: true,
        isConnecting: false,
        isSending: false,
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          chatControllerProvider.overrideWith(() => controller),
        ],
        child: const MaterialApp(home: Scaffold(body: ChatPage())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_clearTranscriptButtonKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_clearTranscriptConfirmButtonKey));
    await tester.pumpAndSettle();

    expect(controller.clearTranscriptCallCount, 1);
    expect(find.text('Clear me'), findsNothing);
    expect(find.text('Transcript cleared locally.'), findsOneWidget);
  });
}

List<ChatMessageEntity> _buildManyAssistantMessages(
  int count, {
  required String prefix,
}) {
  return List<ChatMessageEntity>.generate(count, (index) {
    return ChatMessageEntity(
      id: '$prefix-assistant-$index',
      role: ChatMessageRole.assistant,
      type: ChatMessageType.text,
      status: ChatMessageStatus.delivered,
      createdAt: DateTime.utc(2026, 1, 1, 11, index % 60),
      text: '$prefix message $index',
    );
  });
}

List<ChatMessageEntity> _buildScrollableTranscript() {
  final transcript = <ChatMessageEntity>[];
  for (var index = 0; index < 14; index++) {
    final clientId = 'client-$index';
    transcript.add(
      ChatMessageEntity(
        id: 'user-$index',
        role: ChatMessageRole.user,
        type: ChatMessageType.text,
        status: ChatMessageStatus.delivered,
        createdAt: DateTime.utc(2026, 1, 1, 12, index),
        text: 'User message $index',
        clientMessageId: clientId,
      ),
    );
    transcript.add(
      ChatMessageEntity(
        id: 'assistant-$index',
        role: ChatMessageRole.assistant,
        type: ChatMessageType.text,
        status: ChatMessageStatus.delivered,
        createdAt: DateTime.utc(2026, 1, 1, 12, index, 30),
        text: 'Assistant message $index',
        clientMessageId: clientId,
      ),
    );
  }
  return transcript;
}

class _TestChatController extends ChatController {
  _TestChatController({required this.initialState});

  final ChatControllerState initialState;
  int _counter = 0;
  int clearTranscriptCallCount = 0;
  int ensureMediaLoadedCallCount = 0;
  int retryMediaLoadCallCount = 0;
  int downloadMediaCallCount = 0;
  String? lastEnsureMediaLoadedMessageId;
  String? lastRetryMediaLoadMessageId;
  String? lastDownloadMediaMessageId;

  @override
  ChatControllerState build() {
    return initialState;
  }

  @override
  void ensureStreaming() {}

  @override
  Future<void> attachFromPicker() async {
    _counter += 1;
    state = state.copyWith(
      attachments: <ChatAttachmentDraft>[
        ...state.attachments,
        ChatAttachmentDraft(
          id: 'att-$_counter',
          filename: 'mock.txt',
          mimeType: 'text/plain',
          bytes: Uint8List.fromList(<int>[1, 2, 3]),
        ),
      ],
    );
  }

  @override
  Future<bool> sendMessage(String rawText) async {
    final text = rawText.trim();
    if (text.isEmpty && state.attachments.isEmpty) {
      return false;
    }

    _counter += 1;
    final messageText = text.isEmpty
        ? 'Uploaded ${state.attachments.first.filename}'
        : text;
    state = state.copyWith(
      clearAttachments: true,
      messages: <ChatMessageEntity>[
        ...state.messages,
        ChatMessageEntity(
          id: 'local-$_counter',
          role: ChatMessageRole.user,
          type: ChatMessageType.text,
          status: ChatMessageStatus.delivered,
          createdAt: DateTime.now().toUtc(),
          text: messageText,
        ),
      ],
    );
    return true;
  }

  @override
  Future<void> ensureMediaLoaded(String messageId) async {
    ensureMediaLoadedCallCount += 1;
    lastEnsureMediaLoadedMessageId = messageId;
  }

  @override
  Future<void> retryMediaLoad(String messageId) async {
    retryMediaLoadCallCount += 1;
    lastRetryMediaLoadMessageId = messageId;
  }

  @override
  Future<void> downloadMediaToDevice(String messageId) async {
    downloadMediaCallCount += 1;
    lastDownloadMediaMessageId = messageId;
  }

  @override
  void clearTranscript() {
    clearTranscriptCallCount += 1;
    state = state.copyWith(
      messages: const <ChatMessageEntity>[],
      mediaResources: const <String, ChatMediaResourceState>{},
      clearAttachments: true,
      clearActiveThinkingKeys: true,
      clearReplayNotice: true,
      clearErrorMessage: true,
    );
  }

  void appendMessage(ChatMessageEntity message) {
    state = state.copyWith(
      messages: <ChatMessageEntity>[...state.messages, message],
    );
  }
}
