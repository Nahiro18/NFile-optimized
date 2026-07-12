import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color seedColor = Color(0xFF6B7280);
  
  static ThemeData getAppTheme({
    required bool light,
    bool pitchBlack = false,
    Color? seed,
    ColorScheme? customScheme,
    String fontFamily = 'default',
  }) {
    final rawColor = seed ?? seedColor;
    final brightness = light ? Brightness.light : Brightness.dark;

    ColorScheme colorScheme;
    if (customScheme != null) {
      colorScheme = customScheme.copyWith(brightness: brightness);
    } else {
      final baseScheme = ColorScheme.fromSeed(
        seedColor: rawColor,
        brightness: brightness,
        contrastLevel: 0.0,
        dynamicSchemeVariant: DynamicSchemeVariant.neutral,
      );
      colorScheme = baseScheme;
    }

    final scaffoldBg = light 
        ? const Color(0xFFFAFAFA) 
        : (pitchBlack ? const Color(0xFF000000) : const Color(0xFF0D0D0D));
    final cardBg = light 
        ? const Color(0xFFFFFFFF) 
        : (pitchBlack ? const Color(0xFF0A0A0A) : const Color(0xFF141414));
    final surfaceBg = light 
        ? const Color(0xFFF5F5F5) 
        : (pitchBlack ? const Color(0xFF080808) : const Color(0xFF111111));

    final borderColor = light 
        ? const Color(0xFFE5E5E5) 
        : const Color(0xFF2A2A2A);

    String? effectiveFontFamily;
    TextTheme? textTheme;
    final baseTextTheme = ThemeData(brightness: brightness).textTheme;

    switch (fontFamily) {
      case 'nothing':
        effectiveFontFamily = 'NType82';
        textTheme = const TextTheme(
          displayLarge: TextStyle(fontFamily: 'Ndot57'),
          displayMedium: TextStyle(fontFamily: 'Ndot57'),
          displaySmall: TextStyle(fontFamily: 'Ndot57'),
          headlineLarge: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          headlineMedium: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          headlineSmall: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleLarge: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleMedium: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          titleSmall: TextStyle(fontFamily: 'Ndot57', fontWeight: FontWeight.bold),
          bodyLarge: TextStyle(fontFamily: 'NType82'),
          bodyMedium: TextStyle(fontFamily: 'NType82'),
          bodySmall: TextStyle(fontFamily: 'NType82'),
          labelLarge: TextStyle(fontFamily: 'NType82', fontWeight: FontWeight.bold),
          labelMedium: TextStyle(fontFamily: 'NType82'),
          labelSmall: TextStyle(fontFamily: 'NType82'),
        );
        break;
      case 'outfit':
        effectiveFontFamily = 'Outfit';
        textTheme = GoogleFonts.outfitTextTheme(baseTextTheme);
        break;
      case 'jetbrains':
        effectiveFontFamily = 'JetBrains Mono';
        textTheme = GoogleFonts.jetBrainsMonoTextTheme(baseTextTheme);
        break;
      case 'montserrat':
        effectiveFontFamily = 'Montserrat';
        textTheme = GoogleFonts.montserratTextTheme(baseTextTheme);
        break;
      case 'custom':
        effectiveFontFamily = 'CustomFont';
        break;
      case 'default':
      default:
        effectiveFontFamily = null;
        break;
    }

    final textColor = light ? const Color(0xFF1A1A1A) : const Color(0xFFE8E8E8);
    final mutedColor = light ? const Color(0xFF757575) : const Color(0xFF999999);

    return ThemeData(
      brightness: brightness,
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: effectiveFontFamily,
      textTheme: textTheme,
      fontFamilyFallback: const ['sans-serif', 'Roboto'],
      scaffoldBackgroundColor: scaffoldBg,
      splashColor: Colors.transparent,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      applyElevationOverlayColor: false,
      dividerColor: borderColor,
      dividerTheme: DividerThemeData(
        thickness: 1,
        color: borderColor,
        space: 0,
      ),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: scaffoldBg,
        iconTheme: IconThemeData(color: textColor),
        actionsIconTheme: IconThemeData(color: textColor),
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          fontFamily: effectiveFontFamily,
        ),
      ),
      cardColor: cardBg,
      cardTheme: CardThemeData(
        elevation: 0,
        color: cardBg,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
      ),
      dialogTheme: DialogThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: borderColor),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        color: cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: borderColor),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        elevation: 0,
        backgroundColor: scaffoldBg,
        selectedItemColor: textColor,
        unselectedItemColor: mutedColor,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: scaffoldBg,
        indicatorColor: borderColor,
        labelTextStyle: WidgetStatePropertyAll(TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        )),
        iconTheme: WidgetStatePropertyAll(IconThemeData(color: mutedColor)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        isDense: true,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        backgroundColor: cardBg,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: borderColor),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textColor,
        ),
      ),
    );
  }

  static ThemeData get lightTheme => getAppTheme(light: true);
  static ThemeData get darkTheme => getAppTheme(light: false);
}
