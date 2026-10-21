import 'package:flutter/material.dart';

ThemeData otoTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme =
      ColorScheme.fromSeed(
        seedColor: const Color(0xFFC53D43),
        brightness: brightness,
      ).copyWith(
        primary: dark ? const Color(0xFFFFA5AE) : const Color(0xFFAD303B),
        onPrimary: dark ? const Color(0xFF590D1B) : Colors.white,
        surface: dark ? const Color(0xFF11131D) : const Color(0xFFFAF7F2),
        onSurface: dark ? const Color(0xFFF1EAE3) : const Color(0xFF25211F),
        onSurfaceVariant: dark
            ? const Color(0xFFBEB6C5)
            : const Color(0xFF6B605C),
        surfaceContainerLow: dark
            ? const Color(0xFF1A1C28)
            : const Color(0xFFF0EBE4),
        surfaceContainer: dark
            ? const Color(0xFF222431)
            : const Color(0xFFECE5DC),
        surfaceContainerHigh: dark
            ? const Color(0xFF2A2B39)
            : const Color(0xFFE6DFD7),
        outlineVariant: dark
            ? const Color(0xFF45414D)
            : const Color(0xFFD8CFC6),
      );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
  );
  final text = base.textTheme.copyWith(
    headlineLarge: base.textTheme.headlineLarge!.copyWith(
      fontFamily: 'serif',
      fontSize: 38,
      height: 1.15,
      letterSpacing: -0.8,
    ),
    headlineMedium: base.textTheme.headlineMedium!.copyWith(
      fontFamily: 'serif',
      height: 1.2,
      letterSpacing: -0.5,
    ),
    titleLarge: base.textTheme.titleLarge!.copyWith(
      fontFamily: 'serif',
      fontSize: 23,
    ),
    titleMedium: base.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w600,
    ),
    bodyMedium: base.textTheme.bodyMedium!.copyWith(height: 1.5),
  );
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      toolbarHeight: 72,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      height: 76,
      indicatorColor: scheme.primaryContainer,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: base.textTheme.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
  );
}
