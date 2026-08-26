import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/features/portal/presentation/providers/portal_providers.dart';
import 'package:mugen_ui/features/portal/presentation/widgets/portal_action_card.dart';
import 'package:mugen_ui/features/portal/presentation/widgets/portal_page_shell.dart';
import 'package:mugen_ui/shared/presentation/theme/app_form_style.dart';

class PortalLandingPage extends ConsumerWidget {
  const PortalLandingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(portalDefinitionProvider);
    final config = ref.watch(appConfigProvider);
    final content = definition.landing;
    final theme = definition.theme;
    final showWhatsApp = config.whatsappEmbeddedSignupEnabled;

    return PortalPageShell(
      contentMaxWidth: 760,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth <= 640;
          return Padding(
            padding: EdgeInsets.only(
              top: compact ? 76 : 108,
              bottom: compact ? 62 : 78,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    content.title.toUpperCase(),
                    key: const Key('portal-landing-title'),
                    style: TextStyle(
                      color: theme.titleInk,
                      fontFamily: theme.displayFontFamily,
                      fontSize: compact ? 50 : 58,
                      fontWeight: FontWeight.w400,
                      letterSpacing: compact ? 0.8 : 1.1,
                      height: compact ? 1.02 : 1,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  showWhatsApp
                      ? content.subtitleWithWhatsApp
                      : content.subtitleWithoutWhatsApp,
                  key: const Key('portal-landing-subtitle'),
                  style: TextStyle(
                    color: theme.muted,
                    fontFamily: theme.bodyFontFamily,
                    fontSize: compact ? 15 : 16,
                    height: 1.7,
                  ),
                ),
                SizedBox(height: compact ? 32 : 40),
                PortalActionCard(
                  key: const Key('portal-sign-in-card'),
                  number: '01',
                  eyebrow: content.signInEyebrow,
                  title: content.signInTitle,
                  description: content.signInDescription,
                  kind: PortalActionCardKind.signIn,
                  theme: theme,
                  onPressed: () => ref
                      .read(appNavigatorProvider)
                      .navigateTo(AppRoutePaths.login),
                ),
                if (showWhatsApp) ...[
                  const SizedBox(height: 12),
                  PortalActionCard(
                    key: const Key('portal-whatsapp-card'),
                    number: '02',
                    eyebrow: content.whatsAppEyebrow,
                    title: content.whatsAppTitle,
                    description: content.whatsAppDescription,
                    kind: PortalActionCardKind.whatsApp,
                    theme: theme,
                    onPressed: () => _launchWhatsApp(context, ref),
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '◆',
                      style: TextStyle(color: theme.indigo, fontSize: 7),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        content.securityNote,
                        key: const Key('portal-security-note'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: theme.muted,
                          fontFamily: theme.bodyFontFamily,
                          fontSize: 11,
                          letterSpacing: 0.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _launchWhatsApp(BuildContext context, WidgetRef ref) async {
    final launcher = ref.read(portalWhatsAppSignupLauncherProvider);
    if (launcher == null) {
      await _showInformationDialog(
        context,
        message: 'WhatsApp Embedded Signup is not connected in this UI yet.',
      );
      return;
    }

    try {
      final result = await launcher.launch();
      if (!context.mounted || result.isSuccess) {
        return;
      }
      await _showInformationDialog(
        context,
        message:
            result.failure?.message ??
            'WhatsApp Embedded Signup could not be started.',
        isError: true,
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      await _showInformationDialog(
        context,
        message: 'WhatsApp Embedded Signup could not be started.',
        isError: true,
      );
    }
  }

  Future<void> _showInformationDialog(
    BuildContext context, {
    required String message,
    bool isError = false,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AppFormDialog(
          maxWidth: 520,
          title: 'WhatsApp Embedded Signup',
          scrollable: false,
          body: isError
              ? AppErrorAlert(message: message)
              : Text(
                  message,
                  key: const Key('portal-whatsapp-placeholder-message'),
                  style: Theme.of(dialogContext).textTheme.bodyMedium,
                ),
          actions: [
            FilledButton(
              key: const Key('portal-whatsapp-dialog-close'),
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}
