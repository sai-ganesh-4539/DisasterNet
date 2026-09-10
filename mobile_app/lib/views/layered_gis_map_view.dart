import 'dart:async';

import 'package:field_app/core/wkt.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/alerts_store.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class LayeredGisMapView extends StatefulWidget {
  const LayeredGisMapView({super.key});

  @override
  State<LayeredGisMapView> createState() => _LayeredGisMapViewState();
}

class _LayeredGisMapViewState extends State<LayeredGisMapView> {
  final MapController _mapController = MapController();
  final LiveGisStore _store = LiveGisStore.instance;
  final AlertsStore _alerts = AlertsStore.instance;

  static const LatLng _indiaCenter = LatLng(21.7679, 78.8718);
  static const double _initialZoom = 4.6;

  final Map<String, bool> _layerVisible = {
    'red_zones': true,
    'shelters': true,
    'habitations': true,
    'sos': true,
    'crowd_reports': true,
    'usgs_earthquakes': true,
    'nasa_eonet': true,
    'gdacs': true,
    'emsc': true,
  };

  bool _showLayersPanel = false;
  bool _showSpatialSheet = false;
  bool _showRouteSheet = false;
  bool _loadingExtra = false;
  bool _hideDemoData = false;

  List<Map<String, dynamic>> _sosItems = [];
  List<Map<String, dynamic>> _crowdItems = [];

  LatLng? _routeOrigin;
  LatLng? _routeDestination;
  Map<String, dynamic>? _routeResult;

  final List<LatLng> _drawnPolygon = [];
  Map<String, dynamic>? _spatialResult;

  LatLng? _tappedLocation;
  Map<String, dynamic>? _inspection;
  bool _showInspectorSheet = false;
  bool _isInspecting = false;

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _alerts.addListener(_onStoreChanged);
    _initialize();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _refreshExtraLayers());
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _alerts.removeListener(_onStoreChanged);
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _store.initializeAndRefresh();
    await _alerts.initialize();
    await _refreshExtraLayers();
  }

  Future<void> _refreshExtraLayers() async {
    if (!mounted) return;
    if (_loadingExtra) return;
    if (mounted) setState(() => _loadingExtra = true);
    try {
      final sosItems = await LiveGisApi.sosList(limit: 100);
      final crowdItems = await LiveGisApi.crowdReports();
      if (!mounted) return;
      setState(() {
        _sosItems = sosItems;
        _crowdItems = crowdItems;
      });
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loadingExtra = false);
    }
  }

  Future<void> _refreshViewport() async {
    final bounds = _mapController.camera.visibleBounds;
    await _store.refreshBbox(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );
    await _refreshExtraLayers();
  }

  Future<void> _onMapTapped(LatLng point) async {
    setState(() {
      _tappedLocation = point;
      _showInspectorSheet = true;
      _isInspecting = true;
    });
    try {
      final payload = await LiveGisApi.inspect(latitude: point.latitude, longitude: point.longitude);
      if (!mounted) return;
      setState(() {
        _inspection = {
          ...payload,
          'location_name': payload['location_name'] ?? 'Inspected coordinate',
          'coordinates': '${point.latitude.toStringAsFixed(4)} N, ${point.longitude.toStringAsFixed(4)} E',
        };
      });

      final rg = await LiveGisApi.reverseGeocode(latitude: point.latitude, longitude: point.longitude);
      if (mounted && rg['display_name'] != null) {
        setState(() {
          _inspection = {
            ...?_inspection,
            'display_name': rg['display_name'],
            'state': rg['state'],
            'district': rg['district'],
            'village': rg['village'],
          };
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inspection = {
          'location_name': 'Inspection failed',
          'coordinates': '${point.latitude.toStringAsFixed(4)} N, ${point.longitude.toStringAsFixed(4)} E',
          'error': e.toString(),
        };
      });
    } finally {
      if (mounted) setState(() => _isInspecting = false);
    }
  }

  List<Marker> _buildSosMarkers() {
    if (!_layerVisible['sos']!) return [];
    return _sosItems.map((s) {
      final lat = (s['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (s['longitude'] as num?)?.toDouble() ?? 0.0;
      final sev = s['severity']?.toString().toUpperCase() ?? 'HIGH';
      final color = sev == 'CRITICAL'
          ? const Color(0xFFDC2626)
          : sev == 'HIGH'
              ? const Color(0xFFD97706)
              : sev == 'MEDIUM'
                  ? const Color(0xFFCA8A04)
                  : const Color(0xFF6B7280);
      return Marker(
        point: LatLng(lat, lon),
        width: 36,
        height: 36,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 6, spreadRadius: 1),
            ],
          ),
          child: const Icon(Icons.sos_rounded, color: Colors.white, size: 16),
        ),
      );
    }).toList();
  }

  List<Marker> _buildCrowdMarkers() {
    if (!_layerVisible['crowd_reports']!) return [];
    return _crowdItems.map((c) {
      final lat = (c['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (c['longitude'] as num?)?.toDouble() ?? 0.0;
      final verified = c['verified'] == true;
      return Marker(
        point: LatLng(lat, lon),
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: verified ? const Color(0xFF059669) : const Color(0xFFCA8A04),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(verified ? Icons.verified_rounded : Icons.report_problem_rounded, color: Colors.white, size: 14),
        ),
      );
    }).toList();
  }

  List<Marker> _buildUsgsMarkers() {
    if (!_layerVisible['usgs_earthquakes']!) return [];
    return _alerts.alerts
        .where((a) => a['source']?.toString().toUpperCase() == 'USGS')
        .map((u) {
      final lat = (u['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (u['longitude'] as num?)?.toDouble() ?? 0.0;
      final mag = (u['magnitude'] as num?)?.toDouble() ?? 0.0;
      final size = (16 + (mag * 3).clamp(0.0, 24.0)).toDouble();
      return Marker(
        point: LatLng(lat, lon),
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF7C2D12).withValues(alpha: 0.7),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Center(
            child: Text(
              mag.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEonetMarkers() {
    if (!_layerVisible['nasa_eonet']!) return [];
    return _alerts.alerts
        .where((a) => a['source']?.toString().toUpperCase() == 'NASA_EONET')
        .map((u) {
      final lat = (u['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (u['longitude'] as num?)?.toDouble() ?? 0.0;
      return Marker(
        point: LatLng(lat, lon),
        width: 32,
        height: 32,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF7C3AED).withValues(alpha: 0.8),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
        ),
      );
    }).toList();
  }
  List<Marker> _buildGdacsMarkers() {
    if (!_layerVisible['gdacs']!) return [];
    return _alerts.alerts
        .where((a) => a['source']?.toString().toUpperCase() == 'GDACS')
        .where((a) => a['latitude'] != null && a['longitude'] != null)
        .map((u) {
      final lat = (u['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (u['longitude'] as num?)?.toDouble() ?? 0.0;
      final alertLevel = (u['alert_level']?.toString() ?? 'GREEN').toUpperCase();
      final eventType = (u['type']?.toString() ?? 'DISASTER').toUpperCase();
      final color = alertLevel == 'RED'
          ? const Color(0xFFDC2626)
          : alertLevel == 'ORANGE'
              ? const Color(0xFFEA580C)
              : alertLevel == 'YELLOW'
                  ? const Color(0xFFCA8A04)
                  : const Color(0xFF2563EB);
      final icon = eventType == 'EQ'
          ? Icons.public_rounded
          : eventType == 'TC'
              ? Icons.cyclone_rounded
              : eventType == 'FL'
                  ? Icons.water_rounded
                  : eventType == 'WF'
                      ? Icons.local_fire_department_rounded
                      : Icons.warning_amber_rounded;
      return Marker(
        point: LatLng(lat, lon),
        width: 34,
        height: 34,
        child: Container(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      );
    }).toList();
  }

  List<Marker> _buildEmscMarkers() {
    if (!_layerVisible['emsc']!) return [];
    return _alerts.alerts
        .where((a) => a['source']?.toString().toUpperCase() == 'EMSC')
        .map((u) {
      final lat = (u['latitude'] as num?)?.toDouble() ?? 0.0;
      final lon = (u['longitude'] as num?)?.toDouble() ?? 0.0;
      final mag = (u['magnitude'] as num?)?.toDouble() ?? 0.0;
      final size = (16 + (mag * 3).clamp(0.0, 24.0)).toDouble();
      final inIndia = u['in_india'] == true;
      return Marker(
        point: LatLng(lat, lon),
        width: size,
        height: size,
        child: Container(
          decoration: BoxDecoration(
            color: (inIndia ? const Color(0xFFB91C1C) : const Color(0xFF7C2D12)).withValues(alpha: 0.85),
            shape: BoxShape.circle,
            border: Border.all(color: inIndia ? const Color(0xFF10B981) : Colors.white, width: inIndia ? 3 : 2),
          ),
          child: Center(
            child: Text(
              mag.toStringAsFixed(1),
              style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Polygon> _zonePolygons() {
    if (!_layerVisible['red_zones']!) return [];
    if (_hideDemoData && _store.isDemoScenarioMode) return [];
    final polygons = <Polygon>[];
    for (final HazardZone zone in _store.zones) {
      final rings = parseWktPolygons(zone.geometryWkt);
      if (rings.isEmpty) continue;
      final isCritical = zone.riskScore >= 80;
      final fill = isCritical
          ? const Color(0xFFDC2626).withValues(alpha: 0.30)
          : const Color(0xFFD97706).withValues(alpha: 0.22);
      final stroke = isCritical ? const Color(0xFFB91C1C) : const Color(0xFFD97706);
      polygons.add(
        Polygon(
          points: rings.first,
          color: fill,
          borderColor: stroke,
          borderStrokeWidth: 2,
        ),
      );
    }
    return polygons;
  }

  List<Polyline> _routePolylines() {
    if (_routeResult == null) return [];
    final waypoints = _routeResult!['waypoints'] as List? ?? [];
    if (waypoints.length < 2) return [];
    final points = waypoints
        .map((wp) {
          final coords = (wp as List).map((e) => (e as num).toDouble()).toList();
          return LatLng(coords[0], coords[1]);
        })
        .toList();
    return [
      Polyline(
        points: points,
        color: const Color(0xFF000000),
        strokeWidth: 4.0,
        pattern: StrokePattern.dashed(segments: const [8.0, 6.0]),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _indiaCenter,
              initialZoom: _initialZoom,
              minZoom: 3.5,
              maxZoom: 18.0,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
              onTap: (_, point) => _onMapTapped(point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.de/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.disastermgmt.field_app',
              ),
              PolygonLayer(polygons: _zonePolygons()),
              PolylineLayer(polylines: _routePolylines()),
              MarkerLayer(
                markers: [
                  ...(_layerVisible['shelters']! && !(_hideDemoData && _store.isDemoScenarioMode)
                      ? _store.shelters.map((s) => Marker(
                            point: LatLng(s.latitude, s.longitude),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _setRouteDestination(LatLng(s.latitude, s.longitude)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: s.isInSafeZone ? const Color(0xFF059669) : const Color(0xFF6B7280),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.night_shelter_rounded, color: Colors.white, size: 16),
                              ),
                            ),
                          ))
                      : <Marker>[]),
                  ...(_layerVisible['habitations']! && !(_hideDemoData && _store.isDemoScenarioMode)
                      ? _store.habitations.map((h) => Marker(
                            point: LatLng(h.latitude, h.longitude),
                            width: 36,
                            height: 36,
                            child: GestureDetector(
                              onTap: () => _setRouteOrigin(LatLng(h.latitude, h.longitude)),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: h.priorityCategory == 'IMMEDIATE'
                                      ? const Color(0xFFDC2626)
                                      : const Color(0xFFD97706),
                                  borderRadius: BorderRadius.circular(h.priorityCategory == 'IMMEDIATE' ? 8 : 19),
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: Icon(
                                  h.priorityCategory == 'IMMEDIATE' ? Icons.warning_rounded : Icons.home_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ))
                      : <Marker>[]),
                  ..._buildSosMarkers(),
                  ..._buildCrowdMarkers(),
                  ..._buildUsgsMarkers(),
                  ..._buildEonetMarkers(),
                  ..._buildGdacsMarkers(),
                  ..._buildEmscMarkers(),
                  if (_routeOrigin != null)
                    Marker(
                      point: _routeOrigin!,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF0EA5E9),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.trip_origin_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  if (_routeDestination != null)
                    Marker(
                      point: _routeDestination!,
                      width: 32,
                      height: 32,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF059669),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.place_rounded, color: Colors.white, size: 18),
                      ),
                    ),
                  if (_tappedLocation != null)
                    Marker(
                      point: _tappedLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ],
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: const [
                          BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2)),
                        ],
                      ),
                      child: Text(
                        _alerts.hasAlerts
                            ? 'LIVE: ${_alerts.alerts.length} alerts from ${_alerts.sourcesAttempted.length} sources • Tap to inspect'
                            : _store.alert['headline']?.toString() ?? 'Tap to inspect • Tap layers icon to toggle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _iconButton(Icons.layers_rounded, () => setState(() => _showLayersPanel = true)),
                  const SizedBox(width: 6),
                  _iconButton(Icons.route_rounded, () => setState(() => _showRouteSheet = true)),
                  const SizedBox(width: 6),
                  _iconButton(Icons.refresh_rounded, _refreshViewport,
                      loading: _store.loading || _loadingExtra),
                ],
              ),
            ),
          ),

          if (_showInspectorSheet) _buildInspectorSheet(),
          if (_showLayersPanel) _buildLayersPanel(),
        ],
      ),
    );
  }

  Widget _buildLayersPanel() {
    final layerDefs = <(String, String, IconData, Color)>[
      ('red_zones', 'Red Zones (AI hazard polygons)', Icons.layers_rounded, const Color(0xFFDC2626)),
      ('shelters', 'Safe Shelters', Icons.night_shelter_rounded, const Color(0xFF059669)),
      ('habitations', 'Habitations', Icons.home_rounded, const Color(0xFFD97706)),
      ('sos', 'Active SOS', Icons.sos_rounded, const Color(0xFFDC2626)),
      ('crowd_reports', 'Crowd Reports', Icons.report_problem_rounded, const Color(0xFFCA8A04)),
      ('usgs_earthquakes', 'USGS Earthquakes', Icons.public_rounded, const Color(0xFFDC2626)),
      ('emsc', 'EMSC Earthquakes', Icons.public_rounded, const Color(0xFFB91C1C)),
      ('nasa_eonet', 'NASA EONET (Fires/Volcanoes)', Icons.local_fire_department_rounded, const Color(0xFF7C3AED)),
      ('gdacs', 'GDACS (UN/EU Alerts)', Icons.cyclone_rounded, const Color(0xFF2563EB)),
    ];
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 60, 12, 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.layers_rounded, size: 18, color: Color(0xFF000000)),
                const SizedBox(width: 8),
                const Text('Map Layers', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF6B7280)),
                  onPressed: () => setState(() => _showLayersPanel = false),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFECFDF5), borderRadius: BorderRadius.circular(6)),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF059669)),
                  ),
                  const SizedBox(width: 4),
                  Text('${_alerts.alerts.length} live alerts from ${_alerts.sourcesAttempted.length} sources',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ...layerDefs.map((def) {
              final id = def.$1;
              final name = def.$2;
              final icon = def.$3;
              final color = def.$4;
              return CheckboxListTile(
                value: _layerVisible[id] ?? false,
                onChanged: (v) => setState(() => _layerVisible[id] = v ?? false),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.trailing,
                title: Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  ],
                ),
              );
            }),
            const Divider(height: 16),
            SwitchListTile(
              value: _hideDemoData,
              onChanged: (v) => setState(() => _hideDemoData = v),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Row(
                children: [
                  Icon(Icons.visibility_off_rounded, size: 16, color: Color(0xFF6B7280)),
                  SizedBox(width: 8),
                  Expanded(child: Text('Hide demo data (show only LIVE)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8)),
              child: const Text(
                'USGS + EMSC + GDACS + NASA EONET markers are 100% LIVE data. '
                'Red Zones + Shelters + Habitations come from the backend GIS snapshot '
                '(falls back to Odisha demo when the backend Overpass API is slow).',
                style: TextStyle(fontSize: 10, color: Color(0xFF6B7280), height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _iconButton(IconData icon, VoidCallback onTap, {bool loading = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(color: Color(0x14000000), blurRadius: 10, offset: Offset(0, 2)),
          ],
        ),
        child: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
              )
            : Icon(icon, color: const Color(0xFF000000), size: 18),
      ),
    );
  }

  void _setRouteOrigin(LatLng p) {
    setState(() {
      _routeOrigin = p;
      if (_routeDestination != null) _computeRoute();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Route origin set. Tap a shelter to set destination.')),
    );
  }

  void _setRouteDestination(LatLng p) {
    setState(() {
      _routeDestination = p;
      if (_routeOrigin != null) _computeRoute();
    });
  }

  Future<void> _computeRoute() async {
    if (_routeOrigin == null || _routeDestination == null) return;
    setState(() => _routeResult = null);
    final result = await LiveGisApi.gisRoute(
      originLat: _routeOrigin!.latitude,
      originLon: _routeOrigin!.longitude,
      destLat: _routeDestination!.latitude,
      destLon: _routeDestination!.longitude,
      avoidRedZones: true,
    );
    setState(() {
      _routeResult = result;
      _showRouteSheet = true;
    });
  }

  Widget _buildInspectorSheet() {
    final inspection = _inspection ?? const <String, dynamic>{};
    final riskScore = (inspection['risk_score'] as num?)?.toDouble() ?? 0.0;
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(color: Color(0x24000000), blurRadius: 20, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(color: const Color(0xFFD1D5DB), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inspection['display_name']?.toString() ??
                            inspection['location_name']?.toString() ??
                            'Inspected location',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        inspection['coordinates']?.toString() ?? '',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280), size: 20),
                  onPressed: () => setState(() => _showInspectorSheet = false),
                ),
              ],
            ),
            if (_isInspecting)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
                    SizedBox(width: 8),
                    Text('Running live GIS inspection...', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              )
            else ...[
              if (inspection['state'] != null || inspection['district'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Administrative: ${inspection['state'] ?? '--'} › ${inspection['district'] ?? '--'} › ${inspection['village'] ?? inspection['sub_district'] ?? '--'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          riskScore >= 55 ? Icons.warning_rounded : Icons.verified_rounded,
                          size: 22,
                          color: riskScore >= 55 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${(inspection['risk_score'] as num?) ?? 0}/100 • ${inspection['risk_level'] ?? 'UNKNOWN'}',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                              ),
                              Text(
                                '${inspection['hazard_type'] ?? 'UNKNOWN'} • ${inspection['urgency'] ?? 'N/A'}',
                                style: const TextStyle(fontSize: 10, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _metricTile('Rain 24h', '${inspection['precipitation_24h_mm'] ?? '--'} mm'),
                        _metricTile('Slope', '${inspection['slope_value'] ?? inspection['slope_percentage'] ?? '--'} %'),
                        _metricTile('Elev.', '${inspection['elevation_value'] ?? inspection['elevation'] ?? '--'} m'),
                        _metricTile('Soil', '${inspection['soil_moisture_index'] ?? '--'}'),
                      ],
                    ),
                  ],
                ),
              ),
              if (inspection['nearest_shelter'] is Map)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                    child: Text(
                      'Nearest shelter: ${(inspection['nearest_shelter'] as Map)['shelter_name'] ?? 'Unknown'} • ${inspection['nearest_shelter_km'] ?? '--'} km',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280))),
            const SizedBox(height: 1),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}