import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Brand colours
  static const Color primary = Color(0xFF6A5AE0);
  static const Color primaryLight = Color(0xFFB9ACFF);
  static const Color accent = Color(0xFFFF7A73);
  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFFFB347);
  static const Color danger = Color(0xFFEF5B5B);

  static const Color bgCanvas = Color(0xFFF5F0FF);
  static const Color bgCanvasSoft = Color(0xFFFBF9FF);
  static const Color bgDark = Color(0xFF141120);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color bgCardLight = Color(0xFFF2ECFF);
  static const Color textPrimary = Color(0xFF1B1A28);
  static const Color textSecondary = Color(0xFF5B5870);
  static const Color textMuted = Color(0xFF8B87A1);
  static const Color divider = Color(0xFFE4DBF3);
  static const Color shadow = Color(0x0F1B1A28);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        scaffoldBackgroundColor: bgCanvas,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: bgCard,
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          iconTheme: IconThemeData(color: textPrimary),
        ),
        cardColor: bgCard,
        cardTheme: CardThemeData(
          color: bgCard,
          elevation: 0,
          shadowColor: shadow,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: textPrimary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: bgCard,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: danger),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: textSecondary),
          hintStyle: const TextStyle(color: textMuted),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: textPrimary, fontSize: 36, fontWeight: FontWeight.w800, height: 1.0),
          displayMedium: TextStyle(color: textPrimary, fontSize: 28, fontWeight: FontWeight.w800, height: 1.05),
          titleLarge: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: textPrimary, fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: textPrimary, fontSize: 16),
          bodyMedium: TextStyle(color: textSecondary, fontSize: 14, height: 1.35),
          bodySmall: TextStyle(color: textMuted, fontSize: 12, height: 1.3),
        ),
        dividerTheme: const DividerThemeData(color: divider, thickness: 1),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: bgCard,
          selectedItemColor: primary,
          unselectedItemColor: textMuted,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : textMuted,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary.withOpacity(0.4) : bgCardLight,
          ),
        ),
        sliderTheme: const SliderThemeData(
          activeTrackColor: primary,
          thumbColor: primary,
          inactiveTrackColor: bgCardLight,
          overlayColor: Color(0x336C63FF),
          trackHeight: 6,
          thumbShape: RoundSliderThumbShape(enabledThumbRadius: 10),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF100F1B),
        colorScheme: const ColorScheme.dark(
          primary: primaryLight,
          secondary: accent,
          surface: Color(0xFF1A1B2A),
          error: danger,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          iconTheme: IconThemeData(color: Colors.white),
        ),
        cardColor: const Color(0xFF1A1B2A),
        cardTheme: CardThemeData(
          color: const Color(0xFF1A1B2A),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 52),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
            textStyle: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1F2030),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: Color(0xFF2F3146)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: primaryLight, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: danger),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          labelStyle: const TextStyle(color: Color(0xFFB7B8CC)),
          hintStyle: const TextStyle(color: Color(0xFF8A8CA5)),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800, height: 1.0),
          displayMedium: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, height: 1.05),
          titleLarge: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          titleMedium: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: TextStyle(color: Colors.white, fontSize: 16),
          bodyMedium: TextStyle(color: Color(0xFFD1D2E1), fontSize: 14, height: 1.35),
          bodySmall: TextStyle(color: Color(0xFFA6A8BC), fontSize: 12, height: 1.3),
        ),
        dividerTheme: const DividerThemeData(color: Color(0xFF2F3146), thickness: 1),
      );
}
