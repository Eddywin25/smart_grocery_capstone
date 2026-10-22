import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

class AppStyle {
  // Global Styling for Root Widget MaterialApp in default mode
  static ThemeData base = ThemeData(
    scaffoldBackgroundColor: AppColors.backgroundColor, 
    // Use for Material Widgets
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primaryColor,
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
    ),
    textTheme: AppTextStyles.textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: Color.fromARGB(255, 248, 236, 236),
      foregroundColor: Colors.black,
    ), 
    cardTheme: CardThemeData(
      color: Color.fromARGB(255, 216, 223, 191),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    ),
  );
}
