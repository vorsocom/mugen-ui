import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/config/app_config.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/edit_profile_panel.dart';
import 'package:mugen_ui/features/auth/presentation/widgets/reset_password_panel.dart';
import 'package:mugen_ui/features/user_admin/presentation/widgets/local_user_panel.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class ShellSettingsPanel extends ConsumerWidget {
  const ShellSettingsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final auth = ref.watch(authControllerProvider.notifier);

    final visiblePanels = config.settingsPanels
        .where((panel) {
          return auth.hasRoles(panel.roles);
        })
        .toList(growable: false);

    if (visiblePanels.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('No settings available for this account.'),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppUiPalette.border)),
          ),
          child: Text(
            'Settings',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: visiblePanels.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: AppUiPalette.border),
            itemBuilder: (context, index) {
              final panel = visiblePanels[index];
              return ListTile(
                leading: Icon(panel.icon),
                title: Text(panel.title),
                trailing: const Icon(Icons.open_in_new_outlined),
                onTap: () => _openOverlay(context, panel),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openOverlay(
    BuildContext context,
    SettingsPanelConfig panel,
  ) async {
    final (
      maxWidth,
      maxHeight,
      body,
      showHeader,
      expandBody,
    ) = switch (panel.type) {
      SettingsPanelType.account => (
        760.0,
        640.0,
        const EditProfilePanel(),
        false,
        false,
      ),
      SettingsPanelType.resetPassword => (
        760.0,
        620.0,
        const ResetPasswordPanel(),
        false,
        false,
      ),
      SettingsPanelType.users => (
        1280.0,
        860.0,
        const LocalUserPanel(),
        true,
        true,
      ),
    };

    await showDialog<void>(
      context: context,
      builder: (_) => _SettingsOverlayDialog(
        title: panel.title,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        showHeader: showHeader,
        expandBody: expandBody,
        child: body,
      ),
    );
  }
}

class _SettingsOverlayDialog extends StatelessWidget {
  const _SettingsOverlayDialog({
    required this.title,
    required this.maxWidth,
    required this.maxHeight,
    required this.child,
    this.showHeader = true,
    this.expandBody = true,
  });

  final String title;
  final double maxWidth;
  final double maxHeight;
  final Widget child;
  final bool showHeader;
  final bool expandBody;

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
          mainAxisSize: expandBody ? MainAxisSize.max : MainAxisSize.min,
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
            if (expandBody) Expanded(child: child) else child,
          ],
        ),
      ),
    );
  }
}
