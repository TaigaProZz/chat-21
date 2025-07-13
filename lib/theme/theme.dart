import 'package:flutter/material.dart';

ThemeData lightMode = ThemeData(
  brightness: Brightness.light,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.light,
    seedColor: Colors.deepPurple,
    primary: Colors.deepPurple,
    onPrimary: Colors.white,
    secondary: Colors.deepPurple.shade200,
    onSecondary: Colors.black87,
  ),
);

ThemeData darkMode = ThemeData(
  brightness: Brightness.dark,
  colorScheme: ColorScheme.fromSeed(
    brightness: Brightness.dark,
    seedColor: Colors.deepPurple,
    primary: Colors.deepPurple,
    onPrimary: Colors.white,
    secondary: Colors.deepPurple.shade200,
    onSecondary: Colors.black87,
  ),
);
 