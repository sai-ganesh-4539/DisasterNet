import 'package:flutter/material.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/models/hazard_zone.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  static const String route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService _db = DatabaseService();
  List<Habitation> _habitations = [];
  List<SafeShelter> _shelters = [];
  List<HazardZone> _zones = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final habitations = await _db.getAllHabitations();
    final shelters = await _db.getAllSafeShelters();
    final zones = await _db.getAllHazardZones();

    if (mounted) {
      setState(() {
        _habitations = habitations;
        _shelters = shelters;
        _zones = zones;
        _isLoading = false;
      });
    }
  }

  int get _immediateHabitations => _habitations.where((h) => h.priorityCategory == 'IMMEDIATE').length;
  int get _activeRedZones => _zones.where((z) => z.isRedZone).length;
  int get _availableBeds => _shelters.fold(0, (sum, s) => sum + s.availableCapacity);

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
                    // Top Branding Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'DisasterNet',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[500],
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 3),
                            const Text(
                              'SDMA Command HUD',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF000000),
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF3F4F6),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFF000000), size: 22),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // IMD Live Multi-Hazard Red Zone Alert Banner (No Emojis, No Em-Dashes)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF000000),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                                    SizedBox(width: 4),
                                    Text(
                                      'IMD RED ALERT',
                                      style: TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                    ),
                                  ],
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Real-Time IMD Telemetry',
                                style: TextStyle(color: Colors.grey[400], fontSize: 10.5, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Severe Rainfall & Inundation: East Coast & Central Basins',
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'Active Red Zones across Odisha, Chhattisgarh, Gangetic West Bengal, and North Andhra Pradesh coasts. Squally winds 50 kmph and isolated extremely heavy rainfall active.',
                            style: TextStyle(
                              color: Colors.grey[300],
                              fontSize: 11.5,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => widget.onNavigateToTab?.call(1),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFFFFF),
                                foregroundColor: const Color(0xFF000000),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(vertical: 11),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('View Active Red Zones on Map', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                  SizedBox(width: 6),
                                  Icon(Icons.arrow_forward_rounded, size: 15),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Proactive Overview Header
                    const Text(
                      'National Relocation Overview',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2 Key Metric Cards
                    Row(
                      children: [
                        _buildMetricCard(
                          title: 'Immediate Evacuations',
                          value: '$_immediateHabitations Sites',
                          subtitle: '0-24h Critical Window',
                          color: const Color(0xFFDC2626),
                          icon: Icons.crisis_alert_rounded,
                          onTap: () => widget.onNavigateToTab?.call(2),
                        ),
                        const SizedBox(width: 10),
                        _buildMetricCard(
                          title: 'Active Red Zones',
                          value: '$_activeRedZones Zones',
                          subtitle: 'IMD Multi-Hazard Grids',
                          color: const Color(0xFFD97706),
                          icon: Icons.layers_rounded,
                          onTap: () => widget.onNavigateToTab?.call(1),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Shelter Capacity Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.night_shelter_rounded, color: Color(0xFF059669), size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Relocation Shelter Capacity',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$_availableBeds safe beds ready across ${_shelters.length} sites',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () => widget.onNavigateToTab?.call(3),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              foregroundColor: const Color(0xFFFFFFFF),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            child: const Text('Audit', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Decision Support Modules
                    const Text(
                      'Decision Support Modules',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 10),

                    _buildActionTile(
                      icon: Icons.map_rounded,
                      title: 'GIS Multi-Hazard Map HUD',
                      subtitle: 'Real-time IMD Red Zones, live weather and tap to inspect',
                      onTap: () => widget.onNavigateToTab?.call(1),
                    ),
                    const SizedBox(height: 8),

                    _buildActionTile(
                      icon: Icons.format_list_bulleted_rounded,
                      title: 'Time-Horizon Relocation Matrix',
                      subtitle: 'Prioritize Immediate (0-24h), Short-term (1-4w), Medium-term',
                      onTap: () => widget.onNavigateToTab?.call(2),
                    ),
                    const SizedBox(height: 8),

                    _buildActionTile(
                      icon: Icons.inventory_2_rounded,
                      title: 'Shelter Carrying Capacity Evaluator',
                      subtitle: 'Multi-resource bottleneck analysis for water, food, and beds',
                      onTap: () => widget.onNavigateToTab?.call(3),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF000000),
                ),
              ),
              const SizedBox(height: 1),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF111827),
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1.2),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF000000), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
