import 'package:field_app/services/live_gis_store.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateToTab;

  const HomeScreen({super.key, this.onNavigateToTab});

  static const String route = '/home';

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final LiveGisStore _store = LiveGisStore.instance;

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

  @override
  Widget build(BuildContext context) {
    final redZoneCount = (_store.summary['red_zone_count'] as num?)?.toInt() ?? _store.zones.length;
    final immediateCount = (_store.summary['immediate_count'] as num?)?.toInt() ??
        _store.habitations.where((h) => h.priorityCategory == 'IMMEDIATE').length;
    final immediatePopulation = (_store.summary['population_immediate'] as num?)?.toInt() ??
        _store.habitations
            .where((h) => h.priorityCategory == 'IMMEDIATE')
            .fold<int>(0, (sum, h) => sum + h.totalPopulation);
    final availableBeds = (_store.summary['available_beds'] as num?)?.toInt() ??
        _store.shelters.fold<int>(0, (sum, s) => sum + s.availableCapacity);
    final totalCapacity = _store.shelters.fold<int>(0, (sum, s) => sum + s.totalCapacity);
    final alertHeadline = (_store.alert['headline'] as String?)?.trim();
    final alertDetail = (_store.alert['detail'] as String?)?.trim();

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      body: SafeArea(
        child: _store.loading && !_store.hasLiveData
            ? const Center(child: CircularProgressIndicator(color: Colors.black))
            : RefreshIndicator(
                onRefresh: _refresh,
                color: Colors.black,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                          IconButton(
                            icon: _store.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                                  )
                                : const Icon(Icons.refresh_rounded, color: Color(0xFF000000), size: 22),
                            onPressed: _store.loading ? null : _refresh,
                            tooltip: 'Refresh command HUD',
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF000000),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
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
                                    color: redZoneCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF059669),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        redZoneCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        redZoneCount > 0 ? 'ACTIVE RED ZONES' : 'NO RED ZONES IN VIEW',
                                        style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  _store.isDemoScenarioMode
                                      ? 'demo scenario snapshot'
                                      : _store.cacheHit
                                          ? 'cached live snapshot'
                                          : 'fresh live snapshot',
                                  style: TextStyle(color: Colors.grey[400], fontSize: 10.5, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              alertHeadline?.isNotEmpty == true
                                  ? alertHeadline!
                                  : _store.isDemoScenarioMode
                                      ? 'Scenario operations active'
                                      : 'Operational monitoring active',
                              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              alertDetail?.isNotEmpty == true
                                  ? alertDetail!
                                  : _store.isDemoScenarioMode
                                      ? 'This demonstration is running on a curated scenario snapshot for stable judging output.'
                                      : 'Pull to refresh the current viewport and rebuild the relocation decision snapshot.',
                              style: TextStyle(color: Colors.grey[300], fontSize: 11.5, height: 1.35),
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(_store.isDemoScenarioMode ? 'View scenario red zones on map' : 'View live red zones on map', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.arrow_forward_rounded, size: 15),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      const Text(
                        'Operational Overview',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _buildMetricCard(
                            title: 'Immediate Relocations',
                            value: '$immediateCount Sites',
                            subtitle: '$immediatePopulation people in 0-24h window',
                            color: const Color(0xFFDC2626),
                            icon: Icons.crisis_alert_rounded,
                            onTap: () => widget.onNavigateToTab?.call(2),
                          ),
                          const SizedBox(width: 10),
                          _buildMetricCard(
                            title: 'Active Red Zones',
                            value: '$redZoneCount Zones',
                            subtitle: '${_store.zones.length} mapped polygons in cache',
                            color: const Color(0xFFD97706),
                            icon: Icons.layers_rounded,
                            onTap: () => widget.onNavigateToTab?.call(1),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
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
                                    'Shelter carrying capacity',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827)),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$availableBeds available beds out of $totalCapacity across ${_store.shelters.length} live sites',
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
                      const Text(
                        'Live Decision Inputs',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000)),
                      ),
                      const SizedBox(height: 10),
                      ..._store.dataSources.entries.take(4).map(
                            (entry) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _buildActionTile(
                                icon: Icons.data_thresholding_rounded,
                                title: entry.key,
                                subtitle: entry.value.toString(),
                                onTap: () {},
                              ),
                            ),
                          ),
                      if (_store.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Last refresh error: ${_store.error}',
                          style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ),
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
                color: Colors.black.withValues(alpha: 0.03),
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
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 10),
              Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
              const SizedBox(height: 1),
              Text(title, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280), height: 1.3)),
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
    return GestureDetector(
      onTap: onTap,
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
              decoration: BoxDecoration(color: const Color(0xFFF3F4F6), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF111827), size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.3)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
