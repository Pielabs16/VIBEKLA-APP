import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color backgroundColor = Color(0xFF0a0014);
  static const Color primaryColor = Color(0xFFff2d92);
  static const Color accentColor = Color(0xFFb026ff);
  static const Color surfaceColor = Color(0xFF160826);
  static const Color surface2Color = Color(0xFF0f0520);
  static const Color onSurfaceColor = Color(0xFFf5f0ff);
  static const Color mutedColor = Color(0xFF9b85b8);
  static const Color borderColor = Color(0xFF2a1647);

  static const Color lightBg = Color(0xFFF8F5FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurface2 = Color(0xFFF0EAFF);
  static const Color lightOnSurface = Color(0xFF1A0033);
  static const Color lightMuted = Color(0xFF7A6895);
  static const Color lightBorder = Color(0xFFE0D4F7);

  static Color cardColor(String imageType) {
    switch (imageType) {
      case 'neon':   return const Color(0xFF4A0080);
      case 'gold':   return const Color(0xFF8B3D00);
      case 'electric': return const Color(0xFF003B8B);
      case 'jungle': return const Color(0xFF005C2E);
      case 'fire':   return const Color(0xFF7A0000);
      case 'dark':   return const Color(0xFF0E0030);
      default:       return accentColor;
    }
  }

  static BoxDecoration glassDecoration({double opacity = 0.15, double radius = 16}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: opacity),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
    );
  }

  static List<BoxShadow> glowShadow(Color color, {double intensity = 0.2}) {
    return [BoxShadow(color: color.withValues(alpha: intensity), blurRadius: 12, spreadRadius: 0)];
  }

  static TextTheme _darkTextTheme() => GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: onSurfaceColor, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: onSurfaceColor, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: onSurfaceColor),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: onSurfaceColor),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: onSurfaceColor),
      bodyLarge:     TextStyle(fontSize: 15, color: onSurfaceColor, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 14, color: onSurfaceColor),
      bodySmall:     TextStyle(fontSize: 12, color: Color(0xFF9b85b8), height: 1.4),
      labelSmall:    TextStyle(fontSize: 11, color: Color(0xFF6b5580)),
    ),
  );

  static TextTheme _lightTextTheme() => GoogleFonts.interTextTheme(
    const TextTheme(
      displayLarge:  TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: lightOnSurface, letterSpacing: -0.5),
      headlineLarge: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: lightOnSurface, letterSpacing: -0.5),
      headlineMedium:TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: lightOnSurface),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: lightOnSurface),
      titleLarge:    TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: lightOnSurface),
      bodyLarge:     TextStyle(fontSize: 15, color: lightOnSurface, height: 1.5),
      bodyMedium:    TextStyle(fontSize: 14, color: lightOnSurface),
      bodySmall:     TextStyle(fontSize: 12, color: lightMuted, height: 1.4),
      labelSmall:    TextStyle(fontSize: 11, color: lightMuted),
    ),
  );

  static ThemeData get darkTheme {
    final textTheme = _darkTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      textTheme: textTheme,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: accentColor,
        surface: surfaceColor,
        onSurface: onSurfaceColor,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: backgroundColor,
        foregroundColor: onSurfaceColor,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: onSurfaceColor),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceColor,
        hintStyle: const TextStyle(color: Color(0xFF666666)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF2a1647), width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF2a1647), thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF100020),
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFF666666),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get lightTheme {
    final textTheme = _lightTextTheme();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: lightBg,
      textTheme: textTheme,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: accentColor,
        surface: lightSurface,
        onSurface: lightOnSurface,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightSurface,
        foregroundColor: lightOnSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w600, color: lightOnSurface),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: lightSurface,
        hintStyle: const TextStyle(color: Color(0xFFAAAAAA)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: lightBorder, width: 1)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: primaryColor, width: 1.5)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      dividerTheme: const DividerThemeData(color: lightBorder, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        clipBehavior: Clip.antiAlias,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: lightSurface,
        selectedItemColor: primaryColor,
        unselectedItemColor: Color(0xFFAAAAAA),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
