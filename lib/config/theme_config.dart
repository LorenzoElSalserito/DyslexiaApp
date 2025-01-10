import 'package:flutter/material.dart';

class ThemeConfig {
  static ThemeData get lightTheme {
    return ThemeData(
      primarySwatch: Colors.blue,
      fontFamily: 'OpenDyslexic',
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        bodyLarge: TextStyle(
          fontSize: 18,
          letterSpacing: 0.3,
          height: 1.5,
        ),
      ),
    );
  }

  // Colori personalizzati per la gamification
  static const Color achievementColor = Color(0xFFFFD700);
  static const Color progressColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFE57373);
  static const Color successColor = Color(0xFF81C784);
}