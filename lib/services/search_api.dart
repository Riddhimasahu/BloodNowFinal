import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class SearchApi {
  SearchApi({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _u(String path, Map<String, String> query) {
    final base = Uri.parse('${ApiConfig.baseUrl}$path');
    return base.replace(queryParameters: query);
  }

  /// Requires a **user** JWT (requester). Donors are ordered by Haversine distance.
  Future<NearestDonorsResponse> nearestDonors({
    required String bearerToken,
    required double latitude,
    required double longitude,
    required String bloodGroup,
    int limit = 15,
  }) async {
    final q = {
      'lat': latitude.toString(),
      'lng': longitude.toString(),
      'bloodGroup': bloodGroup,
      'limit': '$limit',
    };
    final base = Uri.parse('${ApiConfig.baseUrl}/api/search/nearest-donors');
    final uri = base.replace(queryParameters: q);
    final res = await _client.get(
      uri,
      headers: {'Authorization': 'Bearer $bearerToken'},
    );
    final decoded = _decode(res.body);
    if (res.statusCode == 401) {
      return NearestDonorsResponse.error('Session expired. Log in again.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final raw = m['results'];
      final list = <NearestDonor>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(NearestDonor.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return NearestDonorsResponse.ok(list);
    }
    final msg = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Search failed (${res.statusCode})';
    return NearestDonorsResponse.error(msg);
  }

  /// [bloodGroup] when set: only banks with inventory for that group (requester-style).
  Future<NearestBanksResponse> nearestBanks({
    double? latitude,
    double? longitude,
    String? address,
    String? bloodGroup,
    int? minUnits,
    int limit = 10,
  }) async {
    final q = {
      if (latitude != null) 'lat': latitude.toString(),
      if (longitude != null) 'lng': longitude.toString(),
      if (address != null && address.isNotEmpty) 'address': address,
      'limit': '$limit',
      if (bloodGroup != null && bloodGroup.isNotEmpty) 'bloodGroup': bloodGroup,
      if (minUnits != null) 'minUnits': minUnits.toString(),
    };
    final res = await _client.get(_u('/api/search/nearest-banks', q));
    final decoded = _decode(res.body);
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded is Map) {
      final m = Map<String, dynamic>.from(decoded);
      final raw = m['results'];
      final list = <NearestBank>[];
      if (raw is List) {
        for (final item in raw) {
          if (item is Map) {
            list.add(NearestBank.fromJson(Map<String, dynamic>.from(item)));
          }
        }
      }
      return NearestBanksResponse.ok(list);
    }
    final msg = decoded is Map && decoded['error'] is String
        ? decoded['error'] as String
        : 'Search failed (${res.statusCode})';
    return NearestBanksResponse.error(msg);
  }

  static dynamic _decode(String body) {
    try {
      return jsonDecode(body);
    } catch (_) {
      return null;
    }
  }

  void close() {
    _client.close();
  }
}

class NearestBanksResponse {
  NearestBanksResponse._({this.results, this.errorMessage});

  factory NearestBanksResponse.ok(List<NearestBank> results) =>
      NearestBanksResponse._(results: results);

  factory NearestBanksResponse.error(String message) =>
      NearestBanksResponse._(errorMessage: message);

  final List<NearestBank>? results;
  final String? errorMessage;

  bool get isSuccess => results != null;
}

class NearestDonorsResponse {
  NearestDonorsResponse._({this.results, this.errorMessage});

  factory NearestDonorsResponse.ok(List<NearestDonor> results) =>
      NearestDonorsResponse._(results: results);

  factory NearestDonorsResponse.error(String message) =>
      NearestDonorsResponse._(errorMessage: message);

  final List<NearestDonor>? results;
  final String? errorMessage;

  bool get isSuccess => results != null;
}

class NearestDonor {
  NearestDonor({
    required this.id,
    required this.fullName,
    required this.bloodGroup,
    required this.approximateLatitude,
    required this.approximateLongitude,
    required this.distanceMeters,
    required this.phoneMasked,
  });

  factory NearestDonor.fromJson(Map<String, dynamic> j) {
    return NearestDonor(
      id: j['id'] is int ? j['id'] as int : int.parse('${j['id']}'),
      fullName: '${j['fullName'] ?? ''}',
      bloodGroup: '${j['bloodGroup'] ?? ''}',
      approximateLatitude: (j['approximateLatitude'] as num).toDouble(),
      approximateLongitude: (j['approximateLongitude'] as num).toDouble(),
      distanceMeters: (j['distanceMeters'] as num).toInt(),
      phoneMasked: '${j['phoneMasked'] ?? ''}',
    );
  }

  final int id;
  final String fullName;
  final String bloodGroup;
  final double approximateLatitude;
  final double approximateLongitude;
  final int distanceMeters;
  final String phoneMasked;
}

class NearestBank {
  NearestBank({
    required this.id,
    required this.name,
    required this.addressLine,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
    this.availableUnits = 0,
  });

  factory NearestBank.fromJson(Map<String, dynamic> j) {
    return NearestBank(
      id: j['id'] is int ? j['id'] as int : int.parse('${j['id']}'),
      name: '${j['name'] ?? ''}',
      addressLine: j['addressLine'] as String?,
      latitude: (j['latitude'] as num).toDouble(),
      longitude: (j['longitude'] as num).toDouble(),
      distanceMeters: (j['distanceMeters'] as num).toInt(),
      availableUnits: (j['availableUnits'] as num?)?.toInt() ?? 0,
    );
  }

  final int id;
  final String name;
  final String? addressLine;
  final double latitude;
  final double longitude;
  final int distanceMeters;
  final int availableUnits;
}
