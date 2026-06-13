import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pointage/theme/app_colors.dart';
import 'package:pointage/theme/app_theme.dart';

void main() {
  test('AppColors expose les couleurs de marque', () {
    expect(AppColors.bleuNuit, const Color(0xFF1A3C5E));
    expect(AppColors.orange, const Color(0xFFE67E22));
  });
  test('AppTheme.light est clair, primary bleu nuit, secondary orange', () {
    final t = AppTheme.light();
    expect(t.brightness, Brightness.light);
    expect(t.colorScheme.primary, AppColors.bleuNuit);
    expect(t.colorScheme.secondary, AppColors.orange);
    expect(t.useMaterial3, isTrue);
  });
}
