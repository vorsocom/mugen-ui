import 'package:flutter/material.dart';

@immutable
class PortalThemeTokens {
  const PortalThemeTokens({
    required this.background,
    required this.ink,
    required this.titleInk,
    required this.muted,
    required this.surface,
    required this.line,
    required this.indigo,
    required this.indigoDark,
    required this.whatsApp,
    required this.graphite,
    required this.onGraphite,
    required this.onGraphiteMuted,
    required this.grid,
    required this.shadow,
    required this.displayFontFamily,
    required this.bodyFontFamily,
  });

  static const PortalThemeTokens defaults = PortalThemeTokens(
    background: Color(0xFFF4F3EF),
    ink: Color(0xFF18202B),
    titleInk: Color(0xFF222B37),
    muted: Color(0xFF677080),
    surface: Color(0xC7FFFFFF),
    line: Color(0x1F18202B),
    indigo: Color(0xFF5358C9),
    indigoDark: Color(0xFF383D9F),
    whatsApp: Color(0xFF168A62),
    graphite: Color(0xFF1C2430),
    onGraphite: Color(0xFFF7F7F8),
    onGraphiteMuted: Color(0xFFAEB4BE),
    grid: Color(0x0A18202B),
    shadow: Color(0x1718202B),
    displayFontFamily: 'BebasNeue',
    bodyFontFamily: 'Inter',
  );

  final Color background;
  final Color ink;
  final Color titleInk;
  final Color muted;
  final Color surface;
  final Color line;
  final Color indigo;
  final Color indigoDark;
  final Color whatsApp;
  final Color graphite;
  final Color onGraphite;
  final Color onGraphiteMuted;
  final Color grid;
  final Color shadow;
  final String displayFontFamily;
  final String bodyFontFamily;

  PortalThemeTokens copyWith({
    Color? background,
    Color? ink,
    Color? titleInk,
    Color? muted,
    Color? surface,
    Color? line,
    Color? indigo,
    Color? indigoDark,
    Color? whatsApp,
    Color? graphite,
    Color? onGraphite,
    Color? onGraphiteMuted,
    Color? grid,
    Color? shadow,
    String? displayFontFamily,
    String? bodyFontFamily,
  }) {
    return PortalThemeTokens(
      background: background ?? this.background,
      ink: ink ?? this.ink,
      titleInk: titleInk ?? this.titleInk,
      muted: muted ?? this.muted,
      surface: surface ?? this.surface,
      line: line ?? this.line,
      indigo: indigo ?? this.indigo,
      indigoDark: indigoDark ?? this.indigoDark,
      whatsApp: whatsApp ?? this.whatsApp,
      graphite: graphite ?? this.graphite,
      onGraphite: onGraphite ?? this.onGraphite,
      onGraphiteMuted: onGraphiteMuted ?? this.onGraphiteMuted,
      grid: grid ?? this.grid,
      shadow: shadow ?? this.shadow,
      displayFontFamily: displayFontFamily ?? this.displayFontFamily,
      bodyFontFamily: bodyFontFamily ?? this.bodyFontFamily,
    );
  }
}

abstract final class PortalLayoutTokens {
  static const double shellMaxWidth = 1080;
  static const double landingMaxWidth = 760;
  static const double documentMaxWidth = 900;
  static const double desktopOuterPadding = 76;
  static const double mobileOuterPadding = 18;
  static const double mobileBreakpoint = 640;
  static const double loginStackBreakpoint = 900;
  static const double backgroundGridSize = 36;
  static const double portalCardRadius = 18;
  static const double loginStageRadius = 28;
  static const double documentCardRadius = 24;
  static const double inputRadius = 10;
}
