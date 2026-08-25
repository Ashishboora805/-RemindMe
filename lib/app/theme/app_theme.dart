import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'colors.dart';
import 'typography.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness b) {
    final isDark = b == Brightness.dark;
    final scheme = ColorScheme(
      brightness: b,
      primary: AppColors.projectAccents.first,
      onPrimary: Colors.white,
      secondary: AppColors.projectAccents[3],
      onSecondary: Colors.white,
      error: AppColors.danger,
      onError: Colors.white,
      surface: isDark ? AppColors.darkBackgroundBottom : Colors.white,
      onSurface: AppColors.textPrimary(b),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          isDark ? AppColors.darkBackgroundTop : AppColors.lightBackgroundTop,
      textTheme: TextTheme(
        displayLarge: AppTypography.largeTitle(b),
        headlineMedium: AppTypography.title1(b),
        titleLarge: AppTypography.title2(b),
        titleMedium: AppTypography.headline(b),
        bodyLarge: AppTypography.body(b),
        bodyMedium: AppTypography.callout(b),
        bodySmall: AppTypography.caption(b),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      }),
    );
  }

  /// Background gradient used behind glass surfaces on every screen.
  static LinearGradient backgroundGradient(Brightness b) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: b == Brightness.dark
            ? [AppColors.darkBackgroundTop, AppColors.darkBackgroundBottom]
            : [AppColors.lightBackgroundTop, AppColors.lightBackgroundBottom],
      );
}
