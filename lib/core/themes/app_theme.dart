import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

ThemeData appTheme(BuildContext context) {
  return ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: AppColors.primaryColor,
    ),
    appBarTheme: const AppBarTheme(
      surfaceTintColor: AppColors.primaryColor,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(
        borderSide: const BorderSide(color: Color(0xFFD8D9DD)),
        borderRadius: BorderRadius.circular(6),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: AppColors.primaryColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Color(0xFFD8D9DD)),
      ),
      floatingLabelStyle: const TextStyle(color: AppColors.primaryColor),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    ),
    textTheme: GoogleFonts.robotoFlexTextTheme(),
  );
}
