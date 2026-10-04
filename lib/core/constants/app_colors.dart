import 'package:flutter/material.dart';

class AppColors {
  // Brand colors
  static const Color ieeeBlue = Color(0xFF00629B);
  static const Color ieeeDark = Color(0xFF001F3F);
  static const Color ieeeLight = Color(0xFF0075BC);

  // Status Colors (Tailwind)
  static const Color success = Color(0xFF10B981); // emerald-500
  static const Color warning = Color(0xFFF59E0B); // amber-500
  static const Color error = Color(0xFFE11D48);   // rose-600
  static const Color info = Color(0xFF3B82F6);    // blue-500

  // Background / Surface Colors (Tailwind Neutral)
  static const Color neutral950 = Color(0xFF0A0A0A);
  static const Color neutral900 = Color(0xFF171717);
  static const Color neutral800 = Color(0xFF262626);
  static const Color neutral700 = Color(0xFF404040);
  
  static const Color background = neutral950;
  static const Color surface = neutral900;
  
  // Text Colors
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA3A3A3); // neutral-400
}
