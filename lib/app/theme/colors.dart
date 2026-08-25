import 'package:flutter/cupertino.dart';

/// Central color palette for the Liquid Glass design system.
/// Never hardcode colors in feature widgets — always reference this file.
class AppColors {
  AppColors._();

  // Brand accents (also selectable as project accent colors)
  static const List<Color> projectAccents = [
    Color(0xFF6C63FF), // violet
    Color(0xFF3DDC97), // mint
    Color(0xFFFF7A59), // coral
    Color(0xFF4FA0FF), // sky
    Color(0xFFFFC542), // amber
    Color(0xFFFF5C8A), // pink
    Color(0xFF57D9C6), // teal
    Color(0xFFB98CFF), // lavender
  ];

  // Light theme surfaces
  static const Color lightBackgroundTop = Color(0xFFF3F5FC);
  static const Color lightBackgroundBottom = Color(0xFFE7ECF8);
  static const Color lightGlassFill = Color(0xB3FFFFFF); // white @ 70%
  static const Color lightGlassBorder = Color(0x59FFFFFF); // white @ 35%
  static const Color lightTextPrimary = Color(0xFF1C1C28);
  static const Color lightTextSecondary = Color(0xFF6B6F80);

  // Dark theme surfaces
  static const Color darkBackgroundTop = Color(0xFF0E0E14);
  static const Color darkBackgroundBottom = Color(0xFF17171F);
  static const Color darkGlassFill = Color(0x33FFFFFF); // white @ 20%
  static const Color darkGlassBorder = Color(0x26FFFFFF); // white @ 15%
  static const Color darkTextPrimary = Color(0xFFF5F5FA);
  static const Color darkTextSecondary = Color(0xFFA1A1B0);

  static const Color danger = Color(0xFFFF453A);
  static const Color warning = Color(0xFFFFB020);
  static const Color success = Color(0xFF34C759);

  static Color glassFill(Brightness b) =>
      b == Brightness.dark ? darkGlassFill : lightGlassFill;
  static Color glassBorder(Brightness b) =>
      b == Brightness.dark ? darkGlassBorder : lightGlassBorder;
  static Color textPrimary(Brightness b) =>
      b == Brightness.dark ? darkTextPrimary : lightTextPrimary;
  static Color textSecondary(Brightness b) =>
      b == Brightness.dark ? darkTextSecondary : lightTextSecondary;
}
