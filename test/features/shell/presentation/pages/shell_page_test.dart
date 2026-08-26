import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/edit_profile_panel.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/reset_password_panel.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_composition_mode.dart';
import 'package:mugen_ui/features/chat/domain/entities/chat_message_entity.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/features/human_handoff/application/dto/human_handoff_inputs.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_delivery_result_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_event_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_session_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_tenant_option_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/entities/human_handoff_transcript_item_entity.dart';
import 'package:mugen_ui/features/human_handoff/domain/repositories/human_handoff_repository.dart';
import 'package:mugen_ui/features/human_handoff/presentation/providers/human_handoff_providers.dart';
import 'package:mugen_ui/features/shell/presentation/pages/shell_page.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/features/user_admin/application/dto/delete_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/edit_user_roles_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/revoke_user_session_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/toggle_user_account_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/update_user_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_registration_input.dart';
import 'package:mugen_ui/features/user_admin/application/dto/user_reset_password_admin_input.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_session_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/entities/user_role_entity.dart';
import 'package:mugen_ui/features/user_admin/domain/repositories/user_admin_repository.dart';
import 'package:mugen_ui/features/user_admin/presentation/providers/user_admin_providers.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/shared/application/pagination.dart';
import 'package:mugen_ui/shared/application/query_models.dart';
import 'package:mugen_ui/shared/domain/failure.dart';
import 'package:mugen_ui/shared/domain/result.dart';
import 'package:mugen_ui/shared/domain/value_objects/auth_session.dart';
import 'package:mugen_ui/shared/presentation/navigation/app_navigator.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const String _reportsRoute = 'reports';
const Key _shellNoAccessibleRoutesKey = Key('shell-no-access-routes');
const Key _shellAccountMenuTriggerKey = Key('shell-account-menu-trigger');
const Key _shellAccountMenuSettingsKey = Key('shell-account-menu-settings');
const Key _shellAccountMenuLogoutKey = Key('shell-account-menu-logout');
const Key _shellAccountSettingsPanelAccountKey = Key(
  'shell-account-settings-panel-core.auth.account',
);
const Key _shellAccountSettingsPanelResetPasswordKey = Key(
  'shell-account-settings-panel-core.auth.reset_password',
);
const Key _shellAccountSettingsPanelUsersKey = Key(
  'shell-account-settings-panel-test.settings.local_users',
);
const Key _humanHandoffDrawerStatusKey = Key(
  'shell-human-handoff-status-chips',
);
const List<String> _webAccessRoles = <String>[webPlatformAccessRole];
const List<String> _authenticatedWebAccessRoles = <String>[
  'com.vorsocomputing.mugen.acp:authenticated',
  webPlatformAccessRole,
];

void main() {
  testWidgets(
    'expanded drawer title renders app name when browser title differs',
    (tester) async {
      final config = AppConfig.defaults().merge(
        const AppConfigurationOverride(
          appName: 'Redcell',
          browserTitle: 'Redcell Wargaming Console',
        ),
      );
      final definition = _buildShellTestDefinition(
        config: config,
        defaultShellRouteId: _reportsRoute,
        shellRoutes: const <ShellRouteDefinition>[
          ShellRouteDefinition(
            id: _reportsRoute,
            title: 'Reports',
            icon: Icons.dashboard_outlined,
            builder: _buildReportsPage,
          ),
        ],
      );
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: _reportsRoute,
        ),
      );
      final authController = _TestAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: null,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appDefinitionProvider.overrideWith((ref) => definition),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Redcell'), findsOneWidget);
      expect(find.text('Redcell Wargaming Console'), findsNothing);
      final drawer = tester.widget<Drawer>(find.byType(Drawer));
      expect(drawer.backgroundColor, AppUiPalette.drawer);
      final activeItem = tester.widget<AnimatedContainer>(
        find.byKey(const Key('shell-drawer-item-reports')),
      );
      final activeDecoration = activeItem.decoration! as BoxDecoration;
      expect(activeDecoration.color, AppUiPalette.drawerSelected);
      expect(
        (activeDecoration.border! as Border).left.color,
        AppUiPalette.accent,
      );
    },
  );

  testWidgets('user bar title follows active SPA route', (tester) async {
    final definition = _buildShellTestDefinition(
      defaultShellRouteId: _reportsRoute,
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: _reportsRoute,
          title: 'Reports',
          icon: Icons.dashboard_outlined,
          builder: _buildReportsPage,
        ),
      ],
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
          appDefinitionProvider.overrideWith((ref) => definition),
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
    final definition = _buildShellTestDefinition(
      defaultShellRouteId: _reportsRoute,
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: _reportsRoute,
          title: 'Reports',
          icon: Icons.dashboard_outlined,
          builder: _buildReportsPage,
        ),
      ],
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
          appDefinitionProvider.overrideWith((ref) => definition),
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
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'user-1',
            roles: _webAccessRoles,
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
    final authController = _RoleAwareAuthController(
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

  testWidgets('drawer groups Platform Configuration tools by admin task', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final config = AppConfig.defaults();
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.chat,
      ),
    );
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'admin-1',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:administrator',
            'com.vorsocomputing.mugen.human_handoff:operator',
            knowledgePackConfiguratorRole,
            webPlatformAccessRole,
          ],
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

    final aiAssistInDrawer = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('AI Assist'),
    );
    final humanHandoffInDrawer = find.descendant(
      of: find.byType(Drawer),
      matching: find.text('Human Handoff'),
    );
    expect(humanHandoffInDrawer, findsOneWidget);
    expect(
      tester.getTopLeft(humanHandoffInDrawer).dy,
      greaterThan(tester.getTopLeft(aiAssistInDrawer).dy),
    );
    expect(find.text('Platform Configuration'), findsOneWidget);
    expect(find.text('Identity & Access'), findsOneWidget);
    expect(find.text('Platform Capabilities'), findsOneWidget);
    expect(find.text('Operations & Governance'), findsOneWidget);
    expect(find.text('Developer'), findsOneWidget);
    expect(find.text('Local Users'), findsOneWidget);
    expect(find.text('Tenants'), findsOneWidget);
    expect(find.text('Roles & Permissions'), findsOneWidget);
    expect(find.text('Audit Events'), findsOneWidget);
    expect(find.text('Runtime Control'), findsOneWidget);
    expect(find.text('Channel Orchestration'), findsOneWidget);
    expect(find.text('Context Engine'), findsOneWidget);
    expect(find.text('Knowledge Packs'), findsOneWidget);
    expect(find.text('ACP Console'), findsOneWidget);

    double topOf(String label) => tester.getTopLeft(find.text(label)).dy;
    expect(topOf('Identity & Access'), lessThan(topOf('Tenants')));
    expect(topOf('Tenants'), lessThan(topOf('Local Users')));
    expect(topOf('Local Users'), lessThan(topOf('Roles & Permissions')));
    expect(
      topOf('Identity & Access'),
      lessThan(topOf('Platform Capabilities')),
    );
    expect(
      topOf('Platform Capabilities'),
      lessThan(topOf('Operations & Governance')),
    );
    expect(topOf('Operations & Governance'), lessThan(topOf('Developer')));
    expect(topOf('Runtime Control'), lessThan(topOf('Audit Events')));
  });

  testWidgets('drawer shows Knowledge Packs for configurator permission', (
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
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'knowledge-1',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:authenticated',
            knowledgePackConfiguratorRole,
            webPlatformAccessRole,
          ],
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
          humanHandoffRepositoryProvider.overrideWithValue(
            _FakeHumanHandoffRepository(),
          ),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Platform Configuration'), findsOneWidget);
    expect(find.text('Platform Capabilities'), findsOneWidget);
    expect(find.text('Identity & Access'), findsNothing);
    expect(find.text('Operations & Governance'), findsNothing);
    expect(find.text('Developer'), findsNothing);
    expect(find.text('Knowledge Packs'), findsOneWidget);
    expect(find.text('Local Users'), findsNothing);
    expect(find.text('Tenants'), findsNothing);
    expect(find.text('Roles & Permissions'), findsNothing);
    expect(find.text('Audit Events'), findsNothing);
  });

  testWidgets('drawer shows Human Handoff for dedicated operator permission', (
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
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'operator-1',
          username: 'Operator One',
          roles: <String>[
            'com.vorsocomputing.mugen.acp:authenticated',
            'com.vorsocomputing.mugen.human_handoff:operator',
            webPlatformAccessRole,
          ],
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
          humanHandoffRepositoryProvider.overrideWithValue(
            _FakeHumanHandoffRepository(),
          ),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Human Handoff'), findsOneWidget);
    expect(find.byKey(_humanHandoffDrawerStatusKey), findsOneWidget);
    expect(find.text('New 1'), findsOneWidget);
    expect(find.text('Open 2'), findsNothing);
    expect(find.text('Platform Configuration'), findsNothing);
    expect(find.text('Local Users'), findsNothing);
    expect(find.text('Tenants'), findsNothing);
    expect(find.text('Roles & Permissions'), findsNothing);
    expect(find.text('Audit Events'), findsNothing);
  });

  testWidgets('Human Handoff drawer chips show quiet live status', (
    tester,
  ) async {
    await _pumpHumanHandoffDrawer(
      tester,
      repository: _FakeHumanHandoffRepository(
        sessions: _buildDrawerHandoffSessions(hasNewActivity: false),
      ),
    );

    expect(find.byKey(_humanHandoffDrawerStatusKey), findsOneWidget);
    expect(find.text('Open 2'), findsOneWidget);
    expect(find.text('Live'), findsNothing);
  });

  testWidgets('Human Handoff drawer tooltip shows reconnecting stream status', (
    tester,
  ) async {
    await _pumpHumanHandoffDrawer(
      tester,
      repository: _FakeHumanHandoffRepository(
        completeLiveStream: true,
        sessions: _buildDrawerHandoffSessions(hasNewActivity: false),
      ),
    );

    expect(find.byKey(_humanHandoffDrawerStatusKey), findsOneWidget);
    expect(find.text('Open 2'), findsOneWidget);
    expect(find.text('Offline'), findsNothing);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(_humanHandoffDrawerStatusKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('live updates reconnecting'));
  });

  testWidgets('Human Handoff drawer chips prioritize failed deliveries', (
    tester,
  ) async {
    await _pumpHumanHandoffDrawer(
      tester,
      repository: _FakeHumanHandoffRepository(
        sessions: _buildDrawerHandoffSessions(
          hasNewActivity: false,
          hasFailure: true,
        ),
      ),
    );

    expect(find.byKey(_humanHandoffDrawerStatusKey), findsOneWidget);
    expect(find.text('Fail 1'), findsOneWidget);
    expect(find.text('Open 2'), findsNothing);
  });

  testWidgets('Human Handoff drawer suppresses transient stream issues', (
    tester,
  ) async {
    await _pumpHumanHandoffDrawer(
      tester,
      repository: _FakeHumanHandoffRepository(
        liveStreamFailuresBeforeSuccess: 1,
        sessions: _buildDrawerHandoffSessions(hasNewActivity: false),
      ),
    );

    expect(find.byKey(_humanHandoffDrawerStatusKey), findsOneWidget);
    expect(find.text('Issue'), findsNothing);
    expect(find.text('Open 2'), findsOneWidget);
    var tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(_humanHandoffDrawerStatusKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('live updates reconnecting'));
    expect(tooltip.message, contains('Last error: Live stream unavailable.'));

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('Issue'), findsNothing);
    expect(find.text('Open 2'), findsOneWidget);
    tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(_humanHandoffDrawerStatusKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('live updates live'));
    expect(tooltip.message, isNot(contains('Last error:')));
  });

  testWidgets('Human Handoff drawer shows one compact persistent issue badge', (
    tester,
  ) async {
    final longLiveError = 'Live stream unavailable. ${'detail ' * 30}';
    await _pumpHumanHandoffDrawer(
      tester,
      repository: _FakeHumanHandoffRepository(
        liveStreamFailuresBeforeSuccess: 3,
        liveStreamFailureMessage: longLiveError,
        sessions: _buildDrawerHandoffSessions(hasNewActivity: false),
      ),
    );

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(find.text('Issue'), findsOneWidget);
    expect(find.text('Open 2'), findsNothing);
    expect(find.text('Clear'), findsNothing);
    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(_humanHandoffDrawerStatusKey),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('live updates unavailable'));
    expect(tooltip.message, contains('Last error: Live stream unavailable.'));
    expect(tooltip.message, endsWith('…'));
    expect(tooltip.message, isNot(contains(longLiveError)));
    final statusSize = tester.getSize(find.byKey(_humanHandoffDrawerStatusKey));
    expect(statusSize.height, lessThanOrEqualTo(24));
    final title = tester.renderObject<RenderParagraph>(
      find.text('Human Handoff'),
    );
    final tileSize = tester.getSize(
      find.byKey(Key('shell-drawer-item-${RouteIds.humanHandoff}')),
    );
    expect(
      title.didExceedMaxLines,
      isFalse,
      reason:
          'title=${title.size}, intrinsic=${title.getMaxIntrinsicWidth(double.infinity)}, '
          'status=$statusSize, tile=$tileSize',
    );
  });

  testWidgets('drawer hides tenant admin routes for non-admin users', (
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
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: _authenticatedWebAccessRoles,
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

    expect(find.text('Human Handoff'), findsNothing);
    expect(find.text('Local Users'), findsNothing);
    expect(find.text('Tenants'), findsNothing);
    expect(find.text('Roles & Permissions'), findsNothing);
    expect(find.text('Audit Events'), findsNothing);
  });

  testWidgets('AI Assist is hidden when web access permission is missing', (
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
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
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

    final title = tester.widget<Text>(
      find.byKey(const Key('shell-user-bar-title')),
    );
    expect(title.data, 'Access Restricted');
    expect(find.byKey(_shellNoAccessibleRoutesKey), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(Drawer),
        matching: find.text('AI Assist'),
      ),
      findsNothing,
    );
    expect(find.text('Connected'), findsNothing);
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
    expect(
      find.byKey(_shellAccountSettingsPanelResetPasswordKey),
      findsOneWidget,
    );
    expect(find.byKey(_shellAccountSettingsPanelUsersKey), findsNothing);
    expect(find.text('Edit Profile'), findsOneWidget);
    expect(find.text('Reset Password'), findsOneWidget);
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
      expect(find.text('Edit Profile'), findsWidgets);
      expect(find.text('Current password'), findsNothing);
    },
  );

  testWidgets(
    'selecting reset-password panel opens the reset-password overlay dialog',
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
      await tester.tap(find.byKey(_shellAccountSettingsPanelResetPasswordKey));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('Current password'), findsOneWidget);
      expect(find.text('Save Profile'), findsNothing);
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
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'user-1',
            roles: _webAccessRoles,
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
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'user-1',
            roles: _webAccessRoles,
          ),
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
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: _webAccessRoles,
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

    expect(find.byKey(const Key('shell-replay-resync-badge')), findsNothing);
  });

  testWidgets('drawer toggle and nav item taps call shell controller actions', (
    tester,
  ) async {
    final definition = _buildShellTestDefinition(
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.chat,
          title: 'AI Assist',
          icon: Icons.chat_bubble_outline,
          builder: _buildPlaceholderShellPage,
        ),
        ShellRouteDefinition(
          id: RouteIds.localUsers,
          title: 'Local Users',
          icon: Icons.groups_outlined,
          section: 'Platform Configuration',
          builder: _buildPlaceholderShellPage,
        ),
      ],
    );
    final shellController = _TrackingShellController(
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
          appDefinitionProvider.overrideWith((ref) => definition),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Local Users'));
    await tester.pump();
    expect(shellController.lastRoute, RouteIds.localUsers);

    await tester.tap(find.byTooltip('Toggle drawer'));
    await tester.pump();
    expect(shellController.toggleCollapsedCalls, 1);
  });

  testWidgets('user bar connection indicator renders connecting state', (
    tester,
  ) async {
    Future<void> pumpWithChatState({
      required bool isConnected,
      required bool isConnecting,
    }) async {
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
            roles: _webAccessRoles,
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
          isConnected: isConnected,
          isConnecting: isConnecting,
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
    }

    await pumpWithChatState(isConnected: false, isConnecting: true);
    expect(find.text('Connecting...'), findsOneWidget);
  });

  testWidgets('route title follows registered shell route metadata', (
    tester,
  ) async {
    final definition = _buildShellTestDefinition(
      defaultShellRouteId: _reportsRoute,
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: _reportsRoute,
          title: 'Reports Route',
          icon: Icons.dashboard_outlined,
          builder: _buildReportsPage,
        ),
      ],
    );
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDefinitionProvider.overrideWith((ref) => definition),
          shellControllerProvider.overrideWith(
            () => _TestShellController(
              initialState: const ShellState(
                isDrawerCollapsed: false,
                showSettings: false,
                activeRoute: _reportsRoute,
              ),
            ),
          ),
          authControllerProvider.overrideWith(() => authController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    final routeTitle = tester.widget<Text>(
      find.byKey(const Key('shell-user-bar-title')),
    );
    expect(routeTitle.data, 'Reports Route');
  });

  testWidgets('route title falls back to active route when unresolved', (
    tester,
  ) async {
    final fallbackConfig = AppConfig.defaults();
    final authController = _TestAuthController(
      initialState: const AuthControllerState(isLoading: false, session: null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appConfigProvider.overrideWith((ref) => fallbackConfig),
          shellControllerProvider.overrideWith(
            () => _TestShellController(
              initialState: const ShellState(
                isDrawerCollapsed: false,
                showSettings: false,
                activeRoute: 'mystery-route',
              ),
            ),
          ),
          authControllerProvider.overrideWith(() => authController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    final fallbackTitle = tester.widget<Text>(
      find.byKey(const Key('shell-user-bar-title')),
    );
    expect(fallbackTitle.data, 'mystery-route');
  });

  testWidgets(
    'unauthorized seeded route redirects to fallback and shows snackbar',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.localUsers,
        ),
      );
      final authController = _RoleAwareAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'user-1',
            roles: _authenticatedWebAccessRoles,
          ),
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
      expect(shellController.state.activeRoute, RouteIds.chat);
      expect(
        find.text('You do not have access to that section.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'role loss on an active admin route revalidates to the fallback route',
    (tester) async {
      final config = AppConfig.defaults();
      final shellController = _TestShellController(
        initialState: const ShellState(
          isDrawerCollapsed: false,
          showSettings: false,
          activeRoute: RouteIds.localUsers,
        ),
      );
      final authController = _MutableRoleAwareAuthController(
        initialState: const AuthControllerState(
          isLoading: false,
          session: AuthSession(
            accessToken: 'token',
            refreshToken: 'refresh',
            userId: 'admin-1',
            roles: <String>[
              'com.vorsocomputing.mugen.acp:administrator',
              webPlatformAccessRole,
            ],
          ),
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
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appConfigProvider.overrideWith((ref) => config),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
            userAdminRepositoryProvider.overrideWithValue(
              _NoopUserAdminRepository(),
            ),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      final initialTitle = tester.widget<Text>(
        find.byKey(const Key('shell-user-bar-title')),
      );
      expect(initialTitle.data, 'Local Users');

      authController.setSession(
        const AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: _authenticatedWebAccessRoles,
        ),
      );
      await tester.pump();
      await tester.pumpAndSettle();

      final fallbackTitle = tester.widget<Text>(
        find.byKey(const Key('shell-user-bar-title')),
      );
      expect(fallbackTitle.data, 'AI Assist');
      expect(shellController.state.activeRoute, RouteIds.chat);
      expect(
        find.text('You do not have access to that section.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('locked-out users see the no-access shell state', (tester) async {
    final definition = _buildShellTestDefinition(
      defaultShellRouteId: RouteIds.runtimeControl,
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.runtimeControl,
          title: 'Runtime Control',
          icon: Icons.settings_input_component_outlined,
          section: 'Platform Configuration',
          requiredRoles: <String>['com.vorsocomputing.mugen.acp:administrator'],
          builder: _buildPlaceholderShellPage,
        ),
      ],
    );
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: false,
        showSettings: false,
        activeRoute: RouteIds.runtimeControl,
      ),
    );
    final authController = _RoleAwareAuthController(
      initialState: const AuthControllerState(
        isLoading: false,
        session: AuthSession(
          accessToken: 'token',
          refreshToken: 'refresh',
          userId: 'user-1',
          roles: <String>['com.vorsocomputing.mugen.acp:authenticated'],
        ),
      ),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          appDefinitionProvider.overrideWith((ref) => definition),
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
    expect(title.data, 'Access Restricted');
    expect(find.byKey(_shellNoAccessibleRoutesKey), findsOneWidget);
    expect(find.text('Runtime Control'), findsNothing);
    expect(find.text('You do not have access to that section.'), findsNothing);
  });

  testWidgets('replay badge tooltip maps generation_mismatch reason', (
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
          roles: _webAccessRoles,
        ),
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
        replayNoticeReason: 'generation_mismatch',
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

    final generationTooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('shell-replay-resync-badge')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(generationTooltip.message, contains('generation changed'));
  });

  testWidgets('replay badge tooltip maps log_rollover reason', (tester) async {
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
          roles: _webAccessRoles,
        ),
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
        replayNoticeReason: 'log_rollover',
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

    final rolloverTooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('shell-replay-resync-badge')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(rolloverTooltip.message, contains('Event log rolled over'));
  });

  testWidgets('replay badge tooltip maps cursor_unavailable reason', (
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
          roles: _webAccessRoles,
        ),
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
        replayNoticeReason: 'cursor_unavailable',
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

    final tooltip = tester.widget<Tooltip>(
      find.ancestor(
        of: find.byKey(const Key('shell-replay-resync-badge')),
        matching: find.byType(Tooltip),
      ),
    );
    expect(tooltip.message, contains('cursor was unavailable'));
  });

  testWidgets('collapsed drawer renders section divider and item tooltips', (
    tester,
  ) async {
    final definition = _buildShellTestDefinition(
      shellRoutes: const <ShellRouteDefinition>[
        ShellRouteDefinition(
          id: RouteIds.chat,
          title: 'Chat',
          icon: Icons.chat_bubble_outline,
          builder: _buildPlaceholderShellPage,
        ),
        ShellRouteDefinition(
          id: RouteIds.localUsers,
          title: 'Local Users',
          icon: Icons.groups_outlined,
          section: 'Platform Configuration',
          group: 'Identity & Access',
          builder: _buildPlaceholderShellPage,
        ),
        ShellRouteDefinition(
          id: RouteIds.acpConsole,
          title: 'ACP Console',
          icon: Icons.data_object_outlined,
          section: 'Platform Configuration',
          group: 'Developer',
          builder: _buildPlaceholderShellPage,
        ),
      ],
    );
    final shellController = _TestShellController(
      initialState: const ShellState(
        isDrawerCollapsed: true,
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
        messages: const <ChatMessageEntity>[],
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
          appDefinitionProvider.overrideWith((ref) => definition),
          shellControllerProvider.overrideWith(() => shellController),
          authControllerProvider.overrideWith(() => authController),
          chatControllerProvider.overrideWith(() => chatController),
        ],
        child: const MaterialApp(home: ShellPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(Divider), findsWidgets);
    expect(find.byTooltip('Local Users'), findsOneWidget);
    expect(find.byTooltip('ACP Console'), findsOneWidget);
    expect(find.text('Identity & Access'), findsNothing);
    expect(find.text('Developer'), findsNothing);
  });

  testWidgets(
    'users settings panel opens dialog with header and close action',
    (tester) async {
      final definition = _buildShellTestDefinition(
        settingsPanels: const <SettingsPanelDefinition>[
          SettingsPanelDefinition(
            id: 'test.settings.local_users',
            title: 'Local Users',
            icon: Icons.groups_outlined,
            builder: _buildLocalUsersPanel,
          ),
        ],
      );
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
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appDefinitionProvider.overrideWith((ref) => definition),
            shellControllerProvider.overrideWith(() => shellController),
            authControllerProvider.overrideWith(() => authController),
            chatControllerProvider.overrideWith(() => chatController),
            userAdminRepositoryProvider.overrideWithValue(
              _NoopUserAdminRepository(),
            ),
          ],
          child: const MaterialApp(home: ShellPage()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(_shellAccountMenuTriggerKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shellAccountMenuSettingsKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(_shellAccountSettingsPanelUsersKey));
      await tester.pumpAndSettle();

      expect(find.text('Local Users'), findsWidgets);
      expect(find.byType(Dialog), findsOneWidget);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );
}

Future<void> _pumpHumanHandoffDrawer(
  WidgetTester tester, {
  required _FakeHumanHandoffRepository repository,
}) async {
  final config = AppConfig.defaults();
  final shellController = _TestShellController(
    initialState: const ShellState(
      isDrawerCollapsed: false,
      showSettings: false,
      activeRoute: RouteIds.chat,
    ),
  );
  final authController = _RoleAwareAuthController(
    initialState: const AuthControllerState(
      isLoading: false,
      session: AuthSession(
        accessToken: 'token',
        refreshToken: 'refresh',
        userId: 'operator-1',
        username: 'Operator One',
        roles: <String>[
          'com.vorsocomputing.mugen.acp:authenticated',
          'com.vorsocomputing.mugen.human_handoff:operator',
          webPlatformAccessRole,
        ],
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
        humanHandoffRepositoryProvider.overrideWithValue(repository),
      ],
      child: const MaterialApp(home: ShellPage()),
    ),
  );
  await tester.pumpAndSettle();
}

MugenUiAppDefinition _buildShellTestDefinition({
  AppConfig? config,
  String defaultShellRouteId = RouteIds.chat,
  List<ShellRouteDefinition>? shellRoutes,
  List<SettingsPanelDefinition>? settingsPanels,
}) {
  return MugenUiAppDefinition(
    config: config ?? AppConfig.defaults(),
    defaultShellRouteId: defaultShellRouteId,
    modules: <MugenUiModule>[
      MugenUiModule(
        id: 'test.shell',
        shellRoutes:
            shellRoutes ??
            const <ShellRouteDefinition>[
              ShellRouteDefinition(
                id: RouteIds.chat,
                title: 'AI Assist',
                icon: Icons.chat_bubble_outline,
                builder: _buildPlaceholderShellPage,
              ),
              ShellRouteDefinition(
                id: RouteIds.humanHandoff,
                title: 'Human Handoff',
                icon: Icons.support_agent_outlined,
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.human_handoff:operator',
                ],
                builder: _buildPlaceholderShellPage,
              ),
              ShellRouteDefinition(
                id: RouteIds.localUsers,
                title: 'Local Users',
                icon: Icons.groups_outlined,
                section: 'Platform Configuration',
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:administrator',
                ],
                builder: _buildPlaceholderShellPage,
              ),
              ShellRouteDefinition(
                id: RouteIds.tenantManagement,
                title: 'Tenants',
                icon: Icons.apartment_outlined,
                section: 'Platform Configuration',
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:administrator',
                ],
                builder: _buildPlaceholderShellPage,
              ),
              ShellRouteDefinition(
                id: RouteIds.rolePermissionManagement,
                title: 'Roles & Permissions',
                icon: Icons.admin_panel_settings_outlined,
                section: 'Platform Configuration',
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:administrator',
                ],
                builder: _buildPlaceholderShellPage,
              ),
              ShellRouteDefinition(
                id: RouteIds.auditManagement,
                title: 'Audit Events',
                icon: Icons.fact_check_outlined,
                section: 'Platform Configuration',
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:administrator',
                ],
                builder: _buildPlaceholderShellPage,
              ),
            ],
      ),
      MugenUiModule(
        id: 'test.settings',
        settingsPanels:
            settingsPanels ??
            const <SettingsPanelDefinition>[
              SettingsPanelDefinition(
                id: 'core.auth.account',
                title: 'Edit Profile',
                icon: Icons.person_outline,
                builder: _buildEditProfilePanel,
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:authenticated',
                ],
                showHeader: false,
                expandBody: false,
              ),
              SettingsPanelDefinition(
                id: 'core.auth.reset_password',
                title: 'Reset Password',
                icon: Icons.security,
                builder: _buildResetPasswordPanel,
                requiredRoles: <String>[
                  'com.vorsocomputing.mugen.acp:authenticated',
                ],
                maxHeight: 620,
                showHeader: false,
                expandBody: false,
              ),
            ],
      ),
    ],
  );
}

Widget _buildPlaceholderShellPage(BuildContext context) {
  return const SizedBox.shrink();
}

Widget _buildReportsPage(BuildContext context) {
  return const SizedBox.shrink();
}

Widget _buildEditProfilePanel(BuildContext context) {
  return const EditProfilePanel();
}

Widget _buildResetPasswordPanel(BuildContext context) {
  return const ResetPasswordPanel();
}

Widget _buildLocalUsersPanel(BuildContext context) {
  return const LocalUserPanel();
}

class _TestShellController extends ShellController {
  _TestShellController({required this.initialState});

  final ShellState initialState;

  @override
  ShellState build() => initialState;
}

class _TrackingShellController extends ShellController {
  _TrackingShellController({required this.initialState});

  final ShellState initialState;
  int toggleCollapsedCalls = 0;
  String? lastRoute;

  @override
  ShellState build() => initialState;

  @override
  void toggleCollapsed() {
    toggleCollapsedCalls += 1;
    super.toggleCollapsed();
  }

  @override
  void setRoute(String route) {
    lastRoute = route;
    super.setRoute(route);
  }
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

class _RoleAwareAuthController extends _TestAuthController {
  _RoleAwareAuthController({required super.initialState});

  @override
  bool hasRoles(List<String> roles, {String operator = 'and'}) {
    final sessionRoles = state.session?.roles ?? const <String>[];
    if (roles.isEmpty) {
      return true;
    }

    if (operator.toLowerCase() == 'or') {
      return roles.any(sessionRoles.contains);
    }

    return roles.every(sessionRoles.contains);
  }
}

class _MutableRoleAwareAuthController extends _RoleAwareAuthController {
  _MutableRoleAwareAuthController({required super.initialState});

  void setSession(AuthSession? session) {
    state = AuthControllerState(isLoading: false, session: session);
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

class _FakeHumanHandoffRepository implements HumanHandoffRepository {
  _FakeHumanHandoffRepository({
    List<HumanHandoffSessionEntity>? sessions,
    this.completeLiveStream = false,
    this.liveStreamFailuresBeforeSuccess = 0,
    this.liveStreamFailureMessage = 'Live stream unavailable.',
  }) : sessions = sessions ?? _buildDrawerHandoffSessions();

  final List<HumanHandoffSessionEntity> sessions;
  final bool completeLiveStream;
  final int liveStreamFailuresBeforeSuccess;
  final String liveStreamFailureMessage;
  int _liveStreamAttempts = 0;
  final StreamController<Result<HumanHandoffEventEntity>> eventController =
      StreamController<Result<HumanHandoffEventEntity>>.broadcast();

  @override
  Future<Result<List<HumanHandoffTenantOptionEntity>>> fetchTenants({
    int top = 200,
  }) async {
    return const Result<List<HumanHandoffTenantOptionEntity>>.success(
      <HumanHandoffTenantOptionEntity>[
        HumanHandoffTenantOptionEntity(id: 'tenant-1', name: 'Tenant One'),
      ],
    );
  }

  @override
  Future<Result<PageResult<HumanHandoffSessionEntity>>> fetchSessions(
    HumanHandoffSessionListQuery query,
  ) async {
    return Result<PageResult<HumanHandoffSessionEntity>>.success(
      PageResult<HumanHandoffSessionEntity>(
        items: sessions,
        total: sessions.length,
        page: query.pageRequest.page,
        pageSize: query.pageRequest.pageSize,
      ),
    );
  }

  @override
  Future<Result<HumanHandoffTranscriptResultEntity>> listTranscript(
    HumanHandoffTranscriptQuery query,
  ) async {
    return const Result<HumanHandoffTranscriptResultEntity>.success(
      HumanHandoffTranscriptResultEntity(
        items: <HumanHandoffTranscriptItemEntity>[],
        count: 0,
        hasMore: false,
      ),
    );
  }

  @override
  Stream<Result<HumanHandoffEventEntity>> streamEvents(
    HumanHandoffEventStreamQuery query, {
    void Function()? onConnected,
  }) {
    _liveStreamAttempts += 1;
    if (_liveStreamAttempts <= liveStreamFailuresBeforeSuccess) {
      return Stream<Result<HumanHandoffEventEntity>>.value(
        Result<HumanHandoffEventEntity>.failure(
          NetworkFailure(liveStreamFailureMessage),
        ),
      );
    }
    onConnected?.call();
    if (completeLiveStream) {
      return const Stream<Result<HumanHandoffEventEntity>>.empty();
    }
    return eventController.stream;
  }

  @override
  Future<Result<HumanHandoffDeliveryResultEntity>> sendReply(
    HumanHandoffReplyInput input,
  ) async {
    return const Result<HumanHandoffDeliveryResultEntity>.success(
      HumanHandoffDeliveryResultEntity(
        decision: 'sent',
        deliveryStatus: 'sent',
      ),
    );
  }

  @override
  Future<Result<void>> deactivate(HumanHandoffDeactivateInput input) async {
    return const Result<void>.success(null);
  }
}

List<HumanHandoffSessionEntity> _buildDrawerHandoffSessions({
  bool hasNewActivity = true,
  bool hasFailure = false,
}) {
  final now = DateTime.utc(2026, 7, 4, 12);
  return <HumanHandoffSessionEntity>[
    HumanHandoffSessionEntity(
      id: 'handoff-1',
      tenantId: 'tenant-1',
      scopeKey: 'tenant:tenant-1',
      platform: 'whatsapp',
      status: 'active',
      lastHumanReplyAt: now.subtract(const Duration(minutes: 5)),
      lastUserMessageAt: hasNewActivity
          ? now
          : now.subtract(const Duration(minutes: 10)),
    ),
    HumanHandoffSessionEntity(
      id: 'handoff-2',
      tenantId: 'tenant-1',
      scopeKey: 'tenant:tenant-1',
      platform: 'web',
      status: 'active',
      lastHumanReplyAt: now,
      lastUserMessageAt: now.subtract(const Duration(minutes: 3)),
      lastDeliveryStatus: hasFailure ? 'failed' : null,
    ),
  ];
}

class _NoopUserAdminRepository implements UserAdminRepository {
  @override
  Future<Result<void>> disableUserAccount(ToggleUserAccountInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> deleteUser(DeleteUserInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> editUserRoles(EditUserRolesInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> enableUserAccount(ToggleUserAccountInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<List<UserSessionEntity>>> fetchUserSessions(
    String userId,
  ) async {
    return const Result<List<UserSessionEntity>>.success(<UserSessionEntity>[]);
  }

  @override
  Future<Result<List<UserRoleEntity>>> fetchRoles() async {
    return const Result<List<UserRoleEntity>>.success(<UserRoleEntity>[]);
  }

  @override
  Future<Result<PageResult<UserEntity>>> fetchUsers(UserListQuery query) async {
    return const Result<PageResult<UserEntity>>.success(
      PageResult<UserEntity>(
        items: <UserEntity>[],
        total: 0,
        page: 1,
        pageSize: 5,
      ),
    );
  }

  @override
  Future<Result<void>> registerUser(UserRegistrationInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> resetUserPasswordAdmin(
    UserResetPasswordAdminInput input,
  ) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> updateUser(UpdateUserInput input) async {
    return const Result<void>.success(null);
  }

  @override
  Future<Result<void>> revokeUserSession(RevokeUserSessionInput input) async {
    return const Result<void>.success(null);
  }
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
