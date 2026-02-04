import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'screens/login_screen.dart';

class ChatApp extends StatelessWidget {
  const ChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF0C8A6A);
    const surface = Color(0xFFF6F4EF);
    const surfaceAlt = Color(0xFFE7F3EF);
    const outline = Color(0xFFE3DED4);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: brand,
      brightness: Brightness.light,
      surface: surface,
      surfaceVariant: surfaceAlt,
    );

    final baseTextTheme = GoogleFonts.plusJakartaSansTextTheme();

    return MaterialApp(
      title: 'CESI Chat',
      theme: ThemeData(
        colorScheme: colorScheme,
        scaffoldBackgroundColor: surface,
        textTheme: baseTextTheme.copyWith(
          headlineLarge: GoogleFonts.poppins(
            fontSize: 34,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
          headlineSmall: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          titleLarge: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
          titleMedium: baseTextTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
          bodyLarge: baseTextTheme.bodyLarge?.copyWith(height: 1.4),
          bodyMedium: baseTextTheme.bodyMedium?.copyWith(height: 1.4),
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          iconTheme: IconThemeData(color: colorScheme.onSurface),
          titleTextStyle: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
        cardTheme: CardThemeData(
          color: Colors.white.withOpacity(0.95),
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: outline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: colorScheme.primary, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: colorScheme.primary,
            foregroundColor: colorScheme.onPrimary,
            textStyle: baseTextTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: const StadiumBorder(),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: colorScheme.primary,
            textStyle: baseTextTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: colorScheme.primaryContainer,
          labelStyle: baseTextTheme.labelMedium?.copyWith(
            color: colorScheme.onPrimaryContainer,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
        listTileTheme: ListTileThemeData(
          iconColor: colorScheme.primary,
          textColor: colorScheme.onSurface,
        ),
        dividerTheme: const DividerThemeData(
          color: outline,
          thickness: 1,
          space: 24,
        ),
        snackBarTheme: SnackBarThemeData(
          backgroundColor: colorScheme.onSurface,
          contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
            color: colorScheme.surface,
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
