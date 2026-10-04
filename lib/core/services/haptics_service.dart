import 'package:flutter/services.dart';

class HapticsService {
  static Future<void> success() async {
    await HapticFeedback.mediumImpact();
  }

  static Future<void> warning() async {
    await HapticFeedback.heavyImpact();
  }

  static Future<void> error() async {
    await HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    await HapticFeedback.heavyImpact();
  }
}
