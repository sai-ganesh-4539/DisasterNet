import 'package:field_app/models/habitation.dart';
import 'package:field_app/models/safe_shelter.dart';
import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/material.dart';

class OperationsConsoleView extends StatefulWidget {
  const OperationsConsoleView({
    super.key,
    required this.onSelectHabitationOnMap,
    required this.onSelectShelterOnMap,
  });

  final ValueChanged<Habitation> onSelectHabitationOnMap;
  final ValueChanged<SafeShelter> onSelectShelterOnMap;

  @override
  State<OperationsConsoleView> createState() => _OperationsConsoleViewState();
}

class _OperationsConsoleViewState extends State<OperationsConsoleView> {
  final AuthService _auth = AuthService.instance;
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _stateCodeController = TextEditingController();
  final TextEditingController _districtController = TextEditingController();

  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _dashboard;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_handleAuthChanged);
    _initialize();
  }

  @override
  void dispose() {
    _auth.removeListener(_handleAuthChanged);
    _usernameController.dispose();
    _passwordController.dispose();
    _stateCodeController.dispose();
    _districtController.dispose();
    super.dispose();
  }

  void _handleAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _auth.initialize();
    if (_auth.isAuthenticated) {
      await _loadDashboard();
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _auth.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );
      if (!_auth.canAccessOperations) {
        setState(() {
          _dashboard = null;
          _error = 'This account does not have planning-console permissions.';
        });
        return;
      }
      await _loadDashboard();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadDashboard() async {
    if (!_auth.isAuthenticated || _auth.accessToken == null) {
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final payload = await LiveGisApi.operationsDashboard(
        token: _auth.accessToken!,
        stateCode: _stateCodeController.text.trim().isEmpty ? null : _stateCodeController.text.trim(),
        districtQuery: _districtController.text.trim().isEmpty ? null : _districtController.text.trim(),
      );
      if (!mounted) return;
      setState(() => _dashboard = payload);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _logout() async {
    await _auth.logout();
    if (!mounted) return;
    setState(() {
      _dashboard = null;
      _error = null;
      _passwordController.clear();
    });
  }

  List<Map<String, dynamic>> _rows(String key) {
    return ((_dashboard?[key] as List?) ?? const []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Map<String, dynamic> _map(String key) => Map<String, dynamic>.from(_dashboard?[key] as Map? ?? const {});

  @override
  Widget build(BuildContext context) {
    final summary = _map('summary');
    final dataSources = _map('data_sources');
    final authContext = _map('auth_context');
    final advisories = ((_dashboard?['advisories'] as List?) ?? const []).map((e) => e.toString()).toList();
    final districtOverview = _rows('district_overview');
    final topHabitations = _rows('top_priority_habitations');
    final topShelters = _rows('constrained_shelters');
    final topZones = _rows('critical_red_zones');

    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        title: Text(_auth.isAuthenticated && (_dashboard?['mode']?.toString() == 'DEMO_SCENARIO') ? 'SDMA Operations Console · Demo' : 'SDMA Operations Console'),
        actions: [
          if (_auth.isAuthenticated)
            IconButton(
              onPressed: _loading ? null : _loadDashboard,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: !_auth.isAuthenticated
            ? _buildLoginView()
            : !_auth.canAccessOperations
                ? _buildAccessDenied()
                : RefreshIndicator(
                    onRefresh: _loadDashboard,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildAuthHeader(authContext),
                        const SizedBox(height: 14),
                        _buildFilterPanel(),
                        const SizedBox(height: 14),
                        if (_error != null) _buildErrorCard(_error!),
                        if (advisories.isNotEmpty) ...[
                          _buildAdvisoryCard(advisories),
                          const SizedBox(height: 14),
                        ],
                        _buildSummaryGrid(summary),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Top relocation priorities'),
                        const SizedBox(height: 8),
                        if (topHabitations.isEmpty)
                          _buildEmptyCard('No prioritized habitations are available for the current filter.')
                        else
                          ...topHabitations.take(6).map(_buildHabitationCard),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Shelter constraints & carrying capacity'),
                        const SizedBox(height: 8),
                        if (topShelters.isEmpty)
                          _buildEmptyCard('No shelter records are available for the current filter.')
                        else
                          ...topShelters.take(6).map(_buildShelterCard),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Critical red zones'),
                        const SizedBox(height: 8),
                        if (topZones.isEmpty)
                          _buildEmptyCard(_dashboard?['mode']?.toString() == 'DEMO_SCENARIO' ? 'No critical red zones are present in the active scenario snapshot.' : 'No critical red zones are present in the latest live snapshot.')
                        else
                          ...topZones.take(6).map(_buildZoneCard),
                        const SizedBox(height: 16),
                        _buildSectionHeader('District overview'),
                        const SizedBox(height: 8),
                        if (districtOverview.isEmpty)
                          _buildEmptyCard(_dashboard?['mode']?.toString() == 'DEMO_SCENARIO' ? 'No district aggregation is available for the active scenario snapshot.' : 'No district aggregation is available for the current live snapshot.')
                        else
                          ...districtOverview.take(8).map(_buildDistrictCard),
                        const SizedBox(height: 16),
                        _buildSectionHeader('Source provenance'),
                        const SizedBox(height: 8),
                        _buildSourceCard(dataSources),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildLoginView() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF000000),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Protected planning access', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'This console is intended for SDMA, state, and district decision-makers. Sign in with a backend operator account to access protected planning views.',
                style: TextStyle(color: Color(0xFFD1D5DB), fontSize: 12, height: 1.35),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _buildLabeledField('Username', _usernameController),
        const SizedBox(height: 10),
        _buildLabeledField('Password', _passwordController, obscureText: true),
        if (_error != null) ...[
          const SizedBox(height: 12),
          _buildErrorCard(_error!),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: _loading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000000),
            foregroundColor: const Color(0xFFFFFFFF),
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Sign in to operations console', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
        const Text(
          'For local development, use a bootstrap operator account configured in the backend environment.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }

  Widget _buildAccessDenied() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _buildErrorCard('Signed-in account does not have planning-console permission.'),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: _logout,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000000), foregroundColor: const Color(0xFFFFFFFF)),
          child: const Text('Sign out'),
        ),
      ],
    );
  }

  Widget _buildAuthHeader(Map<String, dynamic> authContext) {
    final generatedAt = _dashboard?['generated_at']?.toString() ?? 'Unknown';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF000000), borderRadius: BorderRadius.circular(18)),
                child: Text(_auth.role.replaceAll('_', ' '), style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
              ),
              const Spacer(),
              TextButton.icon(onPressed: _logout, icon: const Icon(Icons.logout_rounded, size: 16), label: const Text('Sign out')),
            ],
          ),
          const SizedBox(height: 8),
          Text(_auth.username, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF111827))),
          const SizedBox(height: 4),
          Text(
            '${(_dashboard?['mode']?.toString() == 'DEMO_SCENARIO') ? 'Scenario snapshot loaded at' : 'Live snapshot generated at'} $generatedAt',
            style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
          ),
          if ((authContext['state_code']?.toString().isNotEmpty ?? false) || (authContext['district_code']?.toString().isNotEmpty ?? false)) ...[
            const SizedBox(height: 6),
            Text(
              'Scope: ${authContext['state_code'] ?? 'ALL STATES'} / ${authContext['district_code'] ?? 'ALL DISTRICTS'}',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Operational filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            'Optional state or district text filter for the current operations snapshot.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _buildLabeledField('State code', _stateCodeController)),
              const SizedBox(width: 10),
              Expanded(child: _buildLabeledField('District contains', _districtController)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () {
                          _stateCodeController.clear();
                          _districtController.clear();
                          _loadDashboard();
                        },
                  child: const Text('Reset filters'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _loading ? null : _loadDashboard,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF000000), foregroundColor: const Color(0xFFFFFFFF)),
                  child: const Text('Refresh planning view'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryGrid(Map<String, dynamic> summary) {
    final cards = [
      ('Red zones', '${summary['red_zone_count'] ?? 0}', Icons.layers_rounded, const Color(0xFFD97706)),
      ('Immediate', '${summary['immediate_count'] ?? 0}', Icons.crisis_alert_rounded, const Color(0xFFDC2626)),
      ('Population exposed', '${summary['population_exposed'] ?? 0}', Icons.groups_rounded, const Color(0xFF1D4ED8)),
      ('Available capacity', '${summary['available_capacity'] ?? 0}', Icons.night_shelter_rounded, const Color(0xFF059669)),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: cards.length,
      itemBuilder: (context, index) {
        final (title, value, icon, color) = cards[index];
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFFFF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(height: 8),
              Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(title, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHabitationCard(Map<String, dynamic> row) {
    final category = row['priority_category']?.toString() ?? 'UNKNOWN';
    final color = category == 'IMMEDIATE'
        ? const Color(0xFFDC2626)
        : category == 'SHORT_TERM'
            ? const Color(0xFFD97706)
            : const Color(0xFF2563EB);
    return _buildActionCard(
      title: row['village_name']?.toString() ?? 'Unnamed habitation',
      subtitle: '${row['district_name'] ?? 'Unknown district'} • Population ${row['total_population'] ?? 0}',
      trailing: '${row['priority_score'] ?? 0}',
      color: color,
      actionLabel: 'Open on map',
      onTap: () {
        widget.onSelectHabitationOnMap(Habitation.fromJson(row));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildShelterCard(Map<String, dynamic> row) {
    final isSafe = row['is_in_safe_zone'] == true;
    return _buildActionCard(
      title: row['shelter_name']?.toString() ?? 'Unnamed shelter',
      subtitle: '${row['district_name'] ?? 'Unknown district'} • Available ${row['available_capacity'] ?? 0} • Constraint ${row['capacity_constraint'] ?? 'NONE'}',
      trailing: isSafe ? 'SAFE' : 'UNSAFE',
      color: isSafe ? const Color(0xFF059669) : const Color(0xFFDC2626),
      actionLabel: 'Inspect on map',
      onTap: () {
        widget.onSelectShelterOnMap(SafeShelter.fromJson(row));
        Navigator.pop(context);
      },
    );
  }

  Widget _buildZoneCard(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Container(width: 10, height: 10, decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row['hazard_type'] ?? 'UNKNOWN'} zone', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 3),
                Text('Risk ${row['risk_score'] ?? 0} • ${row['time_horizon'] ?? 'ACTIVE'} • ${row['grid_count'] ?? 0} grid cells', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDistrictCard(Map<String, dynamic> row) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row['district_name']?.toString() ?? 'Unknown district', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
              Text('${row['state_code'] ?? 'IN'}', style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280), fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Immediate ${row['immediate_count'] ?? 0} • Short-term ${row['short_term_count'] ?? 0} • Shelters ${row['shelter_count'] ?? 0} • Capacity ${row['available_capacity'] ?? 0}',
            style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(Map<String, dynamic> sources) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (sources.isEmpty)
            const Text('No source provenance is available yet.', style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280)))
          else
            ...sources.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${entry.key}: ${entry.value}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563))),
              ),
            ),
          const SizedBox(height: 8),
          Text(
            (_dashboard?['mode']?.toString() == 'DEMO_SCENARIO')
                ? 'This planning console is currently running on a curated scenario dataset for deterministic SIH demonstration outputs.'
                : 'This planning console uses backend-generated live snapshots as its source of truth; the device cache is only for offline continuity.',
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required String trailing,
    required Color color,
    required String actionLabel,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
                child: Text(trailing, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: color)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280))),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(onPressed: onTap, icon: const Icon(Icons.arrow_forward_rounded, size: 16), label: Text(actionLabel)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabeledField(String label, TextEditingController controller, {bool obscureText = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5E7EB))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF000000))),
          ),
        ),
      ],
    );
  }

  Widget _buildAdvisoryCard(List<String> advisories) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Actionable advisories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF92400E))),
          const SizedBox(height: 6),
          ...advisories.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• $item', style: const TextStyle(fontSize: 11.5, color: Color(0xFF78350F))),
              )),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(message, style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(text, style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B7280))),
    );
  }

  Widget _buildSectionHeader(String text) {
    return Text(text, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF111827)));
  }
}
