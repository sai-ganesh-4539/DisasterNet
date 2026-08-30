import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:field_app/core/database.dart';
import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/live_gis_store.dart';
import 'package:field_app/services/sync_service.dart';
import 'package:field_app/views/habitation_survey_view.dart';
import 'package:field_app/views/home_screen.dart';
import 'package:field_app/views/map_hud_view.dart';
import 'package:field_app/views/operations_console_view.dart';
import 'package:field_app/views/relocation_priority_view.dart';
import 'package:field_app/views/shelter_capacity_view.dart';
import 'package:field_app/views/shelter_survey_view.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final Connectivity _connectivity = Connectivity();
  final LiveGisStore _store = LiveGisStore.instance;
  final SyncService _syncService = SyncService();
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService.instance;

  int _currentIndex = 0;
  bool _isOnline = true;
  String _deviceHash = 'FIELD-NODE';
  StreamSubscription<dynamic>? _connectivitySub;

  Habitation? _mapTargetHabitation;
  SafeShelter? _mapTargetShelter;

  @override
  void initState() {
    super.initState();
    _store.addListener(_handleStoreChanged);
    _authService.addListener(_handleStoreChanged);
    _initialize();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _store.removeListener(_handleStoreChanged);
    _authService.removeListener(_handleStoreChanged);
    super.dispose();
  }

  void _handleStoreChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _db.initialize();
    await _initializeConnectivity();
    await _initializeDeviceIdentity();
    await _authService.initialize();
    await _syncService.initialize(_deviceHash);
    await _store.initializeAndRefresh();
  }

  Future<void> _initializeConnectivity() async {
    final result = await _connectivity.checkConnectivity();
    if (mounted) {
      setState(() => _isOnline = _isConnectedValue(result));
    }
    _connectivitySub = _connectivity.onConnectivityChanged.listen((result) async {
      final isOnline = _isConnectedValue(result);
      if (!mounted) return;
      setState(() => _isOnline = isOnline);
      if (isOnline) {
        await _syncService.processSyncQueue();
      }
    });
  }

  bool _isConnectedValue(dynamic result) {
    if (result is ConnectivityResult) {
      return result != ConnectivityResult.none;
    }
    if (result is List<ConnectivityResult>) {
      return result.any((r) => r != ConnectivityResult.none);
    }
    return true;
  }

  Future<void> _initializeDeviceIdentity() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final id = androidInfo.id;
      if (mounted && id.isNotEmpty) {
        setState(() => _deviceHash = id.length > 8 ? id.substring(0, 8).toUpperCase() : id.toUpperCase());
      }
    } catch (_) {}
  }

  void _navigateToMapWithHabitation(Habitation habitation) {
    setState(() {
      _mapTargetHabitation = habitation;
      _mapTargetShelter = null;
      _currentIndex = 1;
    });
  }

  void _navigateToMapWithShelter(SafeShelter shelter) {
    setState(() {
      _mapTargetShelter = shelter;
      _mapTargetHabitation = null;
      _currentIndex = 1;
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
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: Color(0xFF000000), size: 24),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 14),
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
                _buildStatusIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    final statusText = !_isOnline
        ? 'OFFLINE'
        : _store.loading
            ? 'REFRESHING'
            : _store.isDemoScenarioMode
                ? 'DEMO MODE'
                : _store.generatedAt != null
                    ? 'LIVE DATA'
                    : 'STARTING';
    final bg = !_isOnline
        ? const Color(0xFFF3F4F6)
        : _store.loading
            ? const Color(0xFFFFFBEB)
            : const Color(0xFFECFDF5);
    final fg = !_isOnline
        ? const Color(0xFF4B5563)
        : _store.loading
            ? const Color(0xFFB45309)
            : const Color(0xFF059669);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(shape: BoxShape.circle, color: fg),
          ),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    final lastUpdated = _store.generatedAt?.toLocal().toString().replaceFirst('.000', '') ?? 'Not synced yet';
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
                      decoration: const BoxDecoration(color: Color(0xFFFFFFFF), shape: BoxShape.circle),
                      child: const Icon(Icons.hub_rounded, color: Color(0xFF000000), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Operational Field Node',
                            style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 16, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _authService.isAuthenticated
                                ? 'Node: $_deviceHash • ${_authService.role.replaceAll('_', ' ')}'
                                : 'Node: $_deviceHash',
                            style: TextStyle(color: Colors.grey[400], fontSize: 11, fontFamily: 'monospace'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    _store.isDemoScenarioMode
                        ? 'DEMO SCENARIO • ${_store.scenarioName.isNotEmpty ? _store.scenarioName : 'Scenario mode'}'
                        : _isOnline
                            ? 'CONNECTED • $lastUpdated'
                            : 'OFFLINE CACHE MODE',
                    style: const TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 12),
              children: [
                _buildDrawerItem(0, Icons.home_rounded, 'Command Dashboard'),
                _buildDrawerItem(1, Icons.map_rounded, _store.isDemoScenarioMode ? 'Scenario Red Zone Map' : 'Live GIS Red Zone Map'),
                _buildDrawerItem(2, Icons.crisis_alert_rounded, 'Relocation Priority Matrix'),
                _buildDrawerItem(3, Icons.night_shelter_rounded, 'Shelter & Greenfield Siting'),
                if (_store.isDemoScenarioMode)
                  ListTile(
                    leading: const Icon(Icons.alt_route_rounded, color: Color(0xFF000000)),
                    title: const Text('Switch Demo Scenario', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    subtitle: Text(
                      _store.scenarioName.isNotEmpty ? _store.scenarioName : 'Scenario mode',
                      style: const TextStyle(fontSize: 11),
                    ),
                    onTap: () {
                      Navigator.pop(context);
                      _showScenarioPicker();
                    },
                  ),
                ListTile(
                  leading: Icon(
                    _authService.isAuthenticated ? Icons.admin_panel_settings_rounded : Icons.lock_outline_rounded,
                    color: const Color(0xFF000000),
                  ),
                  title: const Text('SDMA Operations Console', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                    _authService.isAuthenticated ? _authService.username : 'Protected planning access',
                    style: const TextStyle(fontSize: 11),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => OperationsConsoleView(
                          onSelectHabitationOnMap: _navigateToMapWithHabitation,
                          onSelectShelterOnMap: _navigateToMapWithShelter,
                        ),
                      ),
                    );
                  },
                ),
                if (_authService.isAuthenticated)
                  ListTile(
                    leading: const Icon(Icons.logout_rounded, color: Color(0xFF000000)),
                    title: const Text('Sign Out Operator', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _authService.logout();
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Operator session cleared.'),
                          backgroundColor: Color(0xFF000000),
                        ),
                      );
                    },
                  ),
                const Divider(color: Color(0xFFE5E7EB), height: 24),
                ListTile(
                  leading: const Icon(Icons.edit_location_alt_rounded, color: Color(0xFF000000)),
                  title: const Text('Log Habitation Survey', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HabitationSurveyView()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.add_business_rounded, color: Color(0xFF000000)),
                  title: const Text('Register Shelter Survey', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ShelterSurveyView()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF000000)),
                  title: const Text('Execute Offline Sync Queue', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                  onTap: () async {
                    Navigator.pop(context);
                    final count = await _syncService.syncPendingItems();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Offline queue processed ($count item${count == 1 ? '' : 's'} attempted).'),
                        backgroundColor: const Color(0xFF000000),
                      ),
                    );
                    await _store.refreshFromLocationOrIndia();
                  },
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () {
              Navigator.pop(context);
              _showSdmaSettingsModal();
            },
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFE5E7EB)))),
              child: Row(
                children: [
                  const Icon(Icons.settings_rounded, color: Color(0xFF000000), size: 20),
                  const SizedBox(width: 12),
                  const Text('System Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const Spacer(),
                  Text(_store.cacheHit ? 'cached' : 'live', style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSdmaSettingsModal() {
    final sourceList = _store.dataSources.entries.toList();
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
            child: FutureBuilder<Map<String, dynamic>>(
              future: _syncService.getSyncStatus(),
              builder: (context, snapshot) {
                final syncStatus = snapshot.data ?? const {};
                final pending = syncStatus['local_pending'] ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(color: const Color(0xFFE5E7EB), borderRadius: BorderRadius.circular(2)),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _store.isDemoScenarioMode ? 'Scenario Data Status' : 'Operational Data Status',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.satellite_alt_rounded, size: 16, color: Color(0xFF000000)),
                              SizedBox(width: 8),
                              Text('Active Data Sources', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          if (sourceList.isEmpty)
                            const Text('No live sources have been loaded yet.', style: TextStyle(fontSize: 11, color: Color(0xFF4B5563)))
                          else
                            ...sourceList.take(4).map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.warning_amber_rounded, size: 16, color: Color(0xFFDC2626)),
                              SizedBox(width: 8),
                              Text('Live Decision Snapshot', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text('${_store.isDemoScenarioMode ? 'Loaded' : 'Generated'}: ${_store.generatedAt?.toLocal() ?? 'Pending'}', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                          Text('Red zones: ${_store.summary['red_zone_count'] ?? 0} • Immediate habitations: ${_store.summary['immediate_count'] ?? 0}', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                          if (_store.isDemoScenarioMode && _store.scenarioName.isNotEmpty)
                            Text('Scenario: ${_store.scenarioName}', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                          Text('Safe shelters: ${_store.summary['safe_shelter_count'] ?? 0} • Available beds: ${_store.summary['available_beds'] ?? 0}', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
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
                              const Text('Offline Cache & Sync Queue', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Node $_deviceHash • Pending uploads: $pending', style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
                            ],
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              await _db.clearAll();
                              await _store.initializeAndRefresh(forceRefresh: true);
                              if (context.mounted) Navigator.pop(context);
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
                      child: const Text('Close', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 10),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showScenarioPicker() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final scenarios = await _store.fetchDemoScenarios();
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFFFFFFFF),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Switch demo scenario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text(
                'Choose a deterministic hazard scenario for the SIH walkthrough.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 16),
              ...scenarios.map(
                (scenario) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    scenario['is_active'] == true ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                    color: const Color(0xFF000000),
                  ),
                  title: Text(scenario['name']?.toString() ?? 'Scenario', style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    scenario['description']?.toString() ?? '',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    await _store.activateDemoScenario(scenario['scenario_id'].toString());
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Activated scenario: ${scenario['name']}'),
                        backgroundColor: const Color(0xFF000000),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not load scenarios: $e'),
          backgroundColor: const Color(0xFFB91C1C),
        ),
      );
    }
  }

  Widget _buildDrawerItem(int index, IconData icon, String title) {
    final isSelected = _currentIndex == index;
    return ListTile(
      leading: Icon(icon, color: isSelected ? const Color(0xFF000000) : const Color(0xFF6B7280), size: 22),
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
        return HomeScreen(onNavigateToTab: (index) => setState(() => _currentIndex = index));
      case 1:
        return MapHUDView(initialSelectedHabitation: _mapTargetHabitation, initialSelectedShelter: _mapTargetShelter);
      case 2:
        return RelocationPriorityView(onSelectHabitationOnMap: _navigateToMapWithHabitation);
      case 3:
        return ShelterCapacityView(onSelectShelterOnMap: _navigateToMapWithShelter);
      default:
        return HomeScreen(onNavigateToTab: (index) => setState(() => _currentIndex = index));
    }
  }

  Widget _buildBottomNavigationBar() {
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
            Icon(isSelected ? filledIcon : outlineIcon, color: isSelected ? const Color(0xFF000000) : const Color(0xFF9CA3AF), size: 24),
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
