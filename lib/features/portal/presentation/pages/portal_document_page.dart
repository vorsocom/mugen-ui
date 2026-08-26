import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/features/portal/presentation/widgets/portal_page_shell.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_definition.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';

class PortalTermsPage extends ConsumerWidget {
  const PortalTermsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PortalDocumentPage(
      key: const Key('portal-terms-page'),
      document: ref.watch(portalDefinitionProvider).terms,
    );
  }
}

class PortalPrivacyPage extends ConsumerWidget {
  const PortalPrivacyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PortalDocumentPage(
      key: const Key('portal-privacy-page'),
      document: ref.watch(portalDefinitionProvider).privacy,
    );
  }
}

class PortalDocumentPage extends ConsumerWidget {
  const PortalDocumentPage({required this.document, super.key});

  final PortalDocumentContent document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(portalDefinitionProvider);
    final theme = definition.theme;

    return PortalPageShell(
      contentMaxWidth: PortalLayoutTokens.documentMaxWidth,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact =
              constraints.maxWidth <= PortalLayoutTokens.mobileBreakpoint;
          return Padding(
            padding: EdgeInsets.only(
              top: compact ? 42 : 64,
              bottom: compact ? 36 : 56,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: PortalBackLink(),
                ),
                SizedBox(height: compact ? 14 : 20),
                if (compact)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DocumentTitle(document: document, theme: theme),
                      const SizedBox(height: 16),
                      _LastUpdated(document: document, theme: theme),
                    ],
                  )
                else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: _DocumentTitle(document: document, theme: theme),
                      ),
                      const SizedBox(width: 32),
                      _LastUpdated(document: document, theme: theme),
                    ],
                  ),
                const SizedBox(height: 30),
                Container(
                  key: const Key('portal-document-card'),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: theme.surface,
                    border: Border.all(color: theme.line),
                    borderRadius: BorderRadius.circular(
                      PortalLayoutTokens.documentCardRadius,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.shadow.withValues(alpha: 0.45),
                        blurRadius: 42,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        color: theme.indigo.withValues(alpha: 0.055),
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 22 : 40,
                          vertical: compact ? 26 : 34,
                        ),
                        child: SelectableText(
                          document.summary,
                          key: const Key('portal-document-summary'),
                          style: TextStyle(
                            color: theme.muted,
                            fontFamily: theme.bodyFontFamily,
                            fontSize: compact ? 14 : 15,
                            height: 1.75,
                          ),
                        ),
                      ),
                      for (final section in document.sections)
                        _DocumentSection(
                          section: section,
                          theme: theme,
                          compact: compact,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DocumentTitle extends StatelessWidget {
  const _DocumentTitle({required this.document, required this.theme});

  final PortalDocumentContent document;
  final PortalThemeTokens theme;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        document.title.toUpperCase(),
        key: const Key('portal-document-title'),
        style: TextStyle(
          color: theme.titleInk,
          fontFamily: theme.displayFontFamily,
          fontSize:
              MediaQuery.sizeOf(context).width <=
                  PortalLayoutTokens.mobileBreakpoint
              ? 48
              : 68,
          fontWeight: FontWeight.w400,
          letterSpacing: 1,
          height: 1,
        ),
      ),
    );
  }
}

class _LastUpdated extends StatelessWidget {
  const _LastUpdated({required this.document, required this.theme});

  final PortalDocumentContent document;
  final PortalThemeTokens theme;

  @override
  Widget build(BuildContext context) {
    return Text(
      document.lastUpdated,
      key: const Key('portal-document-last-updated'),
      style: TextStyle(
        color: theme.muted,
        fontFamily: theme.bodyFontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _DocumentSection extends StatelessWidget {
  const _DocumentSection({
    required this.section,
    required this.theme,
    required this.compact,
  });

  final PortalDocumentSection section;
  final PortalThemeTokens theme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final title = Semantics(
      header: true,
      child: Text(
        section.title,
        style: TextStyle(
          color: theme.ink,
          fontFamily: theme.bodyFontFamily,
          fontSize: 13,
          fontWeight: FontWeight.w700,
          height: 1.45,
        ),
      ),
    );
    final body = SelectableText(
      section.body,
      style: TextStyle(
        color: theme.muted,
        fontFamily: theme.bodyFontFamily,
        fontSize: 13,
        height: 1.75,
      ),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 22 : 40,
        vertical: compact ? 26 : 30,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.line)),
      ),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [title, const SizedBox(height: 10), body],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 42, child: title),
                const SizedBox(width: 44),
                Expanded(flex: 58, child: body),
              ],
            ),
    );
  }
}
