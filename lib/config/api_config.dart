import 'api_base_url_io.dart'
    if (dart.library.html) 'api_base_url_web.dart' as url_impl;

/// Backend base URL.
/// Override anytime: `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000`
abstract final class ApiConfig {
  static String get baseUrl => url_impl.resolveApiBaseUrl();
}
