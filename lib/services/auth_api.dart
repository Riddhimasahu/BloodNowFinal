import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthApi {
  AuthApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 25);

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<AuthResult> register(Map<String, dynamic> body) async {
    try {
      final res = await _client
          .post(
            _u('/api/auth/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _parseAuth(res);
    } on TimeoutException {
      return AuthResult.error(
        'Request timed out. Start the API (server folder: npm run dev) and check ${ApiConfig.baseUrl}',
      );
    } catch (e) {
      return AuthResult.error(
        'Cannot reach server at ${ApiConfig.baseUrl}. '
        'Use USB device? Run with --dart-define=API_BASE_URL=http://YOUR_PC_IP:3000\n($e)',
      );
    }
  }

  Future<AuthResult> login(String email, String password) async {
    try {
      final res = await _client
          .post(
            _u('/api/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);
      return _parseAuth(res);
    } on TimeoutException {
      return AuthResult.error(
        'Request timed out. Check API is running at ${ApiConfig.baseUrl}',
      );
    } catch (e) {
      return AuthResult.error(
        'Cannot reach server at ${ApiConfig.baseUrl}. ($e)',
      );
    }
  }

  Future<AuthResult> googleAuth(String idToken, [Map<String, dynamic>? extraFields]) async {
    try {
      final reqBody = <String, dynamic>{'idToken': idToken};
      if (extraFields != null) reqBody.addAll(extraFields);

      final res = await _client
          .post(
            _u('/api/auth/google'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(reqBody),
          )
          .timeout(_timeout);

      final decoded = _decodeJson(res.body);
      if (res.statusCode == 200 && decoded is Map && decoded['isNewUser'] == true) {
        return AuthResult.googleNewUser(
          email: decoded['email']?.toString() ?? '',
          fullName: decoded['fullName']?.toString() ?? '',
          picture: decoded['picture']?.toString(),
        );
      }
      return _parseAuth(res);
    } on TimeoutException {
      return AuthResult.error('Request timed out.');
    } catch (e) {
      return AuthResult.error('Cannot reach server. ($e)');
    }
  }

  AuthResult _parseAuth(http.Response res) {
    final decoded = _decodeJson(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final token = m['token'] as String?;
      final user = m['user'];
      if (token != null && user is Map) {
        return AuthResult.ok(
          token: token,
          user: Map<String, dynamic>.from(user),
        );
      }
    }
    final msg = _errorMessage(decoded, res.statusCode);
    return AuthResult.error(msg);
  }

  static dynamic _decodeJson(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  static String _errorMessage(dynamic decoded, int status) {
    if (decoded is Map && decoded['error'] is String) {
      return decoded['error'] as String;
    }
    if (decoded is Map && decoded['errors'] is List) {
      final list = decoded['errors'] as List;
      final parts = <String>[];
      for (final item in list) {
        if (item is Map) {
          final msg = item['msg'];
          if (msg is String) parts.add(msg);
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    if (status == 0 || (status >= 500 && decoded == null)) {
      return 'Server error or empty response ($status)';
    }
    return 'Request failed ($status)';
  }

  void close() {
    _client.close();
  }
}

class AuthResult {
  AuthResult._({
    this.token,
    this.user,
    this.errorMessage,
    this.isGoogleNewUser = false,
    this.googleEmail,
    this.googleFullName,
    this.googlePicture,
  });

  factory AuthResult.ok({
    required String token,
    required Map<String, dynamic> user,
  }) =>
      AuthResult._(token: token, user: user);

  factory AuthResult.error(String message) =>
      AuthResult._(errorMessage: message);

  factory AuthResult.googleNewUser({
    required String email,
    required String fullName,
    String? picture,
  }) =>
      AuthResult._(
        isGoogleNewUser: true,
        googleEmail: email,
        googleFullName: fullName,
        googlePicture: picture,
      );

  final String? token;
  final Map<String, dynamic>? user;
  final String? errorMessage;
  
  final bool isGoogleNewUser;
  final String? googleEmail;
  final String? googleFullName;
  final String? googlePicture;

  bool get isSuccess => token != null && user != null;
}
