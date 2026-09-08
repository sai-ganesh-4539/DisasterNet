import 'dart:async';

import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/sos_service.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Citizen-facing SOS dispatch view.
///
/// Shows a single big "Send SOS" button plus a quick category selector.
/// When the user taps the button, the SosService runs the 3-layer
/// fallback chain (server → mesh → SMS) and the UI shows live status
/// for each layer.
///
/// Below the SOS button the view also shows:
///   * The local mesh & SMS queues (with retry buttons)
///   * Recent dispatch history (which layer accepted each SOS)
class SosView extends StatefulWidget {
  const SosView({super.key});

  @override
  State<SosView> createState() => _SosViewState();
}

class _SosViewState extends State<SosView> {
  final SosService _sosService = SosService.instance;
  final AuthService _authService = AuthService.instance;

  String _selectedCategory = 'MEDICAL';
  String _selectedSeverity = 'HIGH';
  final TextEditingController _messageCtrl = TextEditingController();
  final TextEditingController _peopleCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();

  bool _sending = false;
  SosDispatchResult? _lastResult;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _sosService.addListener(_onChange);
    _ensureInit();
  }

  @override
  void dispose() {
    _sosService.removeListener(_onChange);
    _messageCtrl.dispose();
    _peopleCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  Future<void> _ensureInit() async {
    await _sosService.initialize(
      deviceId: 'CITIZEN-APP',
      authToken: _authService.accessToken,
    );
  }

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please enable location services.')),
          );
        }
        return null;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _sendSos() async {
    setState(() {
      _sending = true;
      _lastResult = null;
    });
    try {
      final pos = await _getLocation();
      final lat = pos?.latitude ?? 19.076;  // Mumbai default for prototype
      final lon = pos?.longitude ?? 72.877;

      final result = await _sosService.dispatchSos(
        latitude: lat,
        longitude: lon,
        category: _selectedCategory,
        severity: _selectedSeverity,
        message: _messageCtrl.text.trim(),
        peopleCount: int.tryParse(_peopleCtrl.text.trim()),
        contactPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );

      setState(() => _lastResult = result);
    } finally {
      setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Text('Emergency SOS', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF000000))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Big SOS button
              Center(
                child: GestureDetector(
                  onTap: _sending ? null : _sendSos,
                  child: Container(
                    width: 180,
                    height: 180,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                        stops: [0.4, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _sending
                        ? const Center(
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                            ),
                          )
                        : const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.crisis_alert_rounded, color: Colors.white, size: 56),
                              SizedBox(height: 4),
                              Text(
                                'SEND SOS',
                                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1.5),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Tap to dispatch',
                                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Last result
              if (_lastResult != null) ...[
                _buildResultCard(_lastResult!),
                const SizedBox(height: 16),
              ],

              // Category
              const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'MEDICAL',
                  'STRANDED',
                  'FOOD_WATER',
                  'SHELTER',
                  'VIOLENCE',
                  'FIRE',
                  'OTHER',
                ].map((cat) {
                  final selected = _selectedCategory == cat;
                  return ChoiceChip(
                    label: Text(cat.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedCategory = cat),
                    selectedColor: const Color(0xFF000000),
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : const Color(0xFF374151),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // Severity
              const Text('Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((sev) {
                  final selected = _selectedSeverity == sev;
                  final color = sev == 'CRITICAL'
                      ? const Color(0xFFDC2626)
                      : sev == 'HIGH'
                          ? const Color(0xFFD97706)
                          : sev == 'MEDIUM'
                              ? const Color(0xFFCA8A04)
                              : const Color(0xFF059669);
                  return ChoiceChip(
                    label: Text(sev),
                    selected: selected,
                    onSelected: (_) => setState(() => _selectedSeverity = sev),
                    selectedColor: color,
                    labelStyle: TextStyle(
                      color: selected ? Colors.white : color,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    side: BorderSide(color: color.withValues(alpha: 0.4)),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // People count & contact phone
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _peopleCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'People affected',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _phoneCtrl,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Contact phone',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Message
              TextField(
                controller: _messageCtrl,
                maxLines: 3,
                maxLength: 280,
                decoration: const InputDecoration(
                  labelText: 'Describe the situation (optional)',
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 24),

              // Layered fallback status
              const Text('Layered Offline Fallback',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
              const SizedBox(height: 4),
              const Text(
                'SOS messages try each layer in order until one succeeds. '
                'When no signal is available, the SOS is staged locally and propagated the moment any device in the mesh regains connectivity.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              ),
              const SizedBox(height: 12),
              _buildLayerRow(
                layer: '1. Server Direct',
                description: 'HTTPS POST to the central DisasterNet server.',
                icon: Icons.cloud_done_rounded,
                color: const Color(0xFF059669),
                status: _lastResult?.deliveredLayer == 'SERVER_DIRECT'
                    ? 'Delivered'
                    : 'Standby',
              ),
              _buildLayerRow(
                layer: '2. Phone-to-Phone Mesh',
                description: 'Bluetooth LE / Wi-Fi Direct relay to nearby phones.',
                icon: Icons.wifi_tethering_rounded,
                color: const Color(0xFF0EA5E9),
                status: _lastResult?.deliveredLayer == 'MESH_RELAY'
                    ? 'Delivered via mesh'
                    : _sosService.meshQueue.isNotEmpty
                        ? '${_sosService.meshQueue.length} in queue'
                        : 'Standby',
              ),
              _buildLayerRow(
                layer: '3. SMS Gateway',
                description: 'Compact structured SMS to the gateway number.',
                icon: Icons.sms_rounded,
                color: const Color(0xFFD97706),
                status: _lastResult?.deliveredLayer == 'SMS_GATEWAY'
                    ? 'Delivered via SMS'
                    : _sosService.smsQueue.isNotEmpty
                        ? '${_sosService.smsQueue.length} queued'
                        : 'Standby',
              ),
              const SizedBox(height: 24),

              // Recent dispatches
              if (_sosService.recentDispatches.isNotEmpty) ...[
                const Text('Recent Dispatches',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF000000))),
                const SizedBox(height: 8),
                ..._sosService.recentDispatches.take(5).map((d) => _buildDispatchRow(d)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultCard(SosDispatchResult result) {
    final delivered = result.delivered;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: delivered ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: delivered ? const Color(0xFFA7F3D0) : const Color(0xFFFCD34D),
        ),
      ),
      child: Row(
        children: [
          Icon(
            delivered ? Icons.check_circle_rounded : Icons.access_time_rounded,
            size: 32,
            color: delivered ? const Color(0xFF059669) : const Color(0xFFD97706),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  delivered ? 'SOS Delivered' : 'SOS Staged Locally',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  result.message,
                  style: const TextStyle(fontSize: 11.5, color: Color(0xFF4B5563), height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLayerRow({
    required String layer,
    required String description,
    required IconData icon,
    required Color color,
    required String status,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(layer, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
                  Text(description, style: const TextStyle(fontSize: 10.5, color: Color(0xFF6B7280))),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFFFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Text(status, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF374151))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDispatchRow(Map<String, dynamic> d) {
    final layer = d['layer']?.toString() ?? '';
    final ts = d['timestamp']?.toString() ?? '';
    final msg = d['message']?.toString() ?? '';
    final layerColor = layer == 'SERVER_DIRECT'
        ? const Color(0xFF059669)
        : layer == 'MESH_RELAY'
            ? const Color(0xFF0EA5E9)
            : const Color(0xFFD97706);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: layerColor, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: layerColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  child: Text(layer, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: layerColor)),
                ),
                const Spacer(),
                Text(
                  ts.length > 19 ? ts.substring(11, 19) : ts,
                  style: const TextStyle(fontSize: 9, color: Color(0xFF6B7280), fontFamily: 'monospace'),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(msg, style: const TextStyle(fontSize: 11, color: Color(0xFF4B5563))),
          ],
        ),
      ),
    );
  }
}
