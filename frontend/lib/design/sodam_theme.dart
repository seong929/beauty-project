import 'package:flutter/material.dart';

const sodamGreen = Color(0xFF375B46);
const sodamCream = Color(0xFFF6F5F0);
const sodamBorder = Color(0xFFE5E5DD);

ThemeData sodamTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: sodamGreen,
    primary: sodamGreen,
    surface: Colors.white,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: sodamCream,
    dividerColor: sodamBorder,
    textTheme: ThemeData.light().textTheme.apply(
      bodyColor: const Color(0xFF29392F),
      displayColor: const Color(0xFF29392F),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: sodamCream,
      foregroundColor: Color(0xFF29392F),
      scrolledUnderElevation: 0,
      centerTitle: false,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: sodamBorder),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sodamBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: sodamBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(44, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(44, 44),
        side: const BorderSide(color: sodamBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: sodamGreen,
      selectedColor: sodamGreen,
      selectedTileColor: const Color(0xFFE7EEE4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    dataTableTheme: const DataTableThemeData(
      headingRowColor: WidgetStatePropertyAll(Color(0xFFF0F3ED)),
      dividerThickness: 0.6,
      horizontalMargin: 24,
    ),
    chipTheme: ChipThemeData(
      side: const BorderSide(color: sodamBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  );
}
