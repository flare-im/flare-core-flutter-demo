import 'package:flare_im/shared/theme/flare_theme_tokens.dart';
import 'package:flutter/material.dart';

/// 由 [FlareThemeTokens] 生成 [ThemeData]。
abstract final class AppTheme {
  static ThemeData light() {
    const colorScheme = ColorScheme.light(
      primary: FlareThemeTokens.primary,
      onPrimary: Colors.white,
      primaryContainer: FlareThemeTokens.bgSelected,
      onPrimaryContainer: FlareThemeTokens.textPrimary,
      secondary: FlareThemeTokens.bgSecondary,
      onSecondary: FlareThemeTokens.textPrimary,
      surface: FlareThemeTokens.bgSecondary,
      onSurface: FlareThemeTokens.textPrimary,
      error: FlareThemeTokens.error,
      onError: Colors.white,
      outline: FlareThemeTokens.borderPrimary,
      surfaceContainerHighest: FlareThemeTokens.bgPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FlareThemeTokens.bgSecondary,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: FlareThemeTokens.bgSecondary,
        foregroundColor: FlareThemeTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: FlareThemeTokens.textPrimary,
        ),
      ),
      dividerColor: FlareThemeTokens.borderSecondary,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: FlareThemeTokens.bgPrimary,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
          borderSide: const BorderSide(color: FlareThemeTokens.borderPrimary),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
          borderSide: const BorderSide(color: FlareThemeTokens.borderPrimary),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
          borderSide: const BorderSide(
            color: FlareThemeTokens.primary,
            width: 1.5,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlareThemeTokens.primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: FlareThemeTokens.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
        ),
      ),
      cardTheme: CardThemeData(
        color: FlareThemeTokens.bgPrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(FlareThemeTokens.radiusXl),
          side: const BorderSide(color: FlareThemeTokens.borderPrimary),
        ),
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: FlareThemeTokens.textPrimary,
        displayColor: FlareThemeTokens.textPrimary,
      ),
    );
  }

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: FlareThemeTokens.primaryHover,
      onPrimary: FlareDarkThemeTokens.textPrimary,
      primaryContainer: FlareDarkThemeTokens.bgSelected,
      onPrimaryContainer: FlareDarkThemeTokens.textPrimary,
      secondary: FlareDarkThemeTokens.bgSecondary,
      onSecondary: FlareDarkThemeTokens.textPrimary,
      surface: FlareDarkThemeTokens.bgSecondary,
      onSurface: FlareDarkThemeTokens.textPrimary,
      error: Color(0xFFFF5C33),
      onError: FlareDarkThemeTokens.textPrimary,
      outline: FlareDarkThemeTokens.borderPrimary,
      surfaceContainerHighest: FlareDarkThemeTokens.bgPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: FlareDarkThemeTokens.bgPrimary,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: FlareDarkThemeTokens.bgPrimary,
        foregroundColor: FlareDarkThemeTokens.textPrimary,
        surfaceTintColor: Colors.transparent,
      ),
      dividerColor: FlareDarkThemeTokens.borderPrimary,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: FlareThemeTokens.primaryHover,
        foregroundColor: Colors.white,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: FlareDarkThemeTokens.textPrimary,
        displayColor: FlareDarkThemeTokens.textPrimary,
      ),
    );
  }
}
