import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum SessionKind { none, user, bank }

class SessionStore {
  static const _kindKey = 'session_kind';
  static const _tokenKey = 'auth_token';
  static const _userKey = 'auth_user_json';
  static const _bankKey = 'auth_bank_json';

  Future<void> saveUserSession(String token, Map<String, dynamic> user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kindKey, 'user');
    await p.setString(_tokenKey, token);
    await p.setString(_userKey, jsonEncode(user));
    await p.remove(_bankKey);
  }

  Future<void> saveBankSession(String token, Map<String, dynamic> bank) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kindKey, 'bank');
    await p.setString(_tokenKey, token);
    await p.setString(_bankKey, jsonEncode(bank));
    await p.remove(_userKey);
  }

  Future<SessionKind> sessionKind() async {
    final p = await SharedPreferences.getInstance();
    final k = p.getString(_kindKey);
    if (k == 'user') return SessionKind.user;
    if (k == 'bank') return SessionKind.bank;
    return SessionKind.none;
  }

  Future<String?> getToken() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_tokenKey);
  }

  Future<Map<String, dynamic>?> getUser() async {
    final p = await SharedPreferences.getInstance();
    return _decodeMap(p.getString(_userKey));
  }

  Future<Map<String, dynamic>?> getBank() async {
    final p = await SharedPreferences.getInstance();
    return _decodeMap(p.getString(_bankKey));
  }

  Map<String, dynamic>? _decodeMap(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final m = jsonDecode(raw);
      if (m is Map<String, dynamic>) return m;
      if (m is Map) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return null;
  }

  Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kindKey);
    await p.remove(_tokenKey);
    await p.remove(_userKey);
    await p.remove(_bankKey);
  }
}
