import 'package:flutter/material.dart';

import 'package:mugen_ui/shared/presentation/portal/portal_theme_tokens.dart';

enum PortalActionCardKind { signIn, whatsApp }

class PortalActionCard extends StatefulWidget {
  const PortalActionCard({
    required this.number,
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.kind,
    required this.theme,
    required this.onPressed,
    super.key,
  });

  final String number;
  final String eyebrow;
  final String title;
  final String description;
  final PortalActionCardKind kind;
  final PortalThemeTokens theme;
  final VoidCallback onPressed;

  @override
  State<PortalActionCard> createState() => _PortalActionCardState();
}

class _PortalActionCardState extends State<PortalActionCard> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.kind == PortalActionCardKind.whatsApp
        ? widget.theme.whatsApp
        : widget.theme.indigo;
    final emphasized = _hovered || _focused;

    return Semantics(
      button: true,
      label: '${widget.title}. ${widget.description}',
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        transform: Matrix4.translationValues(0, _hovered ? -2 : 0, 0),
        decoration: BoxDecoration(
          color: emphasized ? const Color(0xF5FFFFFF) : widget.theme.surface,
          borderRadius: BorderRadius.circular(
            PortalLayoutTokens.portalCardRadius,
          ),
          border: Border.all(
            color: emphasized
                ? accent.withValues(alpha: 0.38)
                : widget.theme.line,
            width: _focused ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: widget.theme.shadow.withValues(
                alpha: _hovered ? 0.7 : 0.35,
              ),
              blurRadius: _hovered ? 34 : 22,
              offset: Offset(0, _hovered ? 14 : 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(
            PortalLayoutTokens.portalCardRadius,
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onPressed,
            onHover: (value) => setState(() => _hovered = value),
            onFocusChange: (value) => setState(() => _focused = value),
            focusColor: accent.withValues(alpha: 0.08),
            hoverColor: accent.withValues(alpha: 0.04),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 132),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final compact =
                      constraints.maxWidth <=
                      PortalLayoutTokens.mobileBreakpoint;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(
                      compact ? 16 : 20,
                      compact ? 20 : 24,
                      compact ? 16 : 24,
                      compact ? 20 : 24,
                    ),
                    child: Row(
                      children: [
                        if (!compact) ...[
                          SizedBox(
                            width: 30,
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: Text(
                                widget.number,
                                style: TextStyle(
                                  color: widget.theme.muted,
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 18),
                        ],
                        Container(
                          width: compact ? 44 : 48,
                          height: compact ? 44 : 48,
                          decoration: BoxDecoration(
                            color: accent.withValues(alpha: 0.09),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            widget.kind == PortalActionCardKind.whatsApp
                                ? Icons.chat_bubble_outline
                                : Icons.lock_outline,
                            color: accent,
                            size: 22,
                          ),
                        ),
                        SizedBox(width: compact ? 14 : 18),
                        Expanded(
                          child: ExcludeSemantics(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.eyebrow.toUpperCase(),
                                  style: TextStyle(
                                    color: widget.theme.muted,
                                    fontFamily: widget.theme.bodyFontFamily,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.title,
                                  style: TextStyle(
                                    color: widget.theme.ink,
                                    fontFamily: widget.theme.bodyFontFamily,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 5),
                                Text(
                                  widget.description,
                                  style: TextStyle(
                                    color: widget.theme.muted,
                                    fontFamily: widget.theme.bodyFontFamily,
                                    fontSize: compact ? 12 : 13,
                                    height: 1.55,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(width: compact ? 10 : 18),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          width: compact ? 32 : 36,
                          height: compact ? 32 : 36,
                          decoration: BoxDecoration(
                            color: _hovered ? accent : Colors.transparent,
                            shape: BoxShape.circle,
                            border: Border.all(color: widget.theme.line),
                          ),
                          child: Icon(
                            Icons.arrow_forward,
                            size: 18,
                            color: _hovered ? Colors.white : widget.theme.muted,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
