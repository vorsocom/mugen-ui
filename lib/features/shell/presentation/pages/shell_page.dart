import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/features/shell/application/shell_route_access.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/route_views.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/settings_panel.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const Key _shellNoAccessibleRoutesKey = Key('shell-no-access-routes');
const Key _shellUserBarTitleKey = Key('shell-user-bar-title');
const Key _shellReplayResyncBadgeKey = Key('shell-replay-resync-badge');
const Key _shellAccountMenuTriggerKey = Key('shell-account-menu-trigger');
const Key _shellAccountMenuPanelKey = Key('shell-account-menu-panel');
const Key _shellAccountMenuSettingsKey = Key('shell-account-menu-settings');
const Key _shellAccountMenuLogoutKey = Key('shell-account-menu-logout');
const String _shellSettingsPanelKeyPrefix = 'shell-account-settings-panel';
const double _shellTopBarHeight = 52;

enum _AccountMenuAction { logout }

class ShellPage extends ConsumerStatefulWidget {
  const ShellPage({super.key}); // coverage:ignore-line

  @override
  ConsumerState<ShellPage> createState() => _ShellPageState();
}

class _ShellPageState extends ConsumerState<ShellPage> {
  String? _pendingRedirectToken;

  @override
  Widget build(BuildContext context) {
    final shellState = ref.watch(shellControllerProvider);
    final definition = ref.watch(appDefinitionProvider);
    final authState = ref.watch(authControllerProvider);
    final routeAccess = resolveShellRouteAccess(
      shellRoutes: definition.shellRoutes,
      defaultShellRouteId: definition.defaultShellRouteId,
      sessionRoles: authState.session?.roles ?? const <String>[],
      requestedRoute: shellState.activeRoute,
    );
    _scheduleRouteCorrection(routeAccess);

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _AppDrawer(
              isCollapsed: shellState.isDrawerCollapsed,
              showSettings: shellState.showSettings,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _ShellUserBar(),
                  Expanded(
                    child: shellState.showSettings
                        ? const ShellSettingsPanel()
                        : _buildShellRouteBody(
                            context: context,
                            routeAccess: routeAccess,
                            shellRoutes: definition.shellRoutes,
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShellRouteBody({
    required BuildContext context,
    required ShellRouteAccess routeAccess,
    required List<ShellRouteDefinition> shellRoutes,
  }) {
    final displayedRouteId = routeAccess.displayedRouteId;
    if (displayedRouteId == null) {
      return const _NoAccessibleRoutesView();
    }

    return buildRegisteredShellRouteWidget(
      context: context,
      routes: shellRoutes,
      routeId: displayedRouteId,
    );
  }

  void _scheduleRouteCorrection(ShellRouteAccess routeAccess) {
    if (!routeAccess.shouldRedirect) {
      _pendingRedirectToken = null;
      return;
    }

    final redirectToken =
        '${routeAccess.requestedRoute}->${routeAccess.fallbackRoute?.id ?? ''}';
    if (_pendingRedirectToken == redirectToken) {
      return;
    }
    _pendingRedirectToken = redirectToken;

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final currentState = ref.read(shellControllerProvider);
      final definition = ref.read(appDefinitionProvider);
      final currentAccess = resolveShellRouteAccess(
        shellRoutes: definition.shellRoutes,
        defaultShellRouteId: definition.defaultShellRouteId,
        sessionRoles:
            ref.read(authControllerProvider).session?.roles ?? const <String>[],
        requestedRoute: currentState.activeRoute,
      );
      // coverage:ignore-start
      if (!currentAccess.shouldRedirect) {
        if (_pendingRedirectToken == redirectToken) {
          _pendingRedirectToken = null;
        }
        return;
      }
      // coverage:ignore-end

      final didCorrect = ref
          .read(shellControllerProvider.notifier)
          .revalidateRoute();
      if (didCorrect) {
        ref
            .read(snackBarDispatcherProvider)
            .showInContext(context, 'You do not have access to that section.');
      }

      if (_pendingRedirectToken == redirectToken) {
        _pendingRedirectToken = null;
      }
    });
  }
}

class _ShellUserBar extends ConsumerWidget {
  const _ShellUserBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellState = ref.watch(shellControllerProvider);
    final definition = ref.watch(appDefinitionProvider);
    final authState = ref.watch(authControllerProvider);
    final session = authState.session;
    final routeAccess = resolveShellRouteAccess(
      shellRoutes: definition.shellRoutes,
      defaultShellRouteId: definition.defaultShellRouteId,
      sessionRoles: session?.roles ?? const <String>[],
      requestedRoute: shellState.activeRoute,
    );
    final displayedRouteId = routeAccess.displayedRouteId;
    final displayName = session?.username ?? session?.userId ?? 'User';
    final showConnectionIndicator = _isChatRouteActive(
      showSettings: shellState.showSettings,
      routeId: displayedRouteId,
    );
    final isConnected = showConnectionIndicator
        ? ref.watch(chatControllerProvider.select((state) => state.isConnected))
        : false;
    final isConnecting = showConnectionIndicator
        ? ref.watch(
            chatControllerProvider.select((state) => state.isConnecting),
          )
        : false;
    final showReplayResyncBadge =
        !shellState.showSettings && displayedRouteId == RouteIds.chat
        ? ref.watch(
            chatControllerProvider.select((state) => state.hasReplayNotice),
          )
        : false;
    final replayNoticeReason = showReplayResyncBadge
        ? ref.watch(
            chatControllerProvider.select((state) => state.replayNoticeReason),
          )
        : null;
    final routeTitle = _resolveShellRouteTitle(
      shellRoutes: definition.shellRoutes,
      shellState: shellState,
      routeAccess: routeAccess,
    );

    return Container(
      height: _shellTopBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppUiPalette.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Toggle drawer',
            icon: const Icon(Icons.menu),
            onPressed: () {
              ref.read(shellControllerProvider.notifier).toggleCollapsed();
            },
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    routeTitle,
                    key: _shellUserBarTitleKey,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (showConnectionIndicator) ...[
                  const SizedBox(width: 10),
                  _ShellConnectionIndicator(
                    isConnected: isConnected,
                    isConnecting: isConnecting,
                  ),
                  if (showReplayResyncBadge) ...[
                    const SizedBox(width: 8),
                    _ShellReplayResyncBadge(reasonCode: replayNoticeReason),
                  ],
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ShellAccountMenu(displayName: displayName),
        ],
      ),
    );
  }
}

String _resolveShellRouteTitle({
  required List<ShellRouteDefinition> shellRoutes,
  required ShellState shellState,
  required ShellRouteAccess routeAccess,
}) {
  if (shellState.showSettings) {
    return 'Settings';
  }

  final displayedRouteId = routeAccess.displayedRouteId;
  if (displayedRouteId == null) {
    return 'Access Restricted';
  }

  final displayedRoute = findShellRouteDefinition(
    routes: shellRoutes,
    routeId: displayedRouteId,
  );
  if (displayedRoute != null) {
    return displayedRoute.title;
  }

  return displayedRouteId;
}

bool _isChatRouteActive({
  required bool showSettings,
  required String? routeId,
}) {
  if (showSettings || routeId == null) {
    return false;
  }
  return routeId == RouteIds.chat || routeId == RouteIds.dashboard;
}

class _ShellConnectionIndicator extends StatelessWidget {
  const _ShellConnectionIndicator({
    required this.isConnected,
    required this.isConnecting,
  });

  final bool isConnected;
  final bool isConnecting;

  @override
  Widget build(BuildContext context) {
    final color = isConnected
        ? Colors.green
        : isConnecting
        ? Colors.orange
        : AppUiPalette.textMuted;
    final text = isConnected
        ? 'Connected'
        : isConnecting
        ? 'Connecting...'
        : 'Disconnected';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _ShellReplayResyncBadge extends StatelessWidget {
  const _ShellReplayResyncBadge({required this.reasonCode});

  final String? reasonCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Tooltip(
      message: _buildReplayResyncTooltip(reasonCode),
      child: Container(
        key: _shellReplayResyncBadgeKey,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.amber.shade100,
          border: Border.all(color: Colors.amber.shade300),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          'Resynced',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.amber.shade900,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _ShellAccountMenu extends ConsumerWidget {
  const _ShellAccountMenu({required this.displayName});

  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final initials = _buildUserInitials(displayName);
    final panels = _visibleSettingsPanels(ref);

    return PopupMenuButton<_AccountMenuAction>(
      key: _shellAccountMenuTriggerKey,
      tooltip: 'Account menu',
      onSelected: (selection) async {
        if (selection == _AccountMenuAction.logout) {
          await _handleLogout(ref);
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      constraints: const BoxConstraints(minWidth: 320, maxWidth: 360),
      itemBuilder: (context) {
        return <PopupMenuEntry<_AccountMenuAction>>[
          PopupMenuItem<_AccountMenuAction>(
            key: _shellAccountMenuPanelKey,
            enabled: false,
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: _AccountMegaHeader(
              displayName: displayName,
              initials: initials,
            ),
          ),
          const PopupMenuDivider(height: 1),
          PopupMenuItem<_AccountMenuAction>(
            enabled: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: _AccountInlineSettingsSection(
              panels: panels,
              onSelectPanel: (panel) async {
                final navigator = Navigator.of(context);
                navigator.pop();
                await Future<void>.delayed(Duration.zero);
                if (!context.mounted) {
                  return;
                }
                await _openSettingsOverlay(context, panel);
              },
            ),
          ),
          PopupMenuItem<_AccountMenuAction>(
            key: _shellAccountMenuLogoutKey,
            value: _AccountMenuAction.logout,
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: const _AccountMegaAction(
              icon: Icons.logout_outlined,
              title: 'Logout',
              subtitle: 'Sign out of this session',
            ),
          ),
        ];
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: AppUiPalette.border),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppUiPalette.surfaceStrong,
              child: Text(
                initials,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 120),
              child: Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 2),
            const Icon(Icons.expand_more, size: 18),
          ],
        ),
      ),
    );
  }
}

class _AccountMegaHeader extends StatelessWidget {
  const _AccountMegaHeader({required this.displayName, required this.initials});

  final String displayName;
  final String initials;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 22,
          backgroundColor: AppUiPalette.surfaceStrong,
          child: Text(
            initials,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Account',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppUiPalette.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AccountMegaAction extends StatelessWidget {
  const _AccountMegaAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailingIcon = Icons.chevron_right,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailingIcon;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Container(
      decoration: BoxDecoration(
        color: enabled ? AppUiPalette.surface : AppUiPalette.surfaceMuted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppUiPalette.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: enabled ? null : AppUiPalette.textSecondary,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: enabled ? null : AppUiPalette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: enabled
                        ? AppUiPalette.textSecondary
                        : AppUiPalette.textDisabled,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            trailingIcon,
            size: 18,
            color: enabled ? null : AppUiPalette.textSecondary,
          ),
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: content,
    );
  }
}

class _AccountInlineSettingsSection extends StatefulWidget {
  const _AccountInlineSettingsSection({
    required this.panels,
    required this.onSelectPanel,
  });

  final List<SettingsPanelDefinition> panels;
  final Future<void> Function(SettingsPanelDefinition panel) onSelectPanel;

  @override
  State<_AccountInlineSettingsSection> createState() =>
      _AccountInlineSettingsSectionState();
}

class _AccountInlineSettingsSectionState
    extends State<_AccountInlineSettingsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasPanels = widget.panels.isNotEmpty;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountMegaAction(
          key: _shellAccountMenuSettingsKey,
          icon: Icons.settings_outlined,
          title: 'Manage Account',
          subtitle: hasPanels
              ? 'Choose an account option'
              : 'No account options available for this account',
          trailingIcon: _isExpanded ? Icons.expand_less : Icons.expand_more,
          enabled: hasPanels,
          onTap: hasPanels
              ? () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                }
              : null,
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: _isExpanded
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 2),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: widget.panels
                        .map(
                          (panel) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _AccountSettingsPanelAction(
                              key: ValueKey<String>(
                                '$_shellSettingsPanelKeyPrefix-${panel.id}',
                              ),
                              panel: panel,
                              onTap: () => widget.onSelectPanel(panel),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _AccountSettingsPanelAction extends StatelessWidget {
  const _AccountSettingsPanelAction({
    required this.panel,
    required this.onTap,
    super.key,
  });

  final SettingsPanelDefinition panel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppUiPalette.border),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Icon(panel.icon, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(panel.title)),
            ],
          ),
        ),
      ),
    );
  }
}

String _buildReplayResyncTooltip(String? reasonCode) {
  final normalized = reasonCode?.trim().toLowerCase();
  final detail = switch (normalized) {
    'stale_cursor' => 'Replay cursor was stale and the stream was resynced.',
    'generation_mismatch' =>
      'Event stream generation changed and replay was resynced.',
    'event_log_rollover' ||
    'log_rollover' => 'Event log rolled over and replay was resynced.',
    'cursor_unavailable' || 'cursor_not_found' =>
      'Requested replay cursor was unavailable; stream resynced.',
    _ => 'Event replay was resynced.',
  };
  if (normalized == null || normalized.isEmpty) {
    return detail;
  }
  return '$detail ($reasonCode)';
}

List<SettingsPanelDefinition> _visibleSettingsPanels(WidgetRef ref) {
  return visibleSettingsPanels(
    panels: ref.read(settingsPanelDefinitionsProvider),
    hasRoles: ref.read(authControllerProvider.notifier).hasRoles,
  );
}

Future<void> _openSettingsOverlay(
  BuildContext context,
  SettingsPanelDefinition panel,
) async {
  await showSettingsPanelOverlay(context, panel);
}

Future<void> _handleLogout(WidgetRef ref) async {
  final success = await ref.read(authControllerProvider.notifier).logout();
  if (!success) {
    return;
  }
  await ref.read(appNavigatorProvider).navigateTo(AppRoutePaths.login);
}

String _buildUserInitials(String displayName) {
  final normalized = displayName.trim();
  if (normalized.isEmpty) {
    return 'U';
  }

  final tokens = normalized
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (tokens.isEmpty) {
    return 'U';
  }

  final first = _firstCharacter(tokens.first);
  final second = tokens.length > 1 ? _firstCharacter(tokens[1]) : '';
  final initials = '$first$second'.trim();
  if (initials.isEmpty) {
    return 'U';
  }
  return initials.toUpperCase();
}

String _firstCharacter(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return '';
  }
  return trimmed.substring(0, 1);
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.isCollapsed, required this.showSettings});

  final bool isCollapsed;
  final bool showSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final definition = ref.watch(appDefinitionProvider);
    final shellState = ref.watch(shellControllerProvider);
    final sessionRoles =
        ref.watch(authControllerProvider).session?.roles ?? const <String>[];
    final routeAccess = resolveShellRouteAccess(
      shellRoutes: definition.shellRoutes,
      defaultShellRouteId: definition.defaultShellRouteId,
      sessionRoles: sessionRoles,
      requestedRoute: shellState.activeRoute,
    );
    final activeRoute = routeAccess.displayedRouteId;
    final visibleDrawerItems = definition.shellRoutes
        .where((item) => item.showInDrawer)
        .where((item) => routeAccess.allowedRouteIds.contains(item.id))
        .toList(growable: false);
    final primaryItems = <ShellRouteDefinition>[];
    final sectionedItems = <String, List<ShellRouteDefinition>>{};
    for (final item in visibleDrawerItems) {
      final sectionName = item.section?.trim();
      if (sectionName == null || sectionName.isEmpty) {
        primaryItems.add(item);
        continue;
      }
      sectionedItems
          .putIfAbsent(sectionName, () => <ShellRouteDefinition>[])
          .add(item);
    }
    final sectionEntries = sectionedItems.entries.toList(growable: false);
    final theme = Theme.of(context);

    return SizedBox(
      width: isCollapsed ? 72 : 250,
      child: Drawer(
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Container(
              height: _shellTopBarHeight,
              alignment: isCollapsed ? Alignment.center : Alignment.centerLeft,
              padding: EdgeInsets.symmetric(horizontal: isCollapsed ? 0 : 12),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppUiPalette.border)),
              ),
              child: Text(
                isCollapsed ? 'mG' : config.appName,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
                children: [
                  for (final item in primaryItems)
                    _buildDrawerNavItem(
                      context: context,
                      ref: ref,
                      item: item,
                      isSelected: !showSettings && activeRoute == item.id,
                      isCollapsed: isCollapsed,
                    ),
                  for (
                    var index = 0;
                    index < sectionEntries.length;
                    index++
                  ) ...[
                    if (isCollapsed &&
                        (index > 0 || primaryItems.isNotEmpty)) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 8),
                        child: Divider(
                          height: 1,
                          thickness: 1,
                          color: AppUiPalette.border,
                        ),
                      ),
                    ],
                    if (!isCollapsed) ...[
                      if (index > 0 || primaryItems.isNotEmpty)
                        const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(10, 0, 10, 6),
                        child: Text(
                          sectionEntries[index].key,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: AppUiPalette.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.35,
                          ),
                        ),
                      ),
                    ],
                    for (final item in sectionEntries[index].value)
                      _buildDrawerNavItem(
                        context: context,
                        ref: ref,
                        item: item,
                        isSelected: !showSettings && activeRoute == item.id,
                        isCollapsed: isCollapsed,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildDrawerNavItem({
  required BuildContext context,
  required WidgetRef ref,
  required ShellRouteDefinition item,
  required bool isSelected,
  required bool isCollapsed,
}) {
  final theme = Theme.of(context);
  final tile = Material(
    color: isSelected ? AppUiPalette.surfaceStrong : Colors.transparent,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        ref.read(shellControllerProvider.notifier).setRoute(item.id);
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isCollapsed ? 6 : 10,
          vertical: 8,
        ),
        child: Row(
          mainAxisAlignment: isCollapsed
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            _DrawerIconBadge(
              icon: item.icon,
              selected: isSelected,
              compact: isCollapsed,
            ),
            if (!isCollapsed) ...[
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.title,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    ),
  );

  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: isCollapsed ? Tooltip(message: item.title, child: tile) : tile,
  );
}

class _DrawerIconBadge extends StatelessWidget {
  const _DrawerIconBadge({
    required this.icon,
    required this.selected,
    required this.compact,
  });

  final IconData icon;
  final bool selected;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected
        ? AppUiPalette.border
        : AppUiPalette.surfaceStrong;
    return Container(
      width: compact ? 34 : 30,
      height: compact ? 34 : 30,
      decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
      child: Icon(
        icon,
        size: compact ? 19 : 18,
        color: AppUiPalette.textPrimary,
      ),
    );
  }
}

class _NoAccessibleRoutesView extends StatelessWidget {
  const _NoAccessibleRoutesView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Container(
          key: _shellNoAccessibleRoutesKey,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppUiPalette.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 32,
                color: AppUiPalette.textSecondary,
              ),
              const SizedBox(height: 12),
              Text(
                'No accessible sections are available for this account.',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
