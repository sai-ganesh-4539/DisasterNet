import 'package:flutter/material.dart';
import 'package:field_app/views/home_screen.dart';
import 'package:field_app/views/map_hud_view.dart';
import 'package:field_app/views/relocation_priority_view.dart';
import 'package:field_app/views/shelter_capacity_view.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  int _currentIndex = 0; // Default to Home
  bool _isOnline = true;
  final Connectivity _connectivity = Connectivity();

  // User Context
  static const String _officerName = 'SDMA Field Officer';
  static const String _rbacRole = 'INCIDENT_COMMANDER';
  String _deviceHash = 'SEC-8921';

  // Navigation targets from other screens
  Habitation? _mapTargetHabitation;
  SafeShelter? _mapTargetShelter;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final result = await _connectivity.checkConnectivity();
      setState(() => _isOnline = result != ConnectivityResult.none);
      _connectivity.onConnectivityChanged.listen((result) {
        if (mounted) {
          setState(() => _isOnline = result != ConnectivityResult.none);
        }
      });

      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) {
        setState(() {
          _deviceHash = androidInfo.id.substring(0, 8).toUpperCase();
        });
      }
    } catch (_) {}
  }

  void _navigateToMapWithHabitation(Habitation habitation) {
    setState(() {
      _mapTargetHabitation = habitation;
      _mapTargetShelter = null;
      _currentIndex = 1; // Map tab
    });
  }

  void _navigateToMapWithShelter(SafeShelter shelter) {
    setState(() {
      _mapTargetShelter = shelter;
      _mapTargetHabitation = null;
      _currentIndex = 1; // Map tab
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _getCurrentScreen(),
      bottomNavigationBar: _buildBottomNavigationBar(),
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
                // Hamburger Menu
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF000000), size: 24),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),

                // App Name
                const Expanded(
                  child: Text(
                    'DisasterNet',
                    style: TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),

                // Live Online Beacon
                _buildStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _isOnline ? const Color(0xFFECFDF5) : const Color(0xFFF3F4F6),
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
              color: _isOnline ? const Color(0xFF059669) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _isOnline ? 'AI LIVE' : 'OFFLINE',
            style: TextStyle(
              color: _isOnline ? const Color(0xFF059669) : const Color(0xFF4B5563),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFFFFFFFF),
      child: Column(
        children: [
          // Drawer Header matching Mockup
          Container(
            padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
            decoration: const BoxDecoration(
              color: Color(0xFF000000),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded, color: Color(0xFF000000), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            _officerName,
                            style: TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Node: $_deviceHash',
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 11,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    _rbacRole,
                    style: TextStyle(
                      color: Color(0xFF93C5FD),
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation List
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(0, Icons.home_rounded, 'Command Dashboard'),
                _buildDrawerItem(1, Icons.map_rounded, 'Live GIS Red Zone Map'),
                _buildDrawerItem(2, Icons.crisis_alert_rounded, 'Relocation Priority Matrix'),
                _buildDrawerItem(3, Icons.night_shelter_rounded, 'Shelter Carrying Capacity'),
                const Divider(color: Color(0xFFE5E7EB), height: 24),
                ListTile(
                  leading: const Icon(Icons.cloud_download_rounded, color: Color(0xFF000000)),
                  title: const Text('Manual Offline Sync', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Offline delta package synchronized successfully.'),
                        backgroundColor: Color(0xFF000000),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Settings Bottom Row (Interactive SDMA Settings Modal)
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _showSdmaSettingsModal();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_rounded, color: Color(0xFF000000), size: 20),
                  const SizedBox(width: 12),
                  const Text('SDMA Settings', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Text('v2.4.0', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSdmaSettingsModal() {
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
                const Text(
                  'SDMA System Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),

                // Telemetry Feed Setting
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.satellite_alt_rounded, size: 16, color: Color(0xFF000000)),
                          SizedBox(width: 8),
                          Text('Meteorological Telemetry Feed', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('Active: IMD Real-Time Satellite Ingestion & GFS Ensemble (3-hour refresh cycle)', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Red Alert Threshold Trigger
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                          SizedBox(width: 8),
                          Text('Red Alert Rainfall Threshold', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text('Automatic Red Zone Trigger: > 65.0 mm / 24h (National NDMA Standard)', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Device & Cache Diagnostics
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Offline Spatial Cache', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('Status: 100% Synced (Node $_deviceHash)', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                        ],
                      ),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Offline map cache refreshed and verified.'),
                              backgroundColor: Color(0xFF000000),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF000000),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('Purge & Re-sync', style: TextStyle(fontSize: 10.5)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF000000),
                    foregroundColor: const Color(0xFFFFFFFF),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: const Text('Close Settings', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? const Color(0xFF000000) : const Color(0xFF6B7280),
        size: 22,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? const Color(0xFF000000) : const Color(0xFF374151),
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
          fontSize: 14,
        ),
      ),
      trailing: isSelected ? Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.black, shape: BoxShape.circle)) : null,
      onTap: () {
        setState(() => _currentIndex = index);
        Navigator.pop(context);
      },
    );
  }

  Widget _getCurrentScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          onNavigateToTab: (index) => setState(() => _currentIndex = index),
        );
      case 1:
        return MapHUDView(
          initialSelectedHabitation: _mapTargetHabitation,
          initialSelectedShelter: _mapTargetShelter,
        );
      case 2:
        return RelocationPriorityView(
          onSelectHabitationOnMap: (habitation) => _navigateToMapWithHabitation(habitation),
        );
      case 3:
        return ShelterCapacityView(
          onSelectShelterOnMap: (shelter) => _navigateToMapWithShelter(shelter),
        );
      default:
        return HomeScreen(
          onNavigateToTab: (index) => setState(() => _currentIndex = index),
        );
    }
  }

  Widget _buildBottomNavigationBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 62,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _buildNavItem(1, Icons.map_outlined, Icons.map_rounded, 'Map'),
              _buildNavItem(2, Icons.crisis_alert_outlined, Icons.crisis_alert_rounded, 'Priorities'),
              _buildNavItem(3, Icons.night_shelter_outlined, Icons.night_shelter_rounded, 'Shelters'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData outlineIcon, IconData filledIcon, String label) {
    final isSelected = _currentIndex == index;

    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
          if (index != 1) {
            _mapTargetHabitation = null;
            _mapTargetShelter = null;
          }
        });
      },
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? filledIcon : outlineIcon,
              color: isSelected ? const Color(0xFF000000) : const Color(0xFF9CA3AF),
              size: 24,
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
