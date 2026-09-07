import 'package:flutter/services.dart';

/// Safe wrapper around Flutter's [HapticFeedback] that catches missing plugin
/// and platform exceptions on Web and Desktop environments without haptic hardware.
class AppHaptics {
  static void lightImpact() {
    try {
      HapticFeedback.lightImpact();
    } catch (_) {}
  }

  static void mediumImpact() {
    try {
      HapticFeedback.mediumImpact();
    } catch (_) {}
  }

  static void heavyImpact() {
    try {
      HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  static void selectionClick() {
    try {
      HapticFeedback.selectionClick();
    } catch (_) {}
  }
}
