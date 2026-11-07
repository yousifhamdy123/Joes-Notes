import 'package:flutter/services.dart';

/// Receives text shared from other apps ("Share" -> Joe's Notes).
/// The native side lives in MainActivity.kt (written by tool/patch_android.py).
class ShareIntent {
  static const _ch = MethodChannel('joes/share');
  static void Function(String text)? _onText;

  static void init(void Function(String text) onText) {
    _onText = onText;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'shared' && call.arguments is String) {
        _onText?.call(call.arguments as String);
      }
      return null;
    });
  }

  /// Text that launched the app (cold start).
  static Future<void> checkInitial() async {
    try {
      final s = await _ch.invokeMethod<String>('getShared');
      if (s != null && s.trim().isNotEmpty) _onText?.call(s);
    } catch (_) {}
  }
}
