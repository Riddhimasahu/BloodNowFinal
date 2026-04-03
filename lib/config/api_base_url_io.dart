import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kDebugMode;

/// On Android **emulator**, `127.0.0.1` is the emulator itself, not your PC.
/// `10.0.2.2` forwards to the host machine. Physical devices still need
/// `--dart-define=API_BASE_URL=http://<your-pc-lan-ip>:3000`.
String resolveApiBaseUrl() {
  const fromEnv = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );
  if (fromEnv.isNotEmpty) return fromEnv;
  if (kDebugMode && Platform.isAndroid) {
    return 'http://10.0.2.2:3000';
  }
  return 'http://127.0.0.1:3000';
}
