import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/definition/app_definition.dart';
import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/auth/presentation/providers/auth_providers.dart';
import 'package:mugen_ui/shared/presentation/theme/app_ui_palette.dart';

class ShellSettingsPanel extends ConsumerWidget {
  const ShellSettingsPanel({super.key}); // coverage:ignore-line

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visiblePanels = visibleSettingsPanels(
      panels: ref.watch(settingsPanelDefinitionsProvider),
      hasRoles: ref.read(authControllerProvider.notifier).hasRoles,
    );

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
                onTap: () => showSettingsPanelOverlay(context, panel),
              );
            },
          ),
        ),
      ],
    );
  }
}

List<SettingsPanelDefinition> visibleSettingsPanels({
  required List<SettingsPanelDefinition> panels,
  required bool Function(List<String> requiredRoles) hasRoles,
}) {
  return panels
      .where((panel) => hasRoles(panel.requiredRoles))
      .toList(growable: false);
}

Future<void> showSettingsPanelOverlay(
  BuildContext context,
  SettingsPanelDefinition panel,
) async {
  await showDialog<void>(
    context: context,
    builder: (_) => SettingsOverlayDialog(
      title: panel.title,
      maxWidth: panel.maxWidth,
      maxHeight: panel.maxHeight,
      showHeader: panel.showHeader,
      expandBody: panel.expandBody,
      child: Builder(builder: panel.builder),
    ),
  );
}

class SettingsOverlayDialog extends StatelessWidget {
  const SettingsOverlayDialog({
    super.key,
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
