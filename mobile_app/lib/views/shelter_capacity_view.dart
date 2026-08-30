import 'package:flutter/material.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/core/database.dart';

class ShelterCapacityView extends StatefulWidget {
  final Function(SafeShelter)? onSelectShelterOnMap;

  const ShelterCapacityView({super.key, this.onSelectShelterOnMap});

  @override
  State<ShelterCapacityView> createState() => _ShelterCapacityViewState();
}

class _ShelterCapacityViewState extends State<ShelterCapacityView> {
  final DatabaseService _db = DatabaseService();
  List<SafeShelter> _shelters = [];
  String _selectedFilter = 'ALL'; // ALL, AVAILABLE, CRITICAL
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadShelters();
  }

  Future<void> _loadShelters() async {
    setState(() => _isLoading = true);
    final shelters = await _db.getAllSafeShelters();
    setState(() {
      _shelters = shelters;
      _isLoading = false;
    });
  }

  List<SafeShelter> get _filteredShelters {
    if (_selectedFilter == 'ALL') return _shelters;
    if (_selectedFilter == 'AVAILABLE') return _shelters.where((s) => s.availableCapacity > 100).toList();
    if (_selectedFilter == 'CRITICAL') return _shelters.where((s) => s.capacityStatus == 'CRITICAL' || s.availableCapacity < 50).toList();
    return _shelters;
  }

  int get _totalCapacity => _shelters.fold(0, (sum, s) => sum + s.totalCapacity);
  int get _totalOccupancy => _shelters.fold(0, (sum, s) => sum + s.currentPopulation);
  int get _totalAvailable => _shelters.fold(0, (sum, s) => sum + s.availableCapacity);

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
                    // Screen Title
                    const Text(
                      'Shelter Carrying Capacity',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Multi-resource bottleneck assessment & real-time logistics auditing.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF757575),
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Filter Chips Row (Wrapped in SingleChildScrollView to prevent 67px overflow)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip('ALL', 'All Shelters (${_shelters.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip('AVAILABLE', 'High Space'),
                          const SizedBox(width: 8),
                          _buildFilterChip('CRITICAL', 'Bottlenecked'),
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
                          _buildSummaryItem('Total Beds', '$_totalCapacity', Icons.night_shelter_rounded),
                          _buildDivider(),
                          _buildSummaryItem('Occupied', '$_totalOccupancy', Icons.people_outline_rounded, color: const Color(0xFF4B5563)),
                          _buildDivider(),
                          _buildSummaryItem('Available', '$_totalAvailable', Icons.check_circle_outline_rounded, color: const Color(0xFF059669)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section Heading
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Safer Relocation Sites (${_filteredShelters.length})',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF000000),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFECFDF5),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified_user_rounded, size: 11, color: Color(0xFF059669)),
                              SizedBox(width: 4),
                              Text('100% Safe Zone', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // List of Shelters
                    if (_filteredShelters.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(32),
                        alignment: Alignment.center,
                        child: Text(
                          'No shelters match the filter.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _filteredShelters.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final shelter = _filteredShelters[index];
                          return _buildShelterCard(shelter);
                        },
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
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

  Widget _buildShelterCard(SafeShelter shelter) {
    final occupancyPct = (shelter.currentPopulation / (shelter.totalCapacity > 0 ? shelter.totalCapacity : 1)).clamp(0.0, 1.0);
    final pop = shelter.currentPopulation > 0 ? shelter.currentPopulation : 100;
    final waterDays = (shelter.waterAvailableLiters / (pop * 15)).clamp(1.0, 45.0);
    final foodDays = (shelter.foodAvailableKg / (pop * 0.5)).clamp(1.0, 45.0);

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
          // Header: Name and Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      shelter.shelterName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${shelter.shelterType} • ${shelter.districtName} • Buffer: ${shelter.safetyBufferKm}km',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              _buildConstraintBadge(shelter.capacityConstraint),
            ],
          ),
          const SizedBox(height: 12),

          // Bed Capacity Bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Bed Capacity', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF374151))),
                  Text(
                    '${shelter.currentPopulation} / ${shelter.totalCapacity} occupied (${shelter.availableCapacity} beds left)',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: occupancyPct > 0.8 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: occupancyPct,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFE5E7EB),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    occupancyPct > 0.85 ? const Color(0xFFDC2626) : (occupancyPct > 0.6 ? const Color(0xFFD97706) : const Color(0xFF059669)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Multi-Resource Gauges Row (No Emojis)
          Row(
            children: [
              _buildResourceMeter(Icons.water_drop_rounded, 'Potable Water', '${waterDays.toStringAsFixed(0)} Days', waterDays > 7),
              const SizedBox(width: 6),
              _buildResourceMeter(Icons.restaurant_rounded, 'Food Rations', '${foodDays.toStringAsFixed(0)} Days', foodDays > 7),
              const SizedBox(width: 6),
              _buildResourceMeter(Icons.medical_services_rounded, 'Medical Tier', shelter.hasMedicalFacility ? 'Triage Post' : 'Basic Kits', shelter.hasMedicalFacility),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _showAuditAndRestockModal(shelter),
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
                    'Audit and Restock Supplies',
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
                    widget.onSelectShelterOnMap?.call(shelter);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConstraintBadge(String constraint) {
    Color bg = const Color(0xFFECFDF5);
    Color text = const Color(0xFF059669);
    String label = 'OPTIMAL';

    if (constraint == 'WATER') {
      bg = const Color(0xFFEFF6FF);
      text = const Color(0xFF1D4ED8);
      label = 'WATER LIMITED';
    } else if (constraint == 'FOOD') {
      bg = const Color(0xFFFFFBEB);
      text = const Color(0xFFB45309);
      label = 'FOOD LIMITED';
    } else if (constraint == 'SPACE') {
      bg = const Color(0xFFFEF2F2);
      text = const Color(0xFFB91C1C);
      label = 'SPACE LIMITED';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(color: text, fontSize: 9, fontWeight: FontWeight.w800),
      ),
    );
  }

  Widget _buildResourceMeter(IconData icon, String label, String value, bool isHealthy) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
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
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: isHealthy ? const Color(0xFF111827) : const Color(0xFFDC2626),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAuditAndRestockModal(SafeShelter shelter) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
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
                Text(
                  'Audit and Restock: ${shelter.shelterName}',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // Interactive Quick Actions to Restock (No Emojis)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.water_drop_rounded, size: 14, color: Color(0xFF1D4ED8)),
                              const SizedBox(width: 4),
                              Text('Water: ${shelter.waterAvailableLiters} Liters', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                shelter.waterAvailableLiters += 5000;
                              });
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('+5,000L', style: TextStyle(fontSize: 10.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.restaurant_rounded, size: 14, color: Color(0xFFB45309)),
                              const SizedBox(width: 4),
                              Text('Food: ${shelter.foodAvailableKg} Kilograms', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () {
                              setModalState(() {
                                shelter.foodAvailableKg += 1000;
                              });
                              setState(() {});
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('+1,000kg', style: TextStyle(fontSize: 10.5)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.bed_rounded, size: 14, color: Color(0xFF059669)),
                              const SizedBox(width: 4),
                              Text('Occupants: ${shelter.currentPopulation} / ${shelter.totalCapacity}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                                onPressed: shelter.currentPopulation > 0
                                    ? () {
                                        setModalState(() {
                                          shelter.currentPopulation -= 20;
                                          shelter.availableCapacity += 20;
                                        });
                                        setState(() {});
                                      }
                                    : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                                onPressed: shelter.availableCapacity > 0
                                    ? () {
                                        setModalState(() {
                                          shelter.currentPopulation += 20;
                                          shelter.availableCapacity -= 20;
                                        });
                                        setState(() {});
                                      }
                                    : null,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () async {
                    await _db.saveSafeShelter(shelter);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Shelter inventory and carrying capacity updated in database.'),
                        backgroundColor: Color(0xFF000000),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: const Color(0xFFFFFFFF),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Save Audit and Log Restock', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }
}
