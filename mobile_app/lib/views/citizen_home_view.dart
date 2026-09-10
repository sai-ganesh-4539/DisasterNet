import 'package:field_app/services/alerts_store.dart';
import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:field_app/views/alerts_view.dart';
import 'package:field_app/views/crowd_report_view.dart';
import 'package:field_app/views/layered_gis_map_view.dart';
import 'package:field_app/views/sos_view.dart';
import 'package:flutter/material.dart';

/// Citizen-facing home shell — 4-tab bottom navigation tailored to
/// citizen needs:
///   0. Home (overview + alerts ticker)
///   1. Map (layered GIS map with red zones, shelters, SOS, alerts)
///   2. SOS (emergency SOS dispatch with 3-layer fallback)
///   3. Report (crowd-sourced damage report)
class CitizenHomeView extends StatefulWidget {
  const CitizenHomeView({super.key});

  @override
  State<CitizenHomeView> createState() => _CitizenHomeViewState();
}

class _CitizenHomeViewState extends State<CitizenHomeView> {
  final AuthService _authService = AuthService.instance;
  final LiveGisStore _gisStore = LiveGisStore.instance;
  final AlertsStore _alertsStore = AlertsStore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _gisStore.addListener(_onChange);
    _alertsStore.addListener(_onChange);
    _gisStore.initializeAndRefresh();
    _alertsStore.initialize();
  }

  @override
  void dispose() {
    _gisStore.removeListener(_onChange);
    _alertsStore.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _getCurrentScreen(),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return PreferredSize(
      preferredSize: const Size.fromHeight(56),
      child: Container(
        color: const Color(0xFFFFFFFF),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.account_circle_rounded, color: Color(0xFF000000), size: 28),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('DisasterNet',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                      Text(
                        'Citizen • ${_authService.username}',
                        style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _alertsStore.hasAlerts ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _alertsStore.hasAlerts ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _alertsStore.hasAlerts ? '${_alertsStore.alerts.length} LIVE ALERTS' : 'NO ACTIVE ALERTS',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: _alertsStore.hasAlerts ? const Color(0xFFDC2626) : const Color(0xFF059669),
            ),
          ),
        ],
      ),
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return const LayeredGisMapView();
      case 2:
        return const SosView();
      case 3:
        return const CrowdReportView();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
    final redZoneCount = _gisStore.zones.length;
    final shelterCount = _gisStore.shelters.length;
    final habitationCount = _gisStore.habitations.length;
    final topAlerts = _alertsStore.topAlerts;

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      drawer: _buildDrawer(),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await _gisStore.refreshFromLocationOrIndia();
            await _alertsStore.refresh();
          },
          color: Colors.black,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Hero SOS card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF000000),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _alertsStore.hasAlerts ? const Color(0xFFDC2626) : const Color(0xFF059669),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _alertsStore.hasAlerts ? Icons.warning_amber_rounded : Icons.check_circle_outline_rounded,
                                  color: Colors.white,
                                  size: 12,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _alertsStore.hasAlerts ? 'ALERTS ACTIVE' : 'NO ACTIVE ALERTS',
                                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.w800),
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _alertsStore.fromCache ? 'cached' : 'live',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 10, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'In an emergency, tap SOS',
                        style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SOS will use 3 fallback layers (server → mesh → SMS) to ensure your message reaches responders even without internet.',
                        style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 11.5, height: 1.4),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => setState(() => _currentIndex = 2),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crisis_alert_rounded, size: 18),
                              SizedBox(width: 6),
                              Text('SEND SOS NOW', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                // Quick stats
                Row(
                  children: [
                    _statCard('Red Zones', '$redZoneCount', Icons.layers_rounded, const Color(0xFFDC2626), () => setState(() => _currentIndex = 1)),
                    const SizedBox(width: 10),
                    _statCard('Shelters', '$shelterCount', Icons.night_shelter_rounded, const Color(0xFF059669), () => setState(() => _currentIndex = 1)),
                    const SizedBox(width: 10),
                    _statCard('Habitations', '$habitationCount', Icons.home_rounded, const Color(0xFFD97706), () => setState(() => _currentIndex = 1)),
                  ],
                ),
                const SizedBox(height: 22),
                // Live alerts ticker
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Live Official Alerts',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                    GestureDetector(
                      onTap: () => setState(() => _currentIndex = 0),
                      child: const Text('View all', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (topAlerts.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _alertsStore.loading ? 'Fetching live alerts...' : 'No active alerts nearby',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ),
                  )
                else
                  ...topAlerts.take(5).map((alert) => _buildAlertRow(alert)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 6),
              Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
              const SizedBox(height: 1),
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertRow(Map<String, dynamic> alert) {
    final source = alert['source']?.toString() ?? 'ALERT';
    final title = alert['title']?.toString() ?? 'Untitled alert';
    final color = _sourceColor(source);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: color, width: 3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
              child: Text(source, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF374151)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _sourceColor(String source) {
    switch (source.toUpperCase()) {
      case 'USGS': return const Color(0xFFDC2626);
      case 'NASA_EONET': return const Color(0xFF7C3AED);
      case 'IMD': return const Color(0xFF0EA5E9);
      case 'NDMA': return const Color(0xFFD97706);
      default: return const Color(0xFF6B7280);
    }
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: const BoxDecoration(color: Color(0xFF000000)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.person, color: Colors.black, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _authService.username,
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Citizen • ${_authService.role}',
                            style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                ListTile(
                  leading: const Icon(Icons.home_rounded, color: Color(0xFF000000)),
                  title: const Text('Home', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 0);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.map_rounded, color: Color(0xFF000000)),
                  title: const Text('Live Map', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.crisis_alert_rounded, color: Color(0xFFDC2626)),
                  title: const Text('Emergency SOS', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 2);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.report_problem_rounded, color: Color(0xFF000000)),
                  title: const Text('Report Damage', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _currentIndex = 3);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_rounded, color: Color(0xFF000000)),
                  title: const Text('View All Alerts', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AlertsView()));
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFF000000)),
                  title: const Text('Sign Out', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _authService.logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.map_outlined, Icons.map_rounded, 'Map'),
              _buildNavItem(2, Icons.crisis_alert_outlined, Icons.crisis_alert_rounded, 'SOS'),
              _buildNavItem(3, Icons.report_outlined, Icons.report_rounded, 'Report'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;
    return InkWell(
      onTap: () => setState(() => _currentIndex = index),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: isSelected ? const Color(0xFF000000) : const Color(0xFF9CA3AF),
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? const Color(0xFF000000) : const Color(0xFF6B7280),
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
