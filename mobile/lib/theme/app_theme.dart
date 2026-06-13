import 'package:flutter/material.dart';
import 'app_colors.dart';

/// Thème clair de l'application (Material 3).
class AppTheme {
  AppTheme._();
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.bleuNuit,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.bleuNuit,
      secondary: AppColors.orange,
      surface: Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.page,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bleuNuit,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.orange,
        foregroundColor: Colors.white,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: Colors.white,
        ),
      ),
    );
  }
}
