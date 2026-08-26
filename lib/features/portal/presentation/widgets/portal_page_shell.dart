import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mugen_ui/app/providers.dart';
import 'package:mugen_ui/app/routing/route_ids.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_definition.dart';
import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';

class PortalPageShell extends ConsumerWidget {
  const PortalPageShell({
    required this.child,
    super.key,
    this.contentMaxWidth = PortalLayoutTokens.shellMaxWidth,
  });

  final Widget child;
  final double contentMaxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(portalDefinitionProvider);
    final navigator = ref.watch(appNavigatorProvider);
    final theme = definition.theme;

    return Scaffold(
      backgroundColor: theme.background,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile =
              constraints.maxWidth <= PortalLayoutTokens.mobileBreakpoint;
          final horizontalPadding = isMobile
              ? PortalLayoutTokens.mobileOuterPadding
              : (constraints.maxWidth * 0.05).clamp(
                  24.0,
                  PortalLayoutTokens.desktopOuterPadding,
                );

          return Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  key: const Key('portal-background-grid'),
                  painter: PortalGridPainter(color: theme.grid),
                ),
              ),
              const Positioned(
                top: -250,
                right: -100,
                child: _PortalAmbientOrb(size: 470, color: Color(0x335C61CF)),
              ),
              const Positioned(
                left: -150,
                bottom: -250,
                child: _PortalAmbientOrb(size: 390, color: Color(0x1F168A62)),
              ),
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: Opacity(
                      opacity: 0.055,
                      child: Image.asset(
                        definition.technicalPatternAssetPath,
                        key: const Key('portal-technical-pattern'),
                        repeat: ImageRepeat.repeat,
                        fit: BoxFit.none,
                        alignment: Alignment.center,
                        filterQuality: FilterQuality.low,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned.fill(
                child: CustomScrollView(
                  primary: false,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        isMobile ? 22 : 28,
                        horizontalPadding,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _PortalFrame(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Semantics(
                              button: true,
                              label: definition.logoSemanticLabel,
                              child: TextButton(
                                key: const Key('portal-logo-link'),
                                onPressed: () =>
                                    navigator.navigateTo(AppRoutePaths.portal),
                                style: ButtonStyle(
                                  minimumSize: const WidgetStatePropertyAll(
                                    Size(48, 48),
                                  ),
                                  padding: const WidgetStatePropertyAll(
                                    EdgeInsets.zero,
                                  ),
                                  alignment: Alignment.centerLeft,
                                  overlayColor: WidgetStatePropertyAll(
                                    theme.indigo.withValues(alpha: 0.07),
                                  ),
                                  side: WidgetStateProperty.resolveWith(
                                    (states) =>
                                        states.contains(WidgetState.focused)
                                        ? BorderSide(
                                            color: theme.indigo.withValues(
                                              alpha: 0.45,
                                            ),
                                            width: 2,
                                          )
                                        : BorderSide.none,
                                  ),
                                  shape: WidgetStatePropertyAll(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                                child: ExcludeSemantics(
                                  child: Image.asset(
                                    definition.logoAssetPath,
                                    key: const Key('portal-logo-image'),
                                    width: isMobile ? 122 : 138,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.symmetric(
                        horizontal: horizontalPadding,
                      ),
                      sliver: SliverToBoxAdapter(
                        child: _PortalFrame(
                          maxWidth: contentMaxWidth,
                          child: child,
                        ),
                      ),
                    ),
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                          horizontalPadding,
                          28,
                          horizontalPadding,
                          isMobile ? 22 : 26,
                        ),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: _PortalFrame(
                            child: _PortalFooter(
                              definition: definition,
                              isMobile: isMobile,
                              onTerms: () =>
                                  navigator.navigateTo(AppRoutePaths.terms),
                              onPrivacy: () =>
                                  navigator.navigateTo(AppRoutePaths.privacy),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class PortalBackLink extends ConsumerWidget {
  const PortalBackLink({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = ref.watch(portalDefinitionProvider);
    return TextButton.icon(
      key: const Key('portal-back-link'),
      onPressed: () =>
          ref.read(appNavigatorProvider).navigateTo(AppRoutePaths.portal),
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: definition.theme.muted,
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('Back to portal'),
    );
  }
}

class PortalGridPainter extends CustomPainter {
  const PortalGridPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (
      var x = 0.0;
      x <= size.width;
      x += PortalLayoutTokens.backgroundGridSize
    ) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (
      var y = 0.0;
      y <= size.height;
      y += PortalLayoutTokens.backgroundGridSize
    ) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(PortalGridPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _PortalFrame extends StatelessWidget {
  const _PortalFrame({
    required this.child,
    this.maxWidth = PortalLayoutTokens.shellMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }
}

class _PortalAmbientOrb extends StatelessWidget {
  const _PortalAmbientOrb({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: ExcludeSemantics(
        child: SizedBox.square(
          dimension: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[color, color.withValues(alpha: 0)],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PortalFooter extends StatelessWidget {
  const _PortalFooter({
    required this.definition,
    required this.isMobile,
    required this.onTerms,
    required this.onPrivacy,
  });

  final PortalDefinition definition;
  final bool isMobile;
  final VoidCallback onTerms;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final theme = definition.theme;
    final footerStyle = TextStyle(
      color: theme.muted,
      fontFamily: theme.bodyFontFamily,
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
    );
    final legal = Row(
      key: const Key('portal-legal-links'),
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton(
          key: const Key('portal-terms-link'),
          onPressed: onTerms,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: theme.muted,
            textStyle: footerStyle,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(definition.footer.termsLabel.toUpperCase()),
        ),
        Text('·', style: footerStyle),
        TextButton(
          key: const Key('portal-privacy-link'),
          onPressed: onPrivacy,
          style: TextButton.styleFrom(
            minimumSize: const Size(48, 48),
            foregroundColor: theme.muted,
            textStyle: footerStyle,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(definition.footer.privacyLabel.toUpperCase()),
        ),
      ],
    );

    return Container(
      key: const Key('portal-footer'),
      padding: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: theme.line)),
      ),
      child: isMobile
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '© ${DateTime.now().year} ${definition.footer.companyName}'
                      .toUpperCase(),
                  style: footerStyle,
                ),
                legal,
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    '© ${DateTime.now().year} ${definition.footer.companyName}'
                        .toUpperCase(),
                    style: footerStyle,
                  ),
                ),
                legal,
                Expanded(
                  child: Text(
                    definition.footer.slogan.toUpperCase(),
                    key: const Key('portal-footer-slogan'),
                    textAlign: TextAlign.end,
                    style: footerStyle,
                  ),
                ),
              ],
            ),
    );
  }
}
