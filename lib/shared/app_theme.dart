import 'package:flutter/material.dart';

/// Centralized app theme for EthioStreetFix — improves visual consistency
/// and accessibility (contrast, spacing, scalable type).
class AppTheme {
  static final ColorScheme _scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF1B5E20), // deep green brand seed
    brightness: Brightness.light,
  );

  static ThemeData get theme {
    return ThemeData(
      colorScheme: _scheme,
      useMaterial3: true,

      // App-wide typography tuned for legibility on mobile and web
      textTheme: Typography.material2021(platform: TargetPlatform.android).black
          .copyWith(
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
            bodyLarge: const TextStyle(fontSize: 16),
            bodyMedium: const TextStyle(fontSize: 14),
          ),

      // Elevated button style
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
        ),
      ),

      // Input decoration (forms)
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 12,
          horizontal: 16,
        ),
      ),

      // App bar
      appBarTheme: AppBarTheme(
        backgroundColor: _scheme.primary,
        foregroundColor: _scheme.onPrimary,
        elevation: 2,
        centerTitle: true,
      ),

      // Card and surface styling (use defaults from Material3 to avoid SDK mismatch)

      // Accessibility defaults
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }

  /// Dark theme counterpart that preserves brand accents while using
  /// high-contrast surfaces suitable for low-light environments.
  static ThemeData get darkTheme {
    final dark = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B5E20),
      brightness: Brightness.dark,
    );
    return ThemeData(
      colorScheme: dark,
      useMaterial3: true,
      brightness: Brightness.dark,
      appBarTheme: AppBarTheme(
        backgroundColor: dark.primary,
        foregroundColor: dark.onPrimary,
        centerTitle: true,
      ),
      textTheme: Typography.material2021(platform: TargetPlatform.android).white
          .copyWith(
            titleLarge: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
    );
  }
}
