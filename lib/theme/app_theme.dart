import 'package:flutter/material.dart';

class AppTheme {
  static const Color bgDark = Color(0xFF030303);
  static const Color surfaceDark = Color(0xFF141414);
  static const Color cardDark = Color(0xFF212121);
  static const Color chipBackground = Color(0xFF272727);
  static const Color chipActiveBackground = Color(0xFFFFFFFF);
  
  static const Color redAccent = Color(0xFFFF0000);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAAAAAA);
  static const Color textMuted = Color(0xFF717171);
  static const Color dividerColor = Color(0xFF2A2A2A);

  // Gradient for "Música que te gustó" card
  static const LinearGradient likedSongsGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE040FB),
      Color(0xFF7C4DFF),
      Color(0xFF448AFF),
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      primaryColor: redAccent,
      canvasColor: bgDark,
      cardColor: cardDark,
      dividerColor: dividerColor,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: bgDark,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: bgDark,
        modalBackgroundColor: bgDark,
      ),
    );
  }
}
