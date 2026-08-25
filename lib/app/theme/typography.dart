import 'package:flutter/cupertino.dart';
import 'colors.dart';

/// Typography scale built on the platform's own UI font: SF Pro on iOS and
/// Roboto on Android, which is exactly what this design targets.
///
/// This deliberately does NOT use `google_fonts`. That package downloads font
/// files over HTTP on first use, and this app ships without the INTERNET
/// permission — so the download always failed and every label fell back to a
/// generic monospace face. An offline-first app must not depend on a network
/// fetch to render its own text. If you want a specific family instead, bundle
/// the .ttf files under `assets/` and set [_fontFamily].
class AppTypography {
  AppTypography._();

  /// Null means "use the platform default UI font".
  static const String? _fontFamily = null;

  static TextStyle _base(Brightness b) => TextStyle(
        fontFamily: _fontFamily,
        color: AppColors.textPrimary(b),
        height: 1.3,
        // Without an explicit `none`, text inherits DefaultTextStyle.fallback()'s
        // yellow double underline anywhere a Material ancestor is absent.
        decoration: TextDecoration.none,
      );

  static TextStyle largeTitle(Brightness b) => _base(b).copyWith(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );

  static TextStyle title1(Brightness b) => _base(b).copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w700,
      );

  static TextStyle title2(Brightness b) => _base(b).copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
      );

  static TextStyle headline(Brightness b) => _base(b).copyWith(
        fontSize: 17,
        fontWeight: FontWeight.w600,
      );

  static TextStyle body(Brightness b) => _base(b).copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
      );

  static TextStyle callout(Brightness b) => _base(b).copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(b),
      );

  static TextStyle caption(Brightness b) => _base(b).copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary(b),
      );
}
