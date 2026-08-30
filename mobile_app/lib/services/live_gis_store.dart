import 'package:field_app/core/database.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LiveGisStore extends ChangeNotifier {
  LiveGisStore._();
  static final LiveGisStore instance = LiveGisStore._();

  final DatabaseService _db = DatabaseService();

  bool loading = false;
  String? error;
  DateTime? generatedAt;
  bool cacheHit = false;
  Map<String, dynamic> alert = {};
  Map<String, dynamic> summary = {};
  Map<String, dynamic> dataSources = {};
  List<Habitation> habitations = [];
  List<HazardZone> zones = [];
  List<SafeShelter> shelters = [];
  double? lastSouth;
  double? lastWest;
  double? lastNorth;
  double? lastEast;

  Future<void> initializeAndRefresh() async {
    await _db.initialize();
    habitations = await _db.getAllHabitations();
    zones = await _db.getAllHazardZones();
    shelters = await _db.getAllSafeShelters();
    notifyListeners();
    await refreshFromLocationOrIndia();
  }

  Future<void> refreshFromLocationOrIndia() async {
    final gps = await _tryGps();
    if (gps != null) {
      await refreshAround(gps.latitude, gps.longitude, padDegrees: 0.55);
      return;
    }
    await refreshBbox(south: 6.5, west: 68.0, north: 37.1, east: 97.4);
  }

  Future<void> refreshAround(double lat, double lon, {double padDegrees = 0.45}) async {
    await refreshBbox(
      south: lat - padDegrees,
      west: lon - padDegrees,
      north: lat + padDegrees,
      east: lon + padDegrees,
    );
  }

  Future<void> refreshBbox({
    required double south,
    required double west,
    required double north,
    required double east,
  }) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final payload = await LiveGisApi.snapshot(
        south: south,
        west: west,
        north: north,
        east: east,
      );
      await _applyPayload(payload);
      lastSouth = south;
      lastWest = west;
      lastNorth = north;
      lastEast = east;
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> _applyPayload(Map<String, dynamic> payload) async {
    generatedAt = DateTime.tryParse('${payload['generated_at']}')?.toUtc();
    cacheHit = payload['cache_hit'] == true;
    alert = Map<String, dynamic>.from(payload['alert'] as Map? ?? {});
    summary = Map<String, dynamic>.from(payload['summary'] as Map? ?? {});
    dataSources = Map<String, dynamic>.from(payload['data_sources'] as Map? ?? {});

    final zoneRows = (payload['red_zones'] as List? ?? [])
        .whereType<Map>()
        .map((row) => HazardZone.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final habRows = (payload['habitations'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Habitation.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    final shelterRows = (payload['shelters'] as List? ?? [])
        .whereType<Map>()
        .map((row) => SafeShelter.fromJson(Map<String, dynamic>.from(row)))
        .toList();

    await _db.replaceLiveSnapshot(
      zones: zoneRows,
      habitations: habRows,
      shelters: shelterRows,
    );
    zones = zoneRows;
    habitations = habRows;
    shelters = shelterRows;
  }

  Future<Position?> _tryGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      return Geolocator.getCurrentPosition(timeLimit: const Duration(seconds: 6));
    } catch (_) {
      return null;
    }
  }
}
