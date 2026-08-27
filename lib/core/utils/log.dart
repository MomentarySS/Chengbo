import 'package:flutter/foundation.dart';

/// 轻量日志工具。 Release 模式自动静默，Debug 模式走 `debugPrint`。
abstract final class AppLog {
  static void d(String tag, String message) {
    if (kDebugMode) {
      debugPrint('[$tag] $message');
    }
  }

  static void e(String tag, String message, {Object? error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      debugPrint('[$tag] ERROR: $message');
      if (error != null) debugPrint('[$tag] error: $error');
      if (stackTrace != null) debugPrint('[$tag] stack: $stackTrace');
    }
  }
}
