import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:flutter/material.dart';

class ShelterCapacityView extends StatefulWidget {
  final Function(SafeShelter)? onSelectShelterOnMap;

  const ShelterCapacityView({super.key, this.onSelectShelterOnMap});

  @override
  State<ShelterCapacityView> createState() => _ShelterCapacityViewState();
}

class _ShelterCapacityViewState extends State<ShelterCapacityView> {
  final LiveGisStore _store = LiveGisStore.instance;
  List<SafeShelter> _shelters = [];
  String _selectedFilter = 'ALL';
  int _activeTabIndex = 0;
  bool _isEvaluatingSite = false;
  bool _isRegisteringSite = false;
  Map<String, dynamic>? _evaluatedSiteResult;

  final _siteNameController = TextEditingController();
  final _districtController = TextEditingController();
  final _stateCodeController = TextEditingController(text: 'IN');
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _hectaresController = TextEditingController(text: '4.5');
  final _roadDistController = TextEditingController(text: '0.8');

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _siteNameController.text = 'Proposed Relocation Sector';
    _districtController.text = 'District';
    _latController.text = '20.0850';
    _lonController.text = '86.1520';
    _syncFromStore();
    _store.initializeAndRefresh();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    _siteNameController.dispose();
    _districtController.dispose();
    _stateCodeController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _hectaresController.dispose();
    _roadDistController.dispose();
    super.dispose();
  }

  void _onStoreChanged() {
    if (!mounted) return;
    _syncFromStore();
  }

  void _syncFromStore() {
    setState(() {
      _shelters = List<SafeShelter>.from(_store.shelters)
        ..sort((a, b) => b.availableCapacity.compareTo(a.availableCapacity));
    });
  }

  Future<void> _refresh() => _store.refreshFromLocationOrIndia();

  List<SafeShelter> get _filteredShelters {
    if (_selectedFilter == 'ALL') return _shelters;
    if (_selectedFilter == 'AVAILABLE') return _shelters.where((s) => s.availableCapacity > 100 && s.isInSafeZone).toList();
    if (_selectedFilter == 'CRITICAL') return _shelters.where((s) => s.capacityStatus == 'CRITICAL' || !s.isInSafeZone).toList();
    return _shelters;
  }

  int get _totalCapacity => _shelters.fold(0, (sum, s) => sum + s.totalCapacity);
  int get _totalOccupancy => _shelters.fold(0, (sum, s) => sum + s.currentPopulation);
  int get _totalAvailable => _shelters.fold(0, (sum, s) => sum + s.availableCapacity);

  Future<void> _evaluateGreenfieldSite() async {
    final lat = double.tryParse(_latController.text);
    final lon = double.tryParse(_lonController.text);
    final hectares = double.tryParse(_hectaresController.text);
    final roadDistanceKm = double.tryParse(_roadDistController.text);
    if (lat == null || lon == null || hectares == null || roadDistanceKm == null) return;

    setState(() => _isEvaluatingSite = true);
    try {
      final result = await LiveGisApi.evaluateCandidateSite(
        siteName: _siteNameController.text.trim(),
        districtName: _districtController.text.trim(),
        stateCode: _stateCodeController.text.trim().toUpperCase(),
        latitude: lat,
        longitude: lon,
        hectares: hectares,
        roadDistanceKm: roadDistanceKm,
      );
      if (!mounted) return;
      setState(() => _evaluatedSiteResult = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Site evaluation failed: $e'), backgroundColor: const Color(0xFFB91C1C)),
      );
    } finally {
      if (mounted) setState(() => _isEvaluatingSite = false);
    }
  }

  Future<void> _registerEvaluatedSite() async {
    final result = _evaluatedSiteResult;
    if (result == null) return;
    setState(() => _isRegisteringSite = true);
    try {
      final latitude = (result['latitude'] as num).toDouble();
      final longitude = (result['longitude'] as num).toDouble();
      final registration = await LiveGisApi.registerCandidateSite(
        siteName: _siteNameController.text.trim(),
        districtName: _districtController.text.trim(),
        stateCode: _stateCodeController.text.trim().toUpperCase(),
        latitude: latitude,
        longitude: longitude,
        hectares: (result['hectares'] as num).toDouble(),
        roadDistanceKm: (result['road_distance_km'] as num).toDouble(),
      );
      await _store.refreshAround(latitude, longitude, padDegrees: 0.55);
      if (!mounted) return;
      final message = registration['message']?.toString() ?? 'Candidate site registered.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: const Color(0xFF000000)),
      );
      setState(() => _activeTabIndex = 0);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Site registration failed: $e'), backgroundColor: const Color(0xFFB91C1C)),
      );
    } finally {
      if (mounted) setState(() => _isRegisteringSite = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _store.loading && _shelters.isEmpty
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : RefreshIndicator(
                onRefresh: _refresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Shelter & Greenfield Siting', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                                SizedBox(height: 4),
                                Text(
                                  'Live carrying-capacity audit and proposed-site evaluator driven by the backend GIS engine.',
                                  style: TextStyle(fontSize: 12.5, color: Color(0xFF757575), height: 1.3),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: _store.loading
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                                : const Icon(Icons.refresh_rounded, color: Color(0xFF000000)),
                            onPressed: _store.loading ? null : _refresh,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30), border: Border.all(color: const Color(0xFFE5E7EB))),
                        child: Row(
                          children: [
                            Expanded(child: _toggleTab('Shelter Capacities (${_shelters.length})', 0)),
                            Expanded(child: _toggleTab('Evaluate New Site', 1)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_activeTabIndex == 0) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildFilterChip('ALL', 'All Shelters (${_shelters.length})'),
                              const SizedBox(width: 8),
                              _buildFilterChip('AVAILABLE', 'Safe + Available'),
                              const SizedBox(width: 8),
                              _buildFilterChip('CRITICAL', 'Unsafe / Bottlenecked'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFE5E7EB))),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildSummaryItem('Total Beds', '$_totalCapacity', Icons.night_shelter_rounded),
                              _buildDivider(),
                              _buildSummaryItem('Occupied', '$_totalOccupancy', Icons.people_outline_rounded, color: const Color(0xFF4B5563)),
                              _buildDivider(),
                              _buildSummaryItem('Available', '$_totalAvailable', Icons.check_circle_outline_rounded, color: const Color(0xFF059669)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        if (_filteredShelters.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(32),
                            alignment: Alignment.center,
                            child: Text('No shelters match the filter.', style: TextStyle(color: Colors.grey[600])),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filteredShelters.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 14),
                            itemBuilder: (context, index) => _buildShelterCard(_filteredShelters[index]),
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.travel_explore_rounded, size: 20, color: Color(0xFF000000)),
                                  SizedBox(width: 8),
                                  Text('Proposed Relocation Site Evaluator', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Backend or bundled demo package evaluates hazard context, terrain, red-zone clearance, and carrying capacity.',
                                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                              ),
                              const SizedBox(height: 14),
                              _buildInputField('Candidate Site Name', _siteNameController),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildInputField('District', _districtController)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildInputField('State Code', _stateCodeController)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildInputField('Latitude', _latController, isNumber: true)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildInputField('Longitude', _lonController, isNumber: true)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: _buildInputField('Land (Hectares)', _hectaresController, isNumber: true)),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildInputField('Road Distance (km)', _roadDistController, isNumber: true)),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isEvaluatingSite ? null : _evaluateGreenfieldSite,
                                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000000), foregroundColor: const Color(0xFFFFFFFF), padding: const EdgeInsets.symmetric(vertical: 12)),
                                  child: _isEvaluatingSite
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                      : const Text('Evaluate Site Suitability', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_evaluatedSiteResult != null) _buildSiteResultCard(_evaluatedSiteResult!),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _toggleTab(String label, int index) {
    return GestureDetector(
      onTap: () => setState(() => _activeTabIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _activeTabIndex == index ? const Color(0xFF000000) : Colors.transparent, borderRadius: BorderRadius.circular(24)),
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _activeTabIndex == index ? Colors.white : const Color(0xFF4B5563))),
      ),
    );
  }

  Widget _buildSiteResultCard(Map<String, dynamic> result) {
    final capacity = Map<String, dynamic>.from(result['capacity'] as Map? ?? {});
    final terrain = Map<String, dynamic>.from(result['terrain'] as Map? ?? {});
    final hazard = Map<String, dynamic>.from(result['hazard_context'] as Map? ?? {});
    final suitability = (result['overall_suitability'] ?? 'UNKNOWN').toString();
    final color = suitability == 'HIGHLY_SUITABLE' || suitability == 'SUITABLE'
        ? const Color(0xFF059669)
        : suitability == 'CONDITIONALLY_SUITABLE'
            ? const Color(0xFFD97706)
            : const Color(0xFFDC2626);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
                child: Text(suitability.replaceAll('_', ' '), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white)),
              ),
              const Spacer(),
              Text('Score: ${result['overall_score']}/100', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
            ],
          ),
          const SizedBox(height: 12),
          Text(result['site_name']?.toString() ?? 'Candidate site', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(
            'District: ${result['district_name']} • Elevation: ${terrain['elevation_m']} m • Slope: ${terrain['slope_percentage']}%',
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildSiteStatPill(Icons.groups_rounded, 'Capacity', '${capacity['planned_population_capacity']}'),
              const SizedBox(width: 6),
              _buildSiteStatPill(Icons.shield_outlined, 'Hazard Buffer', '${result['nearest_red_zone_distance_km']} km'),
              const SizedBox(width: 6),
              _buildSiteStatPill(Icons.water_drop_rounded, 'Water', '${capacity['water_available_liters']} L'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Live context: ${hazard['hazard_type']} • risk ${hazard['risk_score']} • rain 24h ${hazard['precipitation_24h_mm']} mm',
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
          ),
          const SizedBox(height: 6),
          Text(
            'Recommendation: ${result['recommendation']}',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isRegisteringSite ? null : _registerEvaluatedSite,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF059669), foregroundColor: const Color(0xFFFFFFFF), padding: const EdgeInsets.symmetric(vertical: 11)),
              child: _isRegisteringSite
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Register as Live Relocation Site', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF4B5563))),
        const SizedBox(height: 3),
        TextFormField(
          controller: controller,
          keyboardType: isNumber ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
          ),
        ),
      ],
    );
  }

  Widget _buildSiteStatPill(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 12, color: const Color(0xFF6B7280)), const SizedBox(width: 4), Text(label, style: const TextStyle(fontSize: 8.5, color: Color(0xFF6B7280)))]),
            const SizedBox(height: 2),
            Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(color: isSelected ? const Color(0xFF000000) : const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(24), border: Border.all(color: isSelected ? const Color(0xFF000000) : const Color(0xFFE5E7EB))),
        child: Text(label, style: TextStyle(color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFF374151), fontSize: 12.5, fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600)),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF000000)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF000000))),
        Text(title, style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDivider() => Container(height: 24, width: 1, color: const Color(0xFFE5E7EB));

  Widget _buildShelterCard(SafeShelter shelter) {
    final occupancyPct = (shelter.currentPopulation / (shelter.totalCapacity == 0 ? 1 : shelter.totalCapacity)).clamp(0.0, 1.0);
    final pop = shelter.currentPopulation > 0 ? shelter.currentPopulation : 100;
    final waterDays = (shelter.waterAvailableLiters / (pop * 15)).clamp(0.0, 45.0);
    final foodDays = (shelter.foodAvailableKg / (pop * 0.5)).clamp(0.0, 45.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFFFFFFFF), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(shelter.shelterName, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                    const SizedBox(height: 2),
                    Text('${shelter.shelterType} • ${shelter.districtName} • Buffer: ${shelter.safetyBufferKm} km', style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              _buildConstraintBadge(shelter.capacityConstraint, shelter.isInSafeZone),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bed Capacity', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  Text('${shelter.currentPopulation} / ${shelter.totalCapacity} occupied (${shelter.availableCapacity} left)', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: occupancyPct > 0.8 ? const Color(0xFFDC2626) : const Color(0xFF059669))),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occupancyPct,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(occupancyPct > 0.85 ? const Color(0xFFDC2626) : (occupancyPct > 0.6 ? const Color(0xFFD97706) : const Color(0xFF059669))),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildResourceMeter(Icons.water_drop_rounded, 'Potable Water', '${waterDays.toStringAsFixed(0)} Days', waterDays > 7),
              const SizedBox(width: 6),
              _buildResourceMeter(Icons.restaurant_rounded, 'Food Rations', '${foodDays.toStringAsFixed(0)} Days', foodDays > 7),
              const SizedBox(width: 6),
              _buildResourceMeter(Icons.medical_services_rounded, 'Medical Tier', shelter.hasMedicalFacility ? 'Available' : 'Basic Only', shelter.hasMedicalFacility),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showAuditSummary(shelter),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000000), foregroundColor: const Color(0xFFFFFFFF), elevation: 0, padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
                  child: const Text('Audit Summary', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30)),
                child: IconButton(icon: const Icon(Icons.map_rounded, color: Color(0xFF000000), size: 18), onPressed: () => widget.onSelectShelterOnMap?.call(shelter)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintBadge(String constraint, bool isSafe) {
    if (!isSafe) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(16)),
        child: const Text('UNSAFE', style: TextStyle(color: Color(0xFFB91C1C), fontSize: 9, fontWeight: FontWeight.w800)),
      );
    }
    Color bg = const Color(0xFFECFDF5);
    Color text = const Color(0xFF059669);
    String label = constraint == 'NONE' ? 'OPTIMAL' : '$constraint LIMITED';
    if (constraint == 'WATER') {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
    } else if (constraint == 'FOOD') {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFB45309);
    } else if (constraint == 'BEDS' || constraint == 'SPACE') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFB91C1C);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
      child: Text(label, style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildResourceMeter(IconData icon, String label, String value, bool isHealthy) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [Icon(icon, size: 9.5, color: const Color(0xFF6B7280)), const SizedBox(width: 2), Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)))]),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: isHealthy ? const Color(0xFF111827) : const Color(0xFFDC2626))),
          ],
        ),
      ),
    );
  }

  void _showAuditSummary(SafeShelter shelter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(color: Color(0xFFFFFFFF), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Text('Audit Summary: ${shelter.shelterName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text('Capacity status: ${shelter.capacityStatus}', style: const TextStyle(fontSize: 12)),
            Text('Constraint: ${shelter.capacityConstraint}', style: const TextStyle(fontSize: 12)),
            Text('Safe buffer: ${shelter.safetyBufferKm} km', style: const TextStyle(fontSize: 12)),
            Text('Water: ${shelter.waterAvailableLiters} L • Food: ${shelter.foodAvailableKg} kg', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(46)),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }
}
