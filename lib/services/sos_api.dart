import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class SosApi {
  SosApi({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<SosResult> sendSosRequest(
    String token, {
    required String bloodGroup,
    required double lat,
    required double lng,
  }) async {
    final res = await _client.post(
      _u('/api/sos-request'),
      headers: _headers(token),
      body: jsonEncode({
        'bloodGroup': bloodGroup,
        'location': {
          'lat': lat,
          'lng': lng,
        }
      }),
    );

    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final count = decoded['donorsNotifiedCount'] ?? 0;
      return SosResult.ok(count as int);
    }

    return SosResult.error(_err(decoded, res.statusCode));
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _err(dynamic decoded, int status) {
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    if (decoded is Map && decoded['errors'] is List) {
      final list = decoded['errors'] as List;
      if (list.isNotEmpty && list.first is Map) {
        final msg = (list.first as Map)['msg'];
        if (msg is String) return msg;
      }
    }
    return 'Request failed ($status)';
  }
}

class SosResult {
  SosResult._({this.donorsNotifiedCount, this.errorMessage});
  factory SosResult.ok(int count) => SosResult._(donorsNotifiedCount: count);
  factory SosResult.error(String message) => SosResult._(errorMessage: message);

  final int? donorsNotifiedCount;
  final String? errorMessage;
  bool get isSuccess => errorMessage == null;
}
