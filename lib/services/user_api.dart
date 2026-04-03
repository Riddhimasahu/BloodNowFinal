import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class UserApi {
  UserApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<UserMeResult> getMe(String token) async {
    final res = await _client.get(_u('/api/users/me'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final u = decoded['user'];
      if (u is Map) {
        return UserMeResult.ok(Map<String, dynamic>.from(u));
      }
    }
    return UserMeResult.error(_err(decoded, res.statusCode));
  }

  Future<UserMeResult> patchMe(String token, Map<String, dynamic> body) async {
    final res = await _client.patch(
      _u('/api/users/me'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final u = decoded['user'];
      if (u is Map) {
        return UserMeResult.ok(Map<String, dynamic>.from(u));
      }
    }
    return UserMeResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleResult> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _client.post(
      _u('/api/users/me/password'),
      headers: _headers(token),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return SimpleResult.ok();
    }
    return SimpleResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleResult> bookAppointment(String token, int bankId, DateTime date) async {
    final res = await _client.post(
      _u('/api/banks/$bankId/appointments'),
      headers: _headers(token),
      body: jsonEncode({'date': date.toIso8601String()}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleResult.ok();
    return SimpleResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleResult> requestBlood(
    String token,
    int bankId, {
    required String bloodGroup,
    required int unitsNeeded,
    String? patientName,
    int? patientAge,
  }) async {
    final res = await _client.post(
      _u('/api/banks/$bankId/requests'),
      headers: _headers(token),
      body: jsonEncode({
        'bloodGroup': bloodGroup,
        'unitsNeeded': unitsNeeded,
        'patientName': patientName,
        'patientAge': patientAge,
      }),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleResult.ok();
    return SimpleResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleResult> updateFcmToken(String token, String fcmToken) async {
    final res = await _client.put(
      _u('/api/users/me/fcm-token'),
      headers: _headers(token),
      body: jsonEncode({'fcmToken': fcmToken}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleResult.ok();
    return SimpleResult.error(_err(decoded, res.statusCode));
  }

  Future<DonorProfileResult> getDonorProfile(String token) async {
    final res = await _client.get(_u('/api/users/me/donor-profile'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      return DonorProfileResult.ok(Map<String, dynamic>.from(decoded));
    }
    return DonorProfileResult.error(_err(decoded, res.statusCode));
  }

  Future<UserActivityResult> getUserActivity(String token) async {
    final res = await _client.get(_u('/api/users/me/activity'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      return UserActivityResult.ok(Map<String, dynamic>.from(decoded));
    }
    return UserActivityResult.error(_err(decoded, res.statusCode));
  }

  Future<DonorImpactResult> getDonorImpact(String token) async {
    final res = await _client.get(_u('/api/users/me/impact'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      return DonorImpactResult.ok(Map<String, dynamic>.from(decoded));
    }
    return DonorImpactResult.error(_err(decoded, res.statusCode));
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

  void close() {
    _client.close();
  }
}

class UserMeResult {
  UserMeResult._({this.user, this.errorMessage});

  factory UserMeResult.ok(Map<String, dynamic> user) =>
      UserMeResult._(user: user);

  factory UserMeResult.error(String message) =>
      UserMeResult._(errorMessage: message);

  final Map<String, dynamic>? user;
  final String? errorMessage;

  bool get isSuccess => user != null;
}

class SimpleResult {
  SimpleResult._({this.errorMessage});

  factory SimpleResult.ok() => SimpleResult._();

  factory SimpleResult.error(String message) =>
      SimpleResult._(errorMessage: message);

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class DonorProfileResult {
  DonorProfileResult._({this.data, this.errorMessage});

  factory DonorProfileResult.ok(Map<String, dynamic> data) =>
      DonorProfileResult._(data: data);

  factory DonorProfileResult.error(String message) =>
      DonorProfileResult._(errorMessage: message);

  final Map<String, dynamic>? data;
  final String? errorMessage;

  bool get isSuccess => data != null;
}

class DonorImpactResult {
  DonorImpactResult._({this.data, this.errorMessage});

  factory DonorImpactResult.ok(Map<String, dynamic> data) =>
      DonorImpactResult._(data: data);

  factory DonorImpactResult.error(String message) =>
      DonorImpactResult._(errorMessage: message);

  final Map<String, dynamic>? data;
  final String? errorMessage;

  bool get isSuccess => data != null;
}

class UserActivityResult {
  UserActivityResult._({this.data, this.errorMessage});

  factory UserActivityResult.ok(Map<String, dynamic> data) =>
      UserActivityResult._(data: data);

  factory UserActivityResult.error(String message) =>
      UserActivityResult._(errorMessage: message);

  final Map<String, dynamic>? data;
  final String? errorMessage;

  bool get isSuccess => data != null;
}
