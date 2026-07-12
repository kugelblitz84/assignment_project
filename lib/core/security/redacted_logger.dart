import 'package:flutter/foundation.dart';

class RedactedLogger {
  const RedactedLogger._();

  static void info(String message) {
    if (kDebugMode) {
      debugPrint('[info] $message');
    }
  }

  static void warning(String message) {
    if (kDebugMode) {
      debugPrint('[warning] $message');
    }
  }

  static String phone(String value) {
    if (value.length <= 4) return '****';
    return '${value.substring(0, 2)}*****${value.substring(value.length - 2)}';
  }

  static String textLength(String value) => '${value.length} chars';
}
