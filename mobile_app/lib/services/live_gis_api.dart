import 'dart:convert';

import 'package:field_app/core/config.dart';
import 'package:field_app/services/local_demo_data.dart';
import 'package:http/http.dart' as http;

class LiveGisApi {
  static Uri _uri(String path, [Map<String, String>? query]) {
    return Uri.parse('${AppConfig.baseUrl}$path').replace(queryParameters: query);
  }

  static Map<String, String> _headers({String? token, bool json = false}) {
    return {
      if (json) 'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _bundledScenario() {
    return const {
      'scenario_id': 'bundled_odisha_cyclone',
      'name': 'Bundled Cyclone Scenario - Odisha Coast',
      'description': 'Bundled offline scenario used when the backend is unreachable on the device.',
      'geography': 'Odisha coastal districts',
      'hazard_mix': ['COASTAL_EROSION', 'FLOOD', 'CYCLONE'],
      'is_active': true,
    };
  }

  static Map<String, dynamic> _bundledDemoScenarioList() {
    return {
      'mode': 'DEMO_SCENARIO',
      'scenarios': [_bundledScenario()],
      'data_sources': {
        'mode': 'Bundled mobile demo fallback',
        'backend_status': 'Unavailable from device; only bundled scenarios can be used offline',
      },
    };
  }

  static Map<String, dynamic> _bundledCurrentDemoScenario() {
    return {
      'mode': 'DEMO_SCENARIO',
      'scenario': _bundledScenario(),
      'data_sources': {
        'mode': 'Bundled mobile demo fallback',
        'backend_status': 'Unavailable from device; using on-device scenario fallback',
      },
    };
  }

  static Future<Map<String, dynamic>> snapshot({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    final uri = _uri('/api/v1/gis/snapshot', {
      'south': south.toStringAsFixed(4),
      'west': west.toStringAsFixed(4),
      'north': north.toStringAsFixed(4),
      'east': east.toStringAsFixed(4),
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 90));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return LocalDemoData.snapshot(
      south: south,
      west: west,
      north: north,
      east: east,
    );
  }

  static Future<Map<String, dynamic>> inspect({
    required double latitude,
    required double longitude,
  }) async {
    final uri = _uri('/api/v1/gis/inspect', {
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
    });
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return LocalDemoData.inspect(
      latitude: latitude,
      longitude: longitude,
    );
  }

  static Future<Map<String, dynamic>> evaluateCandidateSite({
    required String siteName,
    required String districtName,
    required String stateCode,
    required double latitude,
    required double longitude,
    required double hectares,
    required double roadDistanceKm,
    bool waterSupply = true,
    bool sanitationFacilities = true,
    bool electricity = true,
    String medicalFacilityDepth = 'BASIC',
  }) async {
    try {
      final response = await http
          .post(
            _uri('/api/v1/shelters/evaluate-site'),
            headers: _headers(json: true),
            body: jsonEncode({
              'site_name': siteName,
              'district_name': districtName,
              'state_code': stateCode,
              'latitude': latitude,
              'longitude': longitude,
              'hectares': hectares,
              'road_distance_km': roadDistanceKm,
              'water_supply': waterSupply,
              'sanitation_facilities': sanitationFacilities,
              'electricity': electricity,
              'medical_facility_depth': medicalFacilityDepth,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return LocalDemoData.evaluateCandidateSite(
      siteName: siteName,
      districtName: districtName,
      stateCode: stateCode,
      latitude: latitude,
      longitude: longitude,
      hectares: hectares,
      roadDistanceKm: roadDistanceKm,
      waterSupply: waterSupply,
      sanitationFacilities: sanitationFacilities,
      electricity: electricity,
      medicalFacilityDepth: medicalFacilityDepth,
    );
  }

  static Future<Map<String, dynamic>> registerCandidateSite({
    required String siteName,
    required String districtName,
    required String stateCode,
    required double latitude,
    required double longitude,
    required double hectares,
    required double roadDistanceKm,
    bool waterSupply = true,
    bool sanitationFacilities = true,
    bool electricity = true,
    String medicalFacilityDepth = 'BASIC',
  }) async {
    try {
      final response = await http
          .post(
            _uri('/api/v1/shelters/register-candidate'),
            headers: _headers(json: true),
            body: jsonEncode({
              'site_name': siteName,
              'district_name': districtName,
              'state_code': stateCode,
              'latitude': latitude,
              'longitude': longitude,
              'hectares': hectares,
              'road_distance_km': roadDistanceKm,
              'water_supply': waterSupply,
              'sanitation_facilities': sanitationFacilities,
              'electricity': electricity,
              'medical_facility_depth': medicalFacilityDepth,
            }),
          )
          .timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final evaluation = LocalDemoData.evaluateCandidateSite(
      siteName: siteName,
      districtName: districtName,
      stateCode: stateCode,
      latitude: latitude,
      longitude: longitude,
      hectares: hectares,
      roadDistanceKm: roadDistanceKm,
      waterSupply: waterSupply,
      sanitationFacilities: sanitationFacilities,
      electricity: electricity,
      medicalFacilityDepth: medicalFacilityDepth,
    );

    return {
      'success': true,
      'message': 'Registered in bundled demo mode. Backend was unreachable, so this candidate is available only in the local scenario preview.',
      'candidate_site': {
        'candidate_site_id': evaluation['candidate_site_id'],
        'site_name': siteName,
        'district_name': districtName,
        'state_code': stateCode,
        'latitude': latitude,
        'longitude': longitude,
        'hectares': hectares,
        'road_distance_km': roadDistanceKm,
        'geometry_wkt': 'POINT($longitude $latitude)',
        'registration_mode': 'BUNDLED_DEMO_FALLBACK',
      },
      'evaluation': evaluation,
      'mode': 'DEMO_SCENARIO',
      'scenario': _bundledScenario(),
      'data_sources': {
        'mode': 'Bundled mobile demo fallback',
        'backend_status': 'Unavailable from device; simulated registration for demo continuity',
      },
      'registered_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  static Future<Map<String, dynamic>> login({
    required String username,
    required String password,
  }) async {
    final response = await http
        .post(
          _uri('/api/v1/auth/login'),
          headers: _headers(json: true),
          body: jsonEncode({
            'username': username,
            'password': password,
          }),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Login failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> currentUser(String token) async {
    final response = await http.get(
      _uri('/api/v1/auth/me'),
      headers: _headers(token: token),
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('Profile lookup failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> operationsDashboard({
    required String token,
    String? stateCode,
    String? districtQuery,
    double? south,
    double? west,
    double? north,
    double? east,
  }) async {
    final query = <String, String>{
      if (stateCode != null && stateCode.trim().isNotEmpty) 'state_code': stateCode.trim(),
      if (districtQuery != null && districtQuery.trim().isNotEmpty) 'district_query': districtQuery.trim(),
      if (south != null) 'south': south.toStringAsFixed(4),
      if (west != null) 'west': west.toStringAsFixed(4),
      if (north != null) 'north': north.toStringAsFixed(4),
      if (east != null) 'east': east.toStringAsFixed(4),
    };
    final response = await http.get(
      _uri('/api/v1/operations/dashboard', query),
      headers: _headers(token: token),
    ).timeout(const Duration(seconds: 120));
    if (response.statusCode != 200) {
      throw Exception('Operations dashboard failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> demoScenarios() async {
    try {
      final response = await http.get(
        _uri('/api/v1/demo/scenarios'),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return _bundledDemoScenarioList();
  }

  static Future<Map<String, dynamic>> currentDemoScenario() async {
    try {
      final response = await http.get(
        _uri('/api/v1/demo/current'),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return _bundledCurrentDemoScenario();
  }

  static Future<Map<String, dynamic>> activateDemoScenario(String scenarioId) async {
    try {
      final response = await http.post(
        _uri('/api/v1/demo/activate/$scenarioId'),
        headers: _headers(json: true),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'success': true,
      'message': scenarioId == 'bundled_odisha_cyclone'
          ? 'Bundled offline scenario remains active on this device.'
          : 'Backend unreachable. The app remains on the bundled offline scenario for the device demo.',
      'mode': 'DEMO_SCENARIO',
      'scenario': _bundledScenario(),
    };
  }
}
