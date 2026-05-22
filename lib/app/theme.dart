import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Aurora theme — vibrant gradient accents with soft rounded shapes
class AppColors {
  // Gradients
  static const Color gradientStart = Color(0xFF7C4DFF);
  static const Color gradientEnd = Color(0xFF00D4FF);

  // Surface and background
  static const Color background = Color(0xFFF6FBFF);
  static const Color surface = Color(0xFFFFFFFF);

  // Bubble colors
  static const Color incomingBubble = Color(0xFFF0F6FF);
  static const Color outgoingBubble = Color(0xFF6F4CFF);

  // Accents
  static const Color accent = Color(0xFF2B2B2B);
  static const Color unreadBadge = Color(0xFFFF6B6B);

  // Typography
  static const Color textPrimary = Color(0xFF0F1722);
  static const Color textSecondary = Color(0xFF6B7280);
}

ThemeData buildAppTheme() {
  final base = ThemeData.light();

  final colorScheme = ColorScheme.fromSeed(
    seedColor: AppColors.gradientStart,
    brightness: Brightness.light,
  );

  return base.copyWith(
    colorScheme: colorScheme,
    primaryColor: AppColors.gradientStart,
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.textPrimary,
      elevation: 1,
      centerTitle: false,
      titleTextStyle: GoogleFonts.rubik(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
    ),
    textTheme: GoogleFonts.rubikTextTheme(
      base.textTheme,
    ).apply(bodyColor: AppColors.textPrimary),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        textStyle: GoogleFonts.rubik(fontWeight: FontWeight.w600),
      ),
    ),
    cardTheme: base.cardTheme.copyWith(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    iconTheme: const IconThemeData(color: AppColors.gradientStart),
  );
}
