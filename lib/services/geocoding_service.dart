import 'dart:convert';

import 'package:http/http.dart' as http;

/// Reverse geocoding via [Nominatim](https://nominatim.org/) (OpenStreetMap).
/// Use sparingly; cache results in production and respect their usage policy.
class GeocodingService {
  GeocodingService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _userAgent = 'BloodNow/1.0 (local development; no prod traffic)';

  Future<String?> reverseLookup(double latitude, double longitude) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/reverse', {
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'format': 'json',
    });
    final res = await _client.get(
      uri,
      headers: {'User-Agent': _userAgent},
    );
    if (res.statusCode != 200) return null;
    final data = jsonDecode(res.body);
    if (data is! Map<String, dynamic>) return null;
    final name = data['display_name'];
    return name is String ? name : null;
  }

  void close() {
    _client.close();
  }
}
