import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/foundation.dart';

/// Live alerts feed (NDMA, IMD, USGS, OpenWeather, NASA EONET).
/// Used by the citizen-facing alerts ticker on the home screen.
class AlertsStore extends ChangeNotifier {
  AlertsStore._();
  static final AlertsStore instance = AlertsStore._();

  final Connectivity _connectivity = Connectivity();

  bool loading = false;
  String? error;
  DateTime? lastFetched;
  bool fromCache = false;
  List<Map<String, dynamic>> alerts = [];
  Map<String, int> countsBySource = {};
  List<String> sourcesAttempted = [];
  List<Map<String, String>> errors = [];

  StreamSubscription<dynamic>? _connSub;
  Timer? _refreshTimer;

  bool get hasAlerts => alerts.isNotEmpty;

  Future<void> initialize() async {
    _connSub = _connectivity.onConnectivityChanged.listen((result) {
      final online = (result as List<ConnectivityResult>).any((r) => r != ConnectivityResult.none);
      if (online) refresh();
    });
    await refresh();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) => refresh());
  }

  @override
  void dispose() {
    _connSub?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> refresh({double? latitude, double? longitude}) async {
    if (loading) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final payload = await LiveGisApi.liveAlerts(
        latitude: latitude,
        longitude: longitude,
      );
      alerts = (payload['items'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      countsBySource = Map<String, int>.from(
        (payload['counts_by_source'] as Map? ?? {}).map((k, v) => MapEntry(k.toString(), (v as num).toInt())),
      );
      sourcesAttempted = (payload['sources_attempted'] as List? ?? [])
          .map((e) => e.toString())
          .toList();
      errors = (payload['errors'] as List? ?? [])
          .map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v.toString()))))
          .toList();
      fromCache = payload['from_cache'] == true;
      lastFetched = DateTime.now();
    } catch (e) {
      error = e.toString();
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Pull alerts by source — useful for the ticker's filter chips.
  List<Map<String, dynamic>> bySource(String source) {
    return alerts.where((a) => a['source']?.toString().toUpperCase() == source.toUpperCase()).toList();
  }

  /// Top alerts (severity-aware ordering — CRITICAL > HIGH > MEDIUM > LOW)
  List<Map<String, dynamic>> get topAlerts {
    final severityRank = {'CRITICAL': 0, 'HIGH': 1, 'MEDIUM': 2, 'LOW': 3};
    final copy = List<Map<String, dynamic>>.from(alerts);
    copy.sort((a, b) {
      final sa = severityRank[a['severity']?.toString().toUpperCase()] ?? 4;
      final sb = severityRank[b['severity']?.toString().toUpperCase()] ?? 4;
      return sa.compareTo(sb);
    });
    return copy.take(10).toList();
  }
}
