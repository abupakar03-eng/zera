import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

/// Ring-buffer log capture so end users can share diagnostic output via the
/// system share sheet (e.g. WhatsApp/email) without needing `adb logcat`.
class DebugLog {
  static const int _maxLines = 500;
  static final Queue<String> _buffer = Queue<String>();

  static void i(String tag, String msg) {
    final ts = DateTime.now();
    final hh = ts.hour.toString().padLeft(2, '0');
    final mm = ts.minute.toString().padLeft(2, '0');
    final ss = ts.second.toString().padLeft(2, '0');
    final ms = ts.millisecond.toString().padLeft(3, '0');
    final line = '[$hh:$mm:$ss.$ms][$tag] $msg';
    _buffer.add(line);
    while (_buffer.length > _maxLines) {
      _buffer.removeFirst();
    }
    if (kDebugMode) debugPrint(line);
  }

  static String export() => _buffer.join('\n');

  static Future<void> shareViaSystem() async {
    final content = export();
    final body = content.isEmpty ? '(no logs captured yet)' : content;
    await Share.share(body, subject: 'ZERA debug log');
  }

  static void clear() => _buffer.clear();
}
