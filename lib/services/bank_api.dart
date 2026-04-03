import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BankApi {
  BankApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const Duration _timeout = Duration(seconds: 25);

  Uri _u(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  Future<BankAuthResult> register(Map<String, dynamic> body) async {
    try {
      final res = await _client
          .post(
            _u('/api/banks/register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return _parseAuth(res);
    } on TimeoutException {
      return BankAuthResult.error(
        'Request timed out. Check API at ${ApiConfig.baseUrl}',
      );
    } catch (e) {
      return BankAuthResult.error(
        'Cannot reach server at ${ApiConfig.baseUrl}. ($e)',
      );
    }
  }

  Future<BankAuthResult> login(String email, String password) async {
    try {
      final res = await _client
          .post(
            _u('/api/banks/login'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'email': email, 'password': password}),
          )
          .timeout(_timeout);
      return _parseAuth(res);
    } on TimeoutException {
      return BankAuthResult.error(
        'Request timed out. Check API at ${ApiConfig.baseUrl}',
      );
    } catch (e) {
      return BankAuthResult.error(
        'Cannot reach server at ${ApiConfig.baseUrl}. ($e)',
      );
    }
  }

  BankAuthResult _parseAuth(http.Response res) {
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final token = m['token'] as String?;
      final bank = m['bank'];
      if (token != null && bank is Map) {
        return BankAuthResult.ok(
          token: token,
          bank: Map<String, dynamic>.from(bank),
        );
      }
    }
    return BankAuthResult.error(_err(decoded, res.statusCode));
  }

  Future<BankMeResult> getMe(String token) async {
    final res = await _client.get(_u('/api/banks/me'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final b = decoded['bank'];
      if (b is Map) return BankMeResult.ok(Map<String, dynamic>.from(b));
    }
    return BankMeResult.error(_err(decoded, res.statusCode));
  }

  Future<BankMeResult> patchMe(String token, Map<String, dynamic> body) async {
    final res = await _client.patch(
      _u('/api/banks/me'),
      headers: _headers(token),
      body: jsonEncode(body),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final b = decoded['bank'];
      if (b is Map) return BankMeResult.ok(Map<String, dynamic>.from(b));
    }
    return BankMeResult.error(_err(decoded, res.statusCode));
  }

  Future<InventoryResult> getInventory(String token) async {
    final res = await _client.get(
      _u('/api/banks/me/inventory'),
      headers: _headers(token),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final raw = decoded['items'];
      final list = <InventoryItem>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(InventoryItem.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return InventoryResult.ok(list);
    }
    return InventoryResult.error(_err(decoded, res.statusCode));
  }

  Future<InventoryResult> putInventory(
    String token,
    Map<String, int> units,
  ) async {
    final res = await _client.put(
      _u('/api/banks/me/inventory'),
      headers: _headers(token),
      body: jsonEncode({'units': units}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final raw = decoded['items'];
      final list = <InventoryItem>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(InventoryItem.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return InventoryResult.ok(list);
    }
    return InventoryResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleBankResult> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    final res = await _client.post(
      _u('/api/banks/me/password'),
      headers: _headers(token),
      body: jsonEncode({
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      }),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return SimpleBankResult.ok();
    }
    return SimpleBankResult.error(_err(decoded, res.statusCode));
  }

  Future<BankListsResult> getAppointments(String token) async {
    final res = await _client.get(_u('/api/banks/me/appointments'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final raw = decoded['appointments'];
      if (raw is List) {
        return BankListsResult.okAppointments(raw.map((x) => BankAppointment.fromJson(x)).toList());
      }
    }
    return BankListsResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleBankResult> updateAppointmentStatus(String token, int id, String status) async {
    final res = await _client.patch(
      _u('/api/banks/me/appointments/$id'),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleBankResult.ok();
    return SimpleBankResult.error(_err(decoded, res.statusCode));
  }

  Future<BankListsResult> getRequests(String token) async {
    final res = await _client.get(_u('/api/banks/me/requests'), headers: _headers(token));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final raw = decoded['requests'];
      if (raw is List) {
        return BankListsResult.okRequests(raw.map((x) => BankBloodRequest.fromJson(x)).toList());
      }
    }
    return BankListsResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleBankResult> updateRequestStatus(String token, int id, String status) async {
    final res = await _client.patch(
      _u('/api/banks/me/requests/$id'),
      headers: _headers(token),
      body: jsonEncode({'status': status}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleBankResult.ok();
    return SimpleBankResult.error(_err(decoded, res.statusCode));
  }

  Future<SimpleBankResult> markDonationAsUsed(String token, int donationId) async {
    final res = await _client.post(
      _u('/api/banks/mark-used'),
      headers: _headers(token),
      body: jsonEncode({'donationId': donationId}),
    );
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300) return SimpleBankResult.ok();
    return SimpleBankResult.error(_err(decoded, res.statusCode));
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
      final parts = <String>[];
      for (final item in list) {
        if (item is Map) {
          final msg = item['msg'];
          if (msg is String) parts.add(msg);
        }
      }
      if (parts.isNotEmpty) return parts.join('\n');
    }
    return 'Request failed ($status)';
  }

  void close() {
    _client.close();
  }
}

class BankAuthResult {
  BankAuthResult._({this.token, this.bank, this.errorMessage});

  factory BankAuthResult.ok({
    required String token,
    required Map<String, dynamic> bank,
  }) =>
      BankAuthResult._(token: token, bank: bank);

  factory BankAuthResult.error(String message) =>
      BankAuthResult._(errorMessage: message);

  final String? token;
  final Map<String, dynamic>? bank;
  final String? errorMessage;

  bool get isSuccess => token != null && bank != null;
}

class BankMeResult {
  BankMeResult._({this.bank, this.errorMessage});

  factory BankMeResult.ok(Map<String, dynamic> bank) =>
      BankMeResult._(bank: bank);

  factory BankMeResult.error(String message) =>
      BankMeResult._(errorMessage: message);

  final Map<String, dynamic>? bank;
  final String? errorMessage;

  bool get isSuccess => bank != null;
}

class InventoryItem {
  InventoryItem({
    required this.bloodGroup,
    required this.unitsAvailable,
  });

  factory InventoryItem.fromJson(Map<String, dynamic> j) {
    return InventoryItem(
      bloodGroup: '${j['bloodGroup']}',
      unitsAvailable: (j['unitsAvailable'] as num).toInt(),
    );
  }

  final String bloodGroup;
  final int unitsAvailable;
}

class InventoryResult {
  InventoryResult._({this.items, this.errorMessage});

  factory InventoryResult.ok(List<InventoryItem> items) =>
      InventoryResult._(items: items);

  factory InventoryResult.error(String message) =>
      InventoryResult._(errorMessage: message);

  final List<InventoryItem>? items;
  final String? errorMessage;

  bool get isSuccess => items != null;
}

class SimpleBankResult {
  SimpleBankResult._({this.errorMessage});

  factory SimpleBankResult.ok() => SimpleBankResult._();

  factory SimpleBankResult.error(String message) =>
      SimpleBankResult._(errorMessage: message);

  final String? errorMessage;

  bool get isSuccess => errorMessage == null;
}

class BankAppointment {
  final int id;
  final String date;
  final String status;
  final String donorName;
  final String bloodGroup;
  final bool isUsed;
  BankAppointment.fromJson(Map<String, dynamic> j)
      : id = int.parse('${j['id']}'),
        date = '${j['appointment_date']}',
        status = '${j['status']}',
        donorName = '${j['full_name']}',
        bloodGroup = '${j['blood_group']}',
        isUsed = j['is_used'] == true;
}

class BankBloodRequest {
  final int id;
  final String date;
  final String status;
  final String patientName;
  final String bloodGroup;
  final int unitsNeeded;
  BankBloodRequest.fromJson(Map<String, dynamic> j)
      : id = int.parse('${j['id']}'),
        date = '${j['created_at']}',
        status = '${j['status']}',
        patientName =
            j['patient_name'] != null ? '${j['patient_name']}' : 'Unknown',
        bloodGroup = '${j['blood_group']}',
        unitsNeeded = int.parse('${j['units_needed']}');
}

class BankListsResult {
  BankListsResult._({this.appointments, this.requests, this.errorMessage});
  factory BankListsResult.okAppointments(List<BankAppointment> list) =>
      BankListsResult._(appointments: list);
  factory BankListsResult.okRequests(List<BankBloodRequest> list) =>
      BankListsResult._(requests: list);
  factory BankListsResult.error(String msg) =>
      BankListsResult._(errorMessage: msg);

  final List<BankAppointment>? appointments;
  final List<BankBloodRequest>? requests;
  final String? errorMessage;
  bool get isSuccess => errorMessage == null;
}
