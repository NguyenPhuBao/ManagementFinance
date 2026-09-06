import 'package:flutter/material.dart';

class AppColors {
  // Background & Surface
  static const Color background = Color(0xFFEDEDE9);
  static const Color surface = Color(0xFFFFFFFF);

  // Primary (gần đen)
  static const Color primary = Color(0xFF1A1A19);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Semantic
  static const Color income = Color(0xFF4CAF50); // Thu nhập / Tích cực
  static const Color expense = Color(0xFFF25F5C); // Chi tiêu / Tiêu cực

  /// Mức cảnh báo giữa "ổn" và "sắp hỏng" — bậc VÀNG của thang bốn màu ngân
  /// sách (xanh lá → vàng → đỏ tươi → đỏ sẫm).
  ///
  /// Thêm ngày 2026-09-04: bảng màu vốn chỉ có xanh và hai sắc đỏ ([expense] đỏ
  /// tươi, [error] đỏ sẫm), nên trước đó "sắp chạm hạn mức" và "đã vượt" phải
  /// dùng chung một màu. Chọn tông hổ phách đậm thay vì vàng chanh để chữ 12px
  /// còn đọc được trên nền trắng.
  static const Color warning = Color(0xFFE08700);

  // Text
  static const Color textPrimary = Color(0xFF1A1C1A);
  static const Color textSecondary = Color(0xFF767872);

  // Border & Outline
  static const Color outline = Color(0xFFC6C7C1);
  static const Color outlineVariant = Color(0xFFE3E3DF);

  // Containers
  static const Color surfaceContainerLow = Color(0xFFF4F4F0);
  static const Color surfaceContainer = Color(0xFFEEEEEA);
  static const Color surfaceContainerHigh = Color(0xFFE8E8E4);

  // Error
  static const Color error = Color(0xFFBA1A1A);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Missing Aliases from M3
  static const Color secondary = income;
  static const Color onSecondary = surface;
  static const Color secondaryContainer = Color(0xFFA4F1B2);
  static const Color onSecondaryContainer = Color(0xFF0a7320);
  
  static const Color primaryContainer = primary;
  static const Color onPrimaryContainer = surface;

  static const Color onBackground = textPrimary;
  static const Color onSurface = textPrimary;
  static const Color onSurfaceVariant = textSecondary;
  
  static const Color surfaceVariant = outlineVariant;
  static const Color surfaceContainerHighest = outlineVariant;
  static const Color surfaceContainerLowest = surface;
  static const Color borderSubtle = outlineVariant;
}
