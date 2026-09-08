import 'dart:convert';
import 'dart:math' as math;

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

  // ---------------------------------------------------------------------------
  // Citizen self-registration via OTP
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> citizenRequestOtp({required String phoneNumber}) async {
    final response = await http
        .post(
          _uri('/api/v1/auth/citizen/request-otp'),
          headers: _headers(json: true),
          body: jsonEncode({'phone_number': phoneNumber}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('OTP request failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> citizenVerifyOtp({required String phoneNumber, required String otp}) async {
    final response = await http
        .post(
          _uri('/api/v1/auth/citizen/verify-otp'),
          headers: _headers(json: true),
          body: jsonEncode({'phone_number': phoneNumber, 'otp': otp}),
        )
        .timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) {
      throw Exception('OTP verification failed (${response.statusCode}): ${response.body}');
    }
    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  // ---------------------------------------------------------------------------
  // Operations dashboard
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // Demo scenarios
  // ---------------------------------------------------------------------------
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

  // ---------------------------------------------------------------------------
  // SOS endpoints — layered offline mesh (server / mesh relay / SMS gateway)
  // ---------------------------------------------------------------------------
  static String _genUuid() {
    final r = math.Random();
    final hex = List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  /// Submit an SOS to the central server (Layer 1 — direct server).
  /// Returns the parsed response or null if the server was unreachable.
  /// On failure the caller should retry as a mesh relay (Layer 2) or
  /// SMS gateway payload (Layer 3).
  static Future<Map<String, dynamic>?> sosSubmit({
    required String deviceId,
    double? latitude,
    double? longitude,
    String category = 'MEDICAL',
    String severity = 'HIGH',
    String message = '',
    int? peopleCount,
    String? contactPhone,
    String originLayer = 'SERVER_DIRECT',
    List<String> relayedThrough = const [],
    int hopCount = 0,
    String? token,
  }) async {
    final sosId = _genUuid();
    final body = {
      'sos_id': sosId,
      'device_id': deviceId,
      'latitude': latitude,
      'longitude': longitude,
      'category': category,
      'severity': severity,
      'message': message,
      if (peopleCount != null) 'people_count': peopleCount,
      if (contactPhone != null) 'contact_phone': contactPhone,
      'origin_layer': originLayer,
      'relayed_through': relayedThrough,
      'hop_count': hopCount,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      final response = await http
          .post(
            _uri('/api/v1/sos/submit'),
            headers: _headers(token: token, json: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Relay an SOS that was received from another phone in the mesh (Layer 2).
  static Future<Map<String, dynamic>?> sosRelay({
    required String deviceId,
    required Map<String, dynamic> sosPayload,
    String? token,
  }) async {
    try {
      final response = await http
          .post(
            _uri('/api/v1/sos/relay'),
            headers: _headers(token: token, json: true),
            body: jsonEncode(sosPayload),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  /// Fetch SOSes near a given point (citizen view).
  static Future<List<Map<String, dynamic>>> sosList({
    double? latitude,
    double? longitude,
    double radiusKm = 25.0,
    String? category,
    String? severity,
    int limit = 50,
    String? token,
  }) async {
    final query = <String, String>{
      if (latitude != null) 'latitude': latitude.toStringAsFixed(5),
      if (longitude != null) 'longitude': longitude.toStringAsFixed(5),
      'radius_km': radiusKm.toStringAsFixed(1),
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
      'limit': limit.toString(),
    };
    try {
      final response = await http.get(
        _uri('/api/v1/sos/', query),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  static Future<Map<String, dynamic>?> sosAcknowledge({
    required String sosId,
    required String token,
    String? note,
  }) async {
    try {
      final response = await http
          .post(
            _uri('/api/v1/sos/$sosId/acknowledge'),
            headers: _headers(token: token, json: true),
            body: jsonEncode({'note': note}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  // ---------------------------------------------------------------------------
  // Live official alerts (NDMA, IMD, USGS, OpenWeather, NASA EONET)
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>> liveAlerts({
    double? latitude,
    double? longitude,
    List<String>? sourceFilter,
  }) async {
    final query = <String, String>{
      if (latitude != null) 'latitude': latitude.toStringAsFixed(5),
      if (longitude != null) 'longitude': longitude.toStringAsFixed(5),
      if (sourceFilter != null && sourceFilter.isNotEmpty) 'source_filter': sourceFilter.join(','),
    };
    try {
      final response = await http.get(_uri('/api/v1/alerts/live', query)).timeout(const Duration(seconds: 60));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    // Bundled fallback — show 3 curated alerts when offline
    return {
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'from_cache': false,
      'sources_attempted': ['BUNDLED_FALLBACK'],
      'counts_by_source': {'BUNDLED_FALLBACK': 3},
      'items': [
        {
          'source': 'BUNDLED_FALLBACK',
          'type': 'INFO',
          'title': 'Backend unreachable — bundled offline alerts',
          'summary': 'The DisasterNet backend could not be reached. Showing bundled alerts only. Pull to retry.',
          'timestamp': DateTime.now().toUtc().toIso8601String(),
        }
      ],
      'errors': [],
    };
  }

  // ---------------------------------------------------------------------------
  // Crowd-sourced reports
  // ---------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> submitCrowdReport({
    required String category,
    required String severity,
    required double latitude,
    required double longitude,
    String description = '',
    int? peopleAffected,
    int? casualties,
    String? photoUrl,
    String? contactPhone,
    String? token,
  }) async {
    try {
      final response = await http
          .post(
            _uri('/api/v1/crowd-reports/submit'),
            headers: _headers(token: token, json: true),
            body: jsonEncode({
              'category': category,
              'severity': severity,
              'latitude': latitude,
              'longitude': longitude,
              'description': description,
              if (peopleAffected != null) 'people_affected': peopleAffected,
              if (casualties != null) 'casualties': casualties,
              if (photoUrl != null) 'photo_url': photoUrl,
              if (contactPhone != null) 'contact_phone': contactPhone,
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> crowdReports({
    double? latitude,
    double? longitude,
    double radiusKm = 25.0,
    String? category,
    String? severity,
    String? token,
  }) async {
    final query = <String, String>{
      if (latitude != null) 'latitude': latitude.toStringAsFixed(5),
      if (longitude != null) 'longitude': longitude.toStringAsFixed(5),
      'radius_km': radiusKm.toStringAsFixed(1),
      if (category != null) 'category': category,
      if (severity != null) 'severity': severity,
    };
    try {
      final response = await http.get(
        _uri('/api/v1/crowd-reports/', query),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['items'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  // ---------------------------------------------------------------------------
  // GIS extensions — layered map, spatial analysis, routing, reverse geocoding
  // ---------------------------------------------------------------------------
  static Future<List<Map<String, dynamic>>> gisLayers({String? token}) async {
    try {
      final response = await http.get(
        _uri('/api/v1/gis/layers'),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return (data['layers'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
      }
    } catch (_) {}
    return _bundledLayers();
  }

  static List<Map<String, dynamic>> _bundledLayers() {
    return [
      {'layer_id': 'red_zones', 'name': 'Red Zones (AI hazard polygons)', 'geometry_type': 'Polygon', 'default_visible': true, 'is_official': true, 'source': 'DisasterNet'},
      {'layer_id': 'shelters', 'name': 'Safe Shelters', 'geometry_type': 'Point', 'default_visible': true, 'is_official': true, 'source': 'OSM + field'},
      {'layer_id': 'habitations', 'name': 'Vulnerable Habitations', 'geometry_type': 'Point', 'default_visible': true, 'is_official': true, 'source': 'OSM + census'},
      {'layer_id': 'sos', 'name': 'Active SOS', 'geometry_type': 'Point', 'default_visible': true, 'is_official': false, 'source': 'DisasterNet SOS'},
      {'layer_id': 'crowd_reports', 'name': 'Crowd-sourced Reports', 'geometry_type': 'Point', 'default_visible': true, 'is_official': false, 'source': 'DisasterNet citizens'},
      {'layer_id': 'usgs_earthquakes', 'name': 'USGS Earthquakes (24h)', 'geometry_type': 'Point', 'default_visible': false, 'is_official': true, 'source': 'USGS'},
      {'layer_id': 'nasa_eonet', 'name': 'NASA EONET (wildfires & volcanoes)', 'geometry_type': 'Point', 'default_visible': false, 'is_official': true, 'source': 'NASA EONET'},
    ];
  }

  static Future<Map<String, dynamic>> gisRoute({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    bool avoidRedZones = true,
    String? token,
  }) async {
    final query = <String, String>{
      'origin_lat': originLat.toStringAsFixed(5),
      'origin_lon': originLon.toStringAsFixed(5),
      'destination_lat': destLat.toStringAsFixed(5),
      'destination_lon': destLon.toStringAsFixed(5),
      'avoid_red_zones': avoidRedZones.toString(),
    };
    try {
      final response = await http.get(
        _uri('/api/v1/gis/route', query),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 45));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    // Bundled fallback: straight-line distance
    return {
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'distance_km': _haversineKm(originLat, originLon, destLat, destLon).toStringAsFixed(2),
      'duration_estimate_min': (_haversineKm(originLat, originLon, destLat, destLon) / 4.0 * 60).round(),
      'avoided_red_zones': 0,
      'waypoints': [
        [originLat, originLon],
        [destLat, destLon],
      ],
      'notes': 'Bundled fallback — straight great-circle distance.',
    };
  }

  static double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final p1 = lat1 * math.pi / 180;
    final p2 = lat2 * math.pi / 180;
    final dphi = (lat2 - lat1) * math.pi / 180;
    final dlam = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dphi / 2) * math.sin(dphi / 2) +
        math.cos(p1) * math.cos(p2) * math.sin(dlam / 2) * math.sin(dlam / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  static Future<Map<String, dynamic>> reverseGeocode({
    required double latitude,
    required double longitude,
    String? token,
  }) async {
    final query = <String, String>{
      'latitude': latitude.toStringAsFixed(5),
      'longitude': longitude.toStringAsFixed(5),
    };
    try {
      final response = await http.get(
        _uri('/api/v1/gis/reverse-geocode', query),
        headers: _headers(token: token),
      ).timeout(const Duration(seconds: 30));
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (_) {}
    return {
      'server_time': DateTime.now().toUtc().toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'source': 'backend-unreachable',
    };
  }
}
