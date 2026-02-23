import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';

const String _reportsRoute = 'reports';
const Key _shellAccountMenuTriggerKey = Key('shell-account-menu-trigger');
const Key _shellAccountMenuSettingsKey = Key('shell-account-menu-settings');
const Key _shellAccountMenuLogoutKey = Key('shell-account-menu-logout');
const Key _shellAccountSettingsPanelAccountKey = Key(
  'shell-account-settings-panel-account',
);
const Key _shellAccountSettingsPanelUsersKey = Key(
  'shell-account-settings-panel-users',
);

void main() {
  testWidgets('user bar title follows active SPA route', (tester) async {
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(
        drawerItems: <DrawerItemConfig>[
          DrawerItemConfig(
            title: 'Reports',
            icon: Icons.dashboard_outlined,
            route: _reportsRoute,
          ),
        ],
        spaDefaultRoute: _reportsRoute,
        spaRoutes: <SpaRouteConfig>[
          SpaRouteConfig(id: _reportsRoute, title: 'Reports'),
        ],
      ),
    );
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: _reportsRoute,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const Key('shell-user-bar-title')),
    );
    expect(title.data, 'Reports');
  });

  testWidgets('user bar title shows Settings while settings panel is open', (
    tester,
  ) async {
    final config = AppConfig.defaults().merge(
      const AppConfigurationOverride(
        drawerItems: <DrawerItemConfig>[
          DrawerItemConfig(
            title: 'Reports',
            icon: Icons.dashboard_outlined,
            route: _reportsRoute,
          ),
        ],
        spaDefaultRoute: _reportsRoute,
        spaRoutes: <SpaRouteConfig>[
          SpaRouteConfig(id: _reportsRoute, title: 'Reports'),
        ],
      ),
    );
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: true,
        activeRoute: _reportsRoute,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    final title = tester.widget<Text>(
      find.byKey(const Key('shell-user-bar-title')),
    );
    expect(title.data, 'Settings');
  });

  testWidgets(
    'user bar shows connection indicator next to AI Assist on chat route',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.chat,
        ),
      );
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: null,
        ),
      );
      final chatController = _TestChatController(
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
            appConfigProvider.overrideWith((ref) => config),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.byKey(const Key('shell-user-bar-title')),
      );
      expect(title.data, 'AI Assist');
      expect(find.text('Connected'), findsOneWidget);
      expect(find.byKey(const Key('shell-replay-resync-badge')), findsNothing);
    },
  );

  testWidgets('account menu trigger shows avatar initials and display name', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'alice',
          username: 'Alice Doe',
          roles: <String>[],
        ),
      ),
    );
    final chatController = _TestChatController(
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
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(_shellAccountMenuTriggerKey), findsOneWidget);
    expect(find.text('Alice Doe'), findsOneWidget);
    expect(find.text('AD'), findsOneWidget);
  });

  testWidgets('drawer shows Platform Configuration section for admin tools', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'admin-1',
          roles: <String>['com.vorsocomputing.mugen.acp:administrator'],
        ),
      ),
    );
    final chatController = _TestChatController(
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
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform Configuration'), findsOneWidget);
    expect(find.text('Local Users'), findsOneWidget);
  });

  testWidgets('account menu opens and shows settings and logout actions', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    final chatController = _TestChatController(
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
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_shellAccountMenuSettingsKey), findsOneWidget);
    expect(find.byKey(_shellAccountMenuLogoutKey), findsOneWidget);
  });

  testWidgets('selecting settings from account menu opens settings dropdown', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    final chatController = _TestChatController(
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
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_shellAccountMenuSettingsKey));
    await tester.pumpAndSettle();

    expect(find.byKey(_shellAccountSettingsPanelAccountKey), findsOneWidget);
    expect(find.byKey(_shellAccountSettingsPanelUsersKey), findsNothing);
    expect(find.text('Reset Password'), findsWidgets);
  });

  testWidgets(
    'selecting account settings panel opens the account overlay dialog',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.chat,
        ),
      );
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'user-1',
            roles: <String>[],
          ),
        ),
      );
      final chatController = _TestChatController(
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
            appConfigProvider.overrideWith((ref) => config),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shellAccountMenuSettingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shellAccountSettingsPanelAccountKey));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Reset Password'), findsWidgets);
    },
  );

  testWidgets(
    'selecting settings from account menu does not change shell route title',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.chat,
        ),
      );
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: null,
        ),
      );
      final chatController = _TestChatController(
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
            appConfigProvider.overrideWith((ref) => config),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shellAccountMenuSettingsKey));
      await tester.pumpAndSettle();

      final title = tester.widget<Text>(
        find.byKey(const Key('shell-user-bar-title')),
      );
      expect(title.data, 'AI Assist');
    },
  );

  testWidgets('selecting logout from account menu logs out and navigates', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: <String>[],
        ),
      ),
    );
    final chatController = _TestChatController(
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
    final navigator = _FakeAppNavigator();

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
          appNavigatorProvider.overrideWith((ref) => navigator),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(_shellAccountMenuLogoutKey));
    await tester.pumpAndSettle();

    expect(authController.logoutCallCount, 1);
    expect(navigator.lastRoute, RouteIds.login);
    expect(navigator.navigateCallCount, 1);
  });

  testWidgets(
    'user bar shows replay resync badge on chat route when notice is active',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.chat,
        ),
      );
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: null,
        ),
      );
      final chatController = _TestChatController(
        initialState: ChatControllerState(
          conversationId: 'conv-test',
          messages: const <ChatMessageEntity>[],
          mediaResources: const <String, ChatMediaResourceState>{},
          attachments: const <ChatAttachmentDraft>[],
          compositionMode: ChatCompositionMode.messageWithAttachments,
          isConnected: true,
          isConnecting: false,
          isSending: false,
          replayNoticeText: 'Replay resynced',
          replayNoticeReason: 'stale_cursor',
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWith((ref) => config),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Connected'), findsOneWidget);
      expect(
        find.byKey(const Key('shell-replay-resync-badge')),
        findsOneWidget,
      );
    },
  );

  testWidgets('user bar hides replay resync badge when notice is not active', (
    tester,
  ) async {
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );
    final chatController = _TestChatController(
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
          appConfigProvider.overrideWith((ref) => config),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('shell-replay-resync-badge')), findsNothing);
  });
}

class _TestShellController extends ShellController {
  _TestShellController({required this.initialState});

  final ShellState initialState;

  @override
  ShellState build() => initialState;
}

class _TestAuthController extends AuthController {
  _TestAuthController({required this.initialState});

  final AuthControllerState initialState;
  int logoutCallCount = 0;

  @override
  AuthControllerState build() => initialState;

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) => true;

  @override
  Future<bool> logout() async {
    logoutCallCount += 1;
    return true;
  }
}

class _TestChatController extends ChatController {
  _TestChatController({required this.initialState});

  final ChatControllerState initialState;

  @override
  ChatControllerState build() => initialState;

  @override
  void ensureStreaming() {}
}

class _FakeAppNavigator extends AppNavigator {
  String? lastRoute;
  int navigateCallCount = 0;

  @override
  Future<void> navigateTo(String routeName) async {
    navigateCallCount += 1;
    lastRoute = routeName;
  }
}
