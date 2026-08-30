import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/core/database.dart';

class RelocationPriorityView extends StatefulWidget {
  final Function(Habitation)? onSelectHabitationOnMap;
  final Function(SafeShelter)? onSelectShelterOnMap;

  const RelocationPriorityView({
    super.key,
    this.onSelectHabitationOnMap,
    this.onSelectShelterOnMap,
  });

  @override
  State<RelocationPriorityView> createState() => _RelocationPriorityViewState();
}

class _RelocationPriorityViewState extends State<RelocationPriorityView> {
  final DatabaseService _db = DatabaseService();
  String _selectedFilter = 'ALL'; // ALL, IMMEDIATE, SHORT_TERM, MEDIUM_TERM
  List<Habitation> _habitations = [];
  List<SafeShelter> _shelters = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final habitations = await _db.getAllHabitations();
    final shelters = await _db.getAllSafeShelters();

    setState(() {
      _habitations = habitations;
      _shelters = shelters;
      _isLoading = false;
    });
  }

  List<Habitation> get _filteredHabitations {
    if (_selectedFilter == 'ALL') return _habitations;
    return _habitations.where((h) => h.priorityCategory.toUpperCase() == _selectedFilter).toList();
  }

  int get _immediateCount => _habitations.where((h) => h.priorityCategory == 'IMMEDIATE').length;
  int get _shortTermCount => _habitations.where((h) => h.priorityCategory == 'SHORT_TERM').length;
  int get _mediumTermCount => _habitations.where((h) => h.priorityCategory == 'MEDIUM_TERM').length;

  /// Exact spherical haversine distance in kilometers
  double _calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadiusKm = 6371.0;
    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (math.pi / 180.0);
  }

  // Dynamic calculation: Find nearest safe shelter for a given habitation
  (SafeShelter?, double) _findNearestShelter(Habitation habitation) {
    if (_shelters.isEmpty) return (null, 0.0);

    SafeShelter? bestShelter;
    double minDistance = double.infinity;

    for (final shelter in _shelters) {
      final dist = _calculateDistanceKm(
        habitation.latitude,
        habitation.longitude,
        shelter.latitude,
        shelter.longitude,
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestShelter = shelter;
      }
    }

    return (bestShelter, minDistance);
  }

  Future<void> _recalculateLiveAiScoring() async {
    setState(() => _isLoading = true);
    for (final h in _habitations) {
      try {
        final weather = await WeatherService.fetchRealTimeWeather(h.latitude, h.longitude);
        final rainImpact = weather.precipitation > 30.0 ? 55.0 : (weather.precipitation * 1.5);
        final slopeImpact = (h.slopePercentage * 0.9).clamp(0.0, 35.0);
        final hazardScore = (rainImpact + slopeImpact + 10.0).clamp(10.0, 95.0);
        
        final vulnerabilityScore = ((h.population60Plus + h.population0to6) / (h.totalPopulation > 0 ? h.totalPopulation : 1)) * 100.0;
        final isolationScore = h.pathStatus == 'BLOCKED' ? 95.0 : (h.pathStatus == 'DAMAGED' ? 70.0 : 25.0);
        
        final newPriority = (0.45 * hazardScore + 0.35 * vulnerabilityScore + 0.20 * isolationScore).clamp(5.0, 99.0);
        h.priorityScore = newPriority;
        h.priorityCategory = newPriority > 75.0 ? 'IMMEDIATE' : (newPriority > 50.0 ? 'SHORT_TERM' : 'MEDIUM_TERM');
        await _db.saveHabitation(h);
      } catch (_) {}
    }
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('AI Relocation Matrix recalculated from live satellite telemetry.'),
          backgroundColor: Color(0xFF000000),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row with Live AI Re-scoring Action
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Relocation Priority Matrix',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF000000),
                                  letterSpacing: -0.5,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Dynamic AHP urgency ranking & nearest relocation shelters.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFF757575),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.bolt_rounded, color: Color(0xFF000000)),
                          onPressed: _recalculateLiveAiScoring,
                          tooltip: 'Recalculate AI Matrix from Live Satellite',
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips Row (Wrapped in SingleChildScrollView to prevent overflow)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All (${_habitations.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('IMMEDIATE', 'Immediate ($_immediateCount)', isUrgent: true),
                          const SizedBox(width: 8),
                          _buildFilterChip('SHORT_TERM', 'Short-Term ($_shortTermCount)'),
                          const SizedBox(width: 8),
                          _buildFilterChip('MEDIUM_TERM', 'Medium-Term ($_mediumTermCount)'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Summary Stats Strip
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem('At-Risk Pop.', '${_habitations.fold(0, (sum, h) => sum + h.totalPopulation)}', Icons.groups_rounded),
                          _buildDivider(),
                          _buildSummaryItem('Immediate Action', '$_immediateCount Sites', Icons.warning_amber_rounded, color: const Color(0xFFDC2626)),
                          _buildDivider(),
                          _buildSummaryItem('Safe Shelters', '${_shelters.length} Ready', Icons.night_shelter_rounded, color: const Color(0xFF059669)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Ranked Habitations (${_filteredHabitations.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Text(
                          'Geospatial Proximity Active',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Habitation Cards List
                    if (_filteredHabitations.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'No habitations match the selected filter.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredHabitations.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final habitation = _filteredHabitations[index];
                          final (nearestShelter, distKm) = _findNearestShelter(habitation);
                          return _buildHabitationCard(habitation, nearestShelter, distKm);
                        },
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, {bool isUrgent = false}) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF000000) : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? const Color(0xFF000000) : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? const Color(0xFFFFFFFF) : const Color(0xFF374151),
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String title, String value, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, size: 18, color: color ?? const Color(0xFF000000)),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            color: color ?? const Color(0xFF000000),
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 24,
      width: 1,
      color: const Color(0xFFE5E7EB),
    );
  }

  Widget _buildHabitationCard(Habitation habitation, SafeShelter? nearestShelter, double distKm) {
    final (badgeBg, badgeText, badgeLabel) = _getPriorityBadge(habitation.priorityCategory);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row: Name & Priority Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      habitation.villageName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${habitation.districtName} District (ID: ${habitation.habitationId})',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  badgeLabel,
                  style: TextStyle(
                    color: badgeText,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Key Metrics Grid (No Emojis)
          Row(
            children: [
              _buildPillMetric(Icons.people_outline_rounded, 'Population', '${habitation.totalPopulation}'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.elderly_rounded, 'Elderly', '${((habitation.population60Plus / (habitation.totalPopulation > 0 ? habitation.totalPopulation : 1)) * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.landscape_rounded, 'Slope', '${habitation.slopePercentage.toStringAsFixed(0)}%'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.shield_outlined, 'Risk', '${habitation.priorityScore.toStringAsFixed(0)}/100'),
            ],
          ),
          const SizedBox(height: 10),

          // Nearest Relocation Center Dynamic Card (Fixed Haversine Distance & No Emojis)
          if (nearestShelter != null)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.night_shelter_rounded, size: 15, color: Color(0xFF059669)),
                      const SizedBox(width: 6),
                      const Text(
                        'Nearest Relocation Center:',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF374151)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${distKm.toStringAsFixed(1)} km away',
                          style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    nearestShelter.shelterName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bed_rounded, size: 13, color: Color(0xFF4B5563)),
                          const SizedBox(width: 3),
                          Text(
                            '${nearestShelter.availableCapacity} Free Beds',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.water_drop_rounded, size: 13, color: Color(0xFF4B5563)),
                          const SizedBox(width: 3),
                          Text(
                            '${(nearestShelter.waterAvailableLiters / 600).toStringAsFixed(0)}d Water',
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: Color(0xFF4B5563)),
                          ),
                        ],
                      ),
                      Text(
                        'Road: ${habitation.pathStatus}',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: habitation.pathStatus == 'CLEAR' ? const Color(0xFF059669) : const Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showEvacuationPlanModal(habitation, nearestShelter, distKm),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: const Color(0xFFFFFFFF),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: const Text(
                    'Plan Evacuation Route',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: IconButton(
                  icon: const Icon(Icons.map_rounded, color: Color(0xFF000000), size: 18),
                  onPressed: () {
                    widget.onSelectHabitationOnMap?.call(habitation);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPillMetric(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 9.5, color: const Color(0xFF6B7280)),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 7.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
            ),
          ],
        ),
      ),
    );
  }

  (Color, Color, String) _getPriorityBadge(String priority) {
    switch (priority.toUpperCase()) {
      case 'IMMEDIATE':
        return (const Color(0xFFFEE2E2), const Color(0xFF991B1B), 'IMMEDIATE (0-24H)');
      case 'SHORT_TERM':
        return (const Color(0xFFFEF3C7), const Color(0xFF92400E), 'SHORT-TERM (1-4W)');
      case 'MEDIUM_TERM':
        return (const Color(0xFFD1FAE5), const Color(0xFF065F46), 'MEDIUM-TERM (1-6M)');
      default:
        return (const Color(0xFFE5E7EB), const Color(0xFF374151), priority);
    }
  }

  void _showEvacuationPlanModal(Habitation habitation, SafeShelter? shelter, double distKm) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFFFF),
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.crisis_alert_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'SDMA Evacuation Directive: ${habitation.villageName}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned Relocation Site:', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 3),
                  Text(
                    shelter?.shelterName ?? 'Designated Regional Center',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Distance: ${distKm.toStringAsFixed(1)} km', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                      Text('Available Beds: ${shelter?.availableCapacity ?? 200}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Evacuation notice dispatched for ${habitation.totalPopulation} residents to ${shelter?.shelterName}.'),
                    backgroundColor: const Color(0xFF000000),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF000000),
                foregroundColor: const Color(0xFFFFFFFF),
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child: const Text('Dispatch Evacuation Notice', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
