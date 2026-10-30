import 'package:flutter/material.dart';

const operationsGreen = Color(0xFF24624C);
const operationsInk = Color(0xFF20312B);
const operationsMuted = Color(0xFF687771);
const operationsBorder = Color(0xFFE2E9E5);
const operationsBackground = Color(0xFFF5F7F6);

/// Imported only by the dedicated ADMIN and DELIVERY entry points.
ThemeData operationsTheme() => ThemeData(
  useMaterial3: true,
  fontFamily: 'NotoSansKR',
  colorScheme: ColorScheme.fromSeed(
    seedColor: operationsGreen,
    primary: operationsGreen,
    surface: Colors.white,
    onSurface: operationsInk,
    outline: operationsBorder,
    surfaceTint: Colors.transparent,
  ),
  scaffoldBackgroundColor: operationsBackground,
  textTheme: const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: operationsInk,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: operationsInk,
    ),
    titleMedium: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: operationsInk,
    ),
    bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: operationsInk),
    bodySmall: TextStyle(fontSize: 12, height: 1.5, color: operationsMuted),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: operationsInk,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    toolbarHeight: 68,
    titleTextStyle: TextStyle(
      fontFamily: 'NotoSansKR',
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: operationsInk,
    ),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    surfaceTintColor: Colors.transparent,
    elevation: 0,
    margin: const EdgeInsets.symmetric(vertical: 6),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: const BorderSide(color: operationsBorder),
    ),
  ),
  dividerTheme: const DividerThemeData(color: operationsBorder, space: 1),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: operationsBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(9),
      borderSide: const BorderSide(color: operationsBorder),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(44, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: operationsGreen,
      foregroundColor: Colors.white,
      elevation: 0,
      minimumSize: const Size(44, 46),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(44, 44),
      side: const BorderSide(color: operationsBorder),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: Colors.white,
    selectedColor: const Color(0xFFE8F2ED),
    side: const BorderSide(color: operationsBorder),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
  ),
  listTileTheme: const ListTileThemeData(
    selectedColor: operationsGreen,
    selectedTileColor: Color(0xFFEBF3EF),
    contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 6),
  ),
);
