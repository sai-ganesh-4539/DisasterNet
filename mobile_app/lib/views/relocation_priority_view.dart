import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

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
  final LiveGisStore _store = LiveGisStore.instance;
  final Distance _distance = const Distance();
  String _selectedFilter = 'ALL';

  @override
  void initState() {
    super.initState();
    _store.addListener(_onStoreChanged);
    _store.initializeAndRefresh();
  }

  @override
  void dispose() {
    _store.removeListener(_onStoreChanged);
    super.dispose();
  }

  void _onStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _refresh() => _store.refreshFromLocationOrIndia();

  List<Habitation> get _habitations => List<Habitation>.from(_store.habitations)
    ..sort((a, b) => b.priorityScore.compareTo(a.priorityScore));

  List<Habitation> get _filteredHabitations {
    if (_selectedFilter == 'ALL') return _habitations;
    return _habitations.where((h) => h.priorityCategory.toUpperCase() == _selectedFilter).toList();
  }

  int get _immediateCount => _habitations.where((h) => h.priorityCategory == 'IMMEDIATE').length;
  int get _shortTermCount => _habitations.where((h) => h.priorityCategory == 'SHORT_TERM').length;
  int get _mediumTermCount => _habitations.where((h) => h.priorityCategory == 'MEDIUM_TERM').length;

  (SafeShelter?, double) _findNearestShelter(Habitation habitation) {
    if (_store.shelters.isEmpty) return (null, 0.0);
    SafeShelter? bestShelter;
    var minDistance = double.infinity;
    for (final shelter in _store.shelters) {
      final dist = _distance.as(
        LengthUnit.Kilometer,
        LatLng(habitation.latitude, habitation.longitude),
        LatLng(shelter.latitude, shelter.longitude),
      );
      if (dist < minDistance) {
        minDistance = dist;
        bestShelter = shelter;
      }
    }
    return (bestShelter, minDistance);
  }

  @override
  Widget build(BuildContext context) {
    final totalPopulation = _habitations.fold(0, (sum, h) => sum + h.totalPopulation);
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _store.loading && _habitations.isEmpty
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
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Relocation Priority Matrix',
                                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Live habitation ranking from hazard exposure, vulnerability, and access limitations.',
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
                            tooltip: 'Refresh live ranking',
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
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
                            _buildSummaryItem('At-Risk Pop.', '$totalPopulation', Icons.groups_rounded),
                            _buildDivider(),
                            _buildSummaryItem('Immediate', '$_immediateCount Sites', Icons.warning_amber_rounded, color: const Color(0xFFDC2626)),
                            _buildDivider(),
                            _buildSummaryItem('Safe Shelters', '${_store.shelters.where((s) => s.isInSafeZone).length}', Icons.night_shelter_rounded, color: const Color(0xFF059669)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Ranked Habitations (${_filteredHabitations.length})',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF000000)),
                          ),
                          Text(
                            _store.cacheHit ? 'cached snapshot' : 'fresh snapshot',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (_filteredHabitations.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(32),
                          alignment: Alignment.center,
                          child: Text('No habitations match the selected filter.', style: TextStyle(color: Colors.grey[600])),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _filteredHabitations.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 14),
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
          border: Border.all(color: isSelected ? const Color(0xFF000000) : const Color(0xFFE5E7EB)),
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
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color ?? const Color(0xFF000000))),
        Text(title, style: const TextStyle(fontSize: 9.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500)),
      ],
    );
  }

  Widget _buildDivider() => Container(height: 24, width: 1, color: const Color(0xFFE5E7EB));

  Widget _buildHabitationCard(Habitation habitation, SafeShelter? nearestShelter, double distKm) {
    final (badgeBg, badgeText, badgeLabel) = _getPriorityBadge(habitation.priorityCategory);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 3))],
      ),
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
                    Text(habitation.villageName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                    const SizedBox(height: 2),
                    Text(
                      '${habitation.districtName} • ${habitation.stateCode} • ${habitation.proximityToHazardKm.toStringAsFixed(1)} km from nearest red zone',
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(16)),
                child: Text(badgeLabel, style: TextStyle(color: badgeText, fontSize: 9.5, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildPillMetric(Icons.people_outline_rounded, 'Population', '${habitation.totalPopulation}'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.elderly_rounded, 'Elderly', '${((habitation.population60Plus / (habitation.totalPopulation == 0 ? 1 : habitation.totalPopulation)) * 100).toStringAsFixed(0)}%'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.landscape_rounded, 'Slope', '${habitation.slopePercentage.toStringAsFixed(0)}%'),
              const SizedBox(width: 6),
              _buildPillMetric(Icons.shield_outlined, 'Priority', '${habitation.priorityScore.toStringAsFixed(0)}/100'),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFE5E7EB))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Road status: ${habitation.pathStatus}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: habitation.pathStatus == 'CLEAR' ? const Color(0xFF059669) : const Color(0xFFDC2626))),
                const SizedBox(height: 4),
                Text('Nearest shelter: ${nearestShelter?.shelterName ?? 'No live candidate in view'}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(
                  nearestShelter == null
                      ? 'Expand the map viewport or refresh near this habitation to discover more candidate sites.'
                      : '${distKm.toStringAsFixed(1)} km away • ${nearestShelter.availableCapacity} available beds • ${nearestShelter.capacityConstraint} constraint',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF4B5563)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Plan Evacuation Route', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(30)),
                child: IconButton(
                  icon: const Icon(Icons.map_rounded, color: Color(0xFF000000), size: 18),
                  onPressed: () => widget.onSelectHabitationOnMap?.call(habitation),
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
        decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(8), border: Border.all(color: const Color(0xFFE5E7EB))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 9.5, color: const Color(0xFF6B7280)),
                const SizedBox(width: 2),
                Expanded(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600))),
              ],
            ),
            const SizedBox(height: 2),
            Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
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
        decoration: const BoxDecoration(color: Color(0xFFFFFFFF), borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(
              children: [
                const Icon(Icons.crisis_alert_rounded, color: Color(0xFFDC2626), size: 24),
                const SizedBox(width: 10),
                Expanded(child: Text('Relocation plan: ${habitation.villageName}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: const Color(0xFFF9FAFB), borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE5E7EB))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Assigned relocation site', style: TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
                  const SizedBox(height: 3),
                  Text(shelter?.shelterName ?? 'No candidate shelter in current live view', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Distance: ${distKm.toStringAsFixed(1)} km', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                  Text('Available beds: ${shelter?.availableCapacity ?? 0}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                ],
              ),
            ),
            const SizedBox(height: 18),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      shelter == null
                          ? 'No live relocation site is currently available in this viewport. Refresh the map closer to the habitation.'
                          : 'Evacuation plan prepared for ${habitation.totalPopulation} residents to ${shelter.shelterName}.',
                    ),
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
              child: const Text('Acknowledge Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
