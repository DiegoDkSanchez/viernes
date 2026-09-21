import 'package:flutter/material.dart';

const orange = Color(0xFFF86818);
const green = Color(0xFF168653);
const ink = Color(0xFF141B32);

ThemeData appTheme() => ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: orange,
    primary: orange,
    secondary: green,
    surface: Colors.white,
  ),
  scaffoldBackgroundColor: const Color(0xFFF8FAFB),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFFF8FAFB),
    foregroundColor: ink,
    centerTitle: false,
    elevation: 0,
  ),
  textTheme: const TextTheme(
    headlineMedium: TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: ink,
    ),
    titleLarge: TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: ink,
    ),
    bodyMedium: TextStyle(color: Color(0xFF535D75), height: 1.4),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 1,
    shadowColor: const Color(0x18000000),
    margin: const EdgeInsets.only(bottom: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDE1E9)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Color(0xFFDDE1E9)),
    ),
  ),
  filledButtonTheme: FilledButtonThemeData(
    style: FilledButton.styleFrom(
      minimumSize: const Size(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  floatingActionButtonTheme: const FloatingActionButtonThemeData(
    backgroundColor: orange,
    foregroundColor: Colors.white,
  ),
  navigationBarTheme: NavigationBarThemeData(
    backgroundColor: Colors.white,
    indicatorColor: orange.withValues(alpha: .12),
  ),
);
