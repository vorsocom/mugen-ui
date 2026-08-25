import 'package:flutter/material.dart';

abstract class AppUiPalette {
  static const Color background = Color(0xFFFFFFFF);
  static const Color userBar = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF0ECE5);
  static const Color surfaceStrong = Color(0xFFE6E0D7);

  static const Color border = Color(0xFFD8D1C7);
  static const Color borderStrong = Color(0xFFC5BDB2);

  static const Color textPrimary = Color(0xFF252427);
  static const Color textSecondary = Color(0xFF555158);
  static const Color textMuted = Color(0xFF706B68);
  static const Color textDisabled = Color(0xFF918B85);

  static const Color accent = Color(0xFF40546A);
  static const Color accentSoft = Color(0xFFE8EDF2);
  static const Color focusRing = Color(0x3340546A);
  static const Color buttonPrimary = accent;

  static const Color drawer = Color(0xFF2D2F33);
  static const Color drawerRaised = Color(0xFF36383D);
  static const Color drawerSelected = Color(0xFF3C3D48);
  static const Color drawerBorder = Color(0xFF484A4F);
  static const Color drawerText = Color(0xFFE7E1D8);
  static const Color drawerTextMuted = Color(0xFFB7B1A9);

  static const Color success = Color(0xFF28724E);
  static const Color warning = Color(0xFF9B5D18);
  static const Color warningSoft = Color(0xFFF9EBD7);
  static const Color danger = Color(0xFFA54842);
  static const Color dangerSoft = Color(0xFFF8E4E1);
}
