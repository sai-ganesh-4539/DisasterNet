import 'package:field_app/core/wkt.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/hazard_zone.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class MapHUDView extends StatefulWidget {
  final Habitation? initialSelectedHabitation;
  final SafeShelter? initialSelectedShelter;

  const MapHUDView({
    super.key,
    this.initialSelectedHabitation,
    this.initialSelectedShelter,
  });

  @override
  State<MapHUDView> createState() => _MapHUDViewState();
}

class _MapHUDViewState extends State<MapHUDView> {
  final MapController _mapController = MapController();
  final LiveGisStore _store = LiveGisStore.instance;

  static const LatLng _indiaCenter = LatLng(21.7679, 78.8718);
  static const double _initialZoom = 4.6;

  LatLng? _tappedLocation;
  Habitation? _selectedHabitation;
  SafeShelter? _selectedShelter;
  Map<String, dynamic>? _inspection;
  bool _showInspectorSheet = false;
  bool _isInspecting = false;

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _initialize();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _store.initializeAndRefresh();
    if (widget.initialSelectedHabitation != null) {
      await _selectHabitation(widget.initialSelectedHabitation!);
    } else if (widget.initialSelectedShelter != null) {
      await _selectShelter(widget.initialSelectedShelter!);
    }
  }

  bool _isWithinIndia(double lat, double lon) {
    return lat >= 6.0 && lat <= 37.5 && lon >= 68.0 && lon <= 97.5;
  }

  double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, LatLng(lat1, lon1), LatLng(lat2, lon2));
  }

  Future<void> _refreshViewport() async {
    final camera = _mapController.camera;
    final bounds = camera.visibleBounds;
    await _store.refreshBbox(
      south: bounds.south,
      west: bounds.west,
      north: bounds.north,
      east: bounds.east,
    );
  }

  Future<void> _onMapTapped(LatLng point) async {
    if (!_isWithinIndia(point.latitude, point.longitude)) {
      setState(() {
        _tappedLocation = point;
        _selectedHabitation = null;
        _selectedShelter = null;
        _inspection = {
          'location_name': 'Outside supported India extent',
          'coordinates': '${point.latitude.toStringAsFixed(4)} N, ${point.longitude.toStringAsFixed(4)} E',
          'is_within_india': false,
          'risk_score': 0,
          'risk_level': 'N/A',
          'hazard_type': 'OUT_OF_SCOPE',
          'urgency': 'N/A',
        };
        _showInspectorSheet = true;
      });
      return;
    }

    final nearestHab = _findNearestHabitation(point);
    final nearestShelter = _findNearestShelter(point);
    if (nearestHab != null && nearestHab.$2 <= 1.2) {
      await _selectHabitation(nearestHab.$1);
      return;
    }
    if (nearestShelter != null && nearestShelter.$2 <= 1.2) {
      await _selectShelter(nearestShelter.$1);
      return;
    }
    await _inspectPoint(point, label: 'Inspected coordinate');
  }

  (Habitation, double)? _findNearestHabitation(LatLng point) {
    if (_store.habitations.isEmpty) return null;
    Habitation? best;
    var min = double.infinity;
    for (final h in _store.habitations) {
      final d = _distanceKm(point.latitude, point.longitude, h.latitude, h.longitude);
      if (d < min) {
        min = d;
        best = h;
      }
    }
    return best == null ? null : (best, min);
  }

  (SafeShelter, double)? _findNearestShelter(LatLng point) {
    if (_store.shelters.isEmpty) return null;
    SafeShelter? best;
    var min = double.infinity;
    for (final s in _store.shelters) {
      final d = _distanceKm(point.latitude, point.longitude, s.latitude, s.longitude);
      if (d < min) {
        min = d;
        best = s;
      }
    }
    return best == null ? null : (best, min);
  }

  Future<void> _inspectPoint(LatLng point, {String? label}) async {
    setState(() {
      _tappedLocation = point;
      _selectedHabitation = null;
      _selectedShelter = null;
      _showInspectorSheet = true;
      _isInspecting = true;
    });
    try {
      final payload = await LiveGisApi.inspect(latitude: point.latitude, longitude: point.longitude);
      if (!mounted) return;
      setState(() {
        _inspection = {
          ...payload,
          'location_name': label ?? payload['location_name'] ?? 'Inspected coordinate',
          'coordinates': '${point.latitude.toStringAsFixed(4)} N, ${point.longitude.toStringAsFixed(4)} E',
        };
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _inspection = {
          'location_name': label ?? 'Inspection failed',
          'coordinates': '${point.latitude.toStringAsFixed(4)} N, ${point.longitude.toStringAsFixed(4)} E',
          'is_within_india': true,
          'error': e.toString(),
        };
      });
    } finally {
      if (mounted) {
        setState(() => _isInspecting = false);
      }
    }
  }

  Future<void> _selectHabitation(Habitation habitation) async {
    _mapController.move(LatLng(habitation.latitude, habitation.longitude), 13.8);
    setState(() {
      _selectedHabitation = habitation;
      _selectedShelter = null;
    });
    await _inspectPoint(
      LatLng(habitation.latitude, habitation.longitude),
      label: '${habitation.villageName}, ${habitation.districtName}',
    );
    if (!mounted) return;
    setState(() {
      _inspection = {
        ...?_inspection,
        'priority_score': habitation.priorityScore,
        'priority_category': habitation.priorityCategory,
        'population': habitation.totalPopulation,
        'road_status': habitation.pathStatus,
        'slope_value': habitation.slopePercentage,
        'elevation_value': habitation.elevation,
      };
    });
  }

  Future<void> _selectShelter(SafeShelter shelter) async {
    _mapController.move(LatLng(shelter.latitude, shelter.longitude), 13.8);
    setState(() {
      _selectedShelter = shelter;
      _selectedHabitation = null;
    });
    await _inspectPoint(LatLng(shelter.latitude, shelter.longitude), label: shelter.shelterName);
    if (!mounted) return;
    setState(() {
      _inspection = {
        ...?_inspection,
        'available_capacity': shelter.availableCapacity,
        'effective_capacity': shelter.effectiveCapacity,
        'capacity_status': shelter.capacityStatus,
        'capacity_constraint': shelter.capacityConstraint,
        'safety_buffer_km': shelter.safetyBufferKm,
      };
    });
  }

  List<Polygon> _zonePolygons() {
    final polygons = <Polygon>[];
    for (final HazardZone zone in _store.zones) {
      final rings = parseWktPolygons(zone.geometryWkt);
      if (rings.isEmpty) continue;
      final isCritical = zone.riskScore >= 80;
      final fill = isCritical ? const Color(0xFFDC2626).withValues(alpha: 0.30) : const Color(0xFFD97706).withValues(alpha: 0.22);
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

  @override
  Widget build(BuildContext context) {
    final isReady = _store.hasLiveData || !_store.loading;
    final inspection = _inspection ?? const <String, dynamic>{};
    final riskScore = (inspection['risk_score'] as num?)?.toDouble() ?? (_selectedHabitation?.priorityScore ?? 0.0);
    final isRisky = riskScore >= 55;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: isReady
          ? Stack(
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
                      urlTemplate: 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
		      subdomains: const ['a', 'b', 'c', 'd'],
                      userAgentPackageName: 'com.disastermgmt.field_app',
                    ),
                    PolygonLayer(polygons: _zonePolygons()),
                    MarkerLayer(
                      markers: [
                        ..._store.habitations.map((h) => Marker(
                              point: LatLng(h.latitude, h.longitude),
                              width: 38,
                              height: 38,
                              child: GestureDetector(
                                onTap: () => _selectHabitation(h),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: h.priorityCategory == 'IMMEDIATE' ? const Color(0xFFDC2626) : const Color(0xFFD97706),
                                    borderRadius: BorderRadius.circular(h.priorityCategory == 'IMMEDIATE' ? 8 : 19),
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: Icon(
                                    h.priorityCategory == 'IMMEDIATE' ? Icons.warning_rounded : Icons.home_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            )),
                        ..._store.shelters.map((s) => Marker(
                              point: LatLng(s.latitude, s.longitude),
                              width: 38,
                              height: 38,
                              child: GestureDetector(
                                onTap: () => _selectShelter(s),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: s.isInSafeZone ? const Color(0xFF059669) : const Color(0xFF6B7280),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 2),
                                  ),
                                  child: const Icon(Icons.night_shelter_rounded, color: Colors.white, size: 18),
                                ),
                              ),
                            )),
                        if (_tappedLocation != null)
                          Marker(
                            point: _tappedLocation!,
                            width: 36,
                            height: 36,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF000000),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 18),
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
                              color: const Color(0xFFFFFFFF),
                              borderRadius: BorderRadius.circular(30),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Text(
                              _store.alert['headline']?.toString() ?? (_store.isDemoScenarioMode ? 'Tap the map to inspect scenario risk' : 'Tap the map to inspect live risk'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF1F2937)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: _refreshViewport,
                          child: Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFFFF),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 10, offset: const Offset(0, 2)),
                              ],
                            ),
                            child: _store.loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.refresh_rounded, color: Color(0xFF000000), size: 18),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showInspectorSheet)
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFFFF),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 4)),
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
                                      inspection['location_name']?.toString() ?? 'Inspected location',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
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
                          else if (inspection['is_within_india'] == false)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                'This point lies outside the supported India analysis extent.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
                              ),
                            )
                          else ...[
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF9FAFB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(isRisky ? Icons.warning_rounded : Icons.verified_rounded, size: 24, color: isRisky ? const Color(0xFFDC2626) : const Color(0xFF059669)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${riskScore.toStringAsFixed(0)}/100 • ${inspection['risk_level'] ?? 'UNKNOWN'}',
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                            ),
                                            Text(
                                              '${inspection['hazard_type'] ?? 'UNKNOWN'} • ${inspection['urgency'] ?? 'N/A'}',
                                              style: const TextStyle(fontSize: 10.5, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _metricTile('Rain 24h', '${(inspection['precipitation_24h_mm'] ?? 0).toString()} mm'),
                                      _metricTile('Slope', '${(inspection['slope_value'] ?? inspection['slope_percentage'] ?? 0).toString()} %'),
                                      _metricTile('Elev.', '${(inspection['elevation_value'] ?? inspection['elevation'] ?? 0).toString()} m'),
                                      _metricTile('Soil', '${inspection['soil_moisture_index'] ?? '--'}'),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_selectedHabitation != null)
                              Text(
                                'Priority ${inspection['priority_category'] ?? _selectedHabitation!.priorityCategory} • Population ${inspection['population'] ?? _selectedHabitation!.totalPopulation} • Road ${inspection['road_status'] ?? _selectedHabitation!.pathStatus}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                              ),
                            if (_selectedShelter != null)
                              Text(
                                'Shelter capacity ${inspection['available_capacity'] ?? _selectedShelter!.availableCapacity}/${_selectedShelter!.effectiveCapacity} • Constraint ${inspection['capacity_constraint'] ?? _selectedShelter!.capacityConstraint}',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563), fontWeight: FontWeight.w600),
                              ),
                            if (inspection['nearest_shelter'] is Map)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(12)),
                                  child: Text(
                                    'Nearest candidate shelter: ${(inspection['nearest_shelter'] as Map)['shelter_name'] ?? 'Unknown'} • ${(inspection['nearest_shelter_km'] ?? '--').toString()} km',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                            if (inspection['error'] != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  inspection['error'].toString(),
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFB91C1C)),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
              ],
            )
          : const Center(child: CircularProgressIndicator(color: Colors.black)),
    );
  }

  Widget _metricTile(String label, String value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 8, color: Color(0xFF6B7280))),
            const SizedBox(height: 1),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
