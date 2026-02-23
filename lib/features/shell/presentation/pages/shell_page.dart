import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/chat/presentation/providers/chat_providers.dart';
import 'package:mugen_ui/features/shell/presentation/providers/shell_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/reset_password_panel.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/route_views.dart';
import 'package:mugen_ui/features/shell/presentation/widgets/settings_panel.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

const Key _shellUserBarTitleKey = Key('shell-user-bar-title');
const Key _shellReplayResyncBadgeKey = Key('shell-replay-resync-badge');
const Key _shellAccountMenuTriggerKey = Key('shell-account-menu-trigger');
const Key _shellAccountMenuPanelKey = Key('shell-account-menu-panel');
const Key _shellAccountMenuSettingsKey = Key('shell-account-menu-settings');
const Key _shellAccountMenuLogoutKey = Key('shell-account-menu-logout');
const String _shellSettingsPanelKeyPrefix = 'shell-account-settings-panel';
const double _shellTopBarHeight = 52;

enum _AccountMenuAction { logout }

class ShellPage extends ConsumerWidget {
  const ShellPage({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellState = ref.watch(shellControllerProvider);

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
                        : buildSpaRouteWidget(shellState.activeRoute),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShellUserBar extends ConsumerWidget {
  const _ShellUserBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shellState = ref.watch(shellControllerProvider);
    final config = ref.watch(appConfigProvider);
    final session = ref.watch(authControllerProvider).session;
    final displayName = session?.username ?? session?.userId ?? 'User';
    final showConnectionIndicator = _isChatRouteActive(shellState);
    final isConnected = showConnectionIndicator
        ? ref.watch(chatControllerProvider.select((state) => state.isConnected))
        : false;
    final isConnecting = showConnectionIndicator
        ? ref.watch(
            chatControllerProvider.select((state) => state.isConnecting),
          )
        : false;
    final showReplayResyncBadge =
        !shellState.showSettings && shellState.activeRoute == RouteIds.chat
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
      config: config,
      shellState: shellState,
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
  required AppConfig config,
  required ShellState shellState,
}) {
  if (shellState.showSettings) {
    return 'Settings';
  }

  for (final route in config.spaRoutes) {
    if (route.id == shellState.activeRoute) {
      return route.title;
    }
  }

  for (final item in config.drawerItems) {
    if (item.route == shellState.activeRoute) {
      return item.title;
    }
  }

  return shellState.activeRoute;
}

bool _isChatRouteActive(ShellState shellState) {
  if (shellState.showSettings) {
    return false;
  }
  return shellState.activeRoute == RouteIds.chat ||
      shellState.activeRoute == RouteIds.dashboard;
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

  final List<SettingsPanelConfig> panels;
  final Future<void> Function(SettingsPanelConfig panel) onSelectPanel;

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
                                '$_shellSettingsPanelKeyPrefix-${panel.type.name}',
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

  final SettingsPanelConfig panel;
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

List<SettingsPanelConfig> _visibleSettingsPanels(WidgetRef ref) {
  final config = ref.read(appConfigProvider);
  final auth = ref.read(authControllerProvider.notifier);
  return config.settingsPanels
      .where((panel) => auth.hasRoles(panel.roles))
      .toList(growable: false);
}

Future<void> _openSettingsOverlay(
  BuildContext context,
  SettingsPanelConfig panel,
) async {
  final (maxWidth, maxHeight, body) = switch (panel.type) {
    SettingsPanelType.account => (560.0, 520.0, const ResetPasswordPanel()),
    SettingsPanelType.users => (1280.0, 860.0, const LocalUserPanel()),
  };

  await showDialog<void>(
    context: context,
    builder: (_) => _AccountSettingsOverlayDialog(
      title: panel.title,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      showHeader: panel.type != SettingsPanelType.account,
      child: body,
    ),
  );
}

Future<void> _handleLogout(WidgetRef ref) async {
  final success = await ref.read(authControllerProvider.notifier).logout();
  if (!success) {
    return;
  }
  await ref.read(appNavigatorProvider).navigateTo(RouteIds.login);
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

class _AccountSettingsOverlayDialog extends StatelessWidget {
  const _AccountSettingsOverlayDialog({
    required this.title,
    required this.maxWidth,
    required this.maxHeight,
    required this.child,
    this.showHeader = true,
  });

  final String title;
  final double maxWidth;
  final double maxHeight;
  final Widget child;
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.sizeOf(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth.clamp(320.0, media.width - 48),
          maxHeight: maxHeight.clamp(280.0, media.height - 48),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showHeader)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: AppUiPalette.border),
                  ),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}

class _AppDrawer extends ConsumerWidget {
  const _AppDrawer({required this.isCollapsed, required this.showSettings});

  final bool isCollapsed;
  final bool showSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final authController = ref.read(authControllerProvider.notifier);
    final shellState = ref.watch(shellControllerProvider);
    final activeRoute = shellState.activeRoute;
    final visibleDrawerItems = config.drawerItems
        .where(
          (item) => item.roles.isEmpty || authController.hasRoles(item.roles),
        )
        .toList(growable: false);
    final primaryItems = <DrawerItemConfig>[];
    final sectionedItems = <String, List<DrawerItemConfig>>{};
    for (final item in visibleDrawerItems) {
      final sectionName = item.section?.trim();
      if (sectionName == null || sectionName.isEmpty) {
        primaryItems.add(item);
        continue;
      }
      sectionedItems
          .putIfAbsent(sectionName, () => <DrawerItemConfig>[])
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
                      isSelected: !showSettings && activeRoute == item.route,
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
                        isSelected: !showSettings && activeRoute == item.route,
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
  required DrawerItemConfig item,
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
        ref.read(shellControllerProvider.notifier).setRoute(item.route);
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
