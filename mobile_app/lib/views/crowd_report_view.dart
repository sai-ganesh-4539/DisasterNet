import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

/// Citizen crowd-sourced damage report submission view.
///
/// Lets any citizen (or anonymous user) submit a damage report with
/// category, severity, location, description, photo URL, people
/// affected, casualties. Field officers can also verify reports.
class CrowdReportView extends StatefulWidget {
  const CrowdReportView({super.key});

  @override
  State<CrowdReportView> createState() => _CrowdReportViewState();
}

class _CrowdReportViewState extends State<CrowdReportView> {
  final AuthService _authService = AuthService.instance;

  String _category = 'FLOOD';
  String _severity = 'HIGH';
  final TextEditingController _descriptionCtrl = TextEditingController();
  final TextEditingController _peopleCtrl = TextEditingController();
  final TextEditingController _casualtiesCtrl = TextEditingController();
  final TextEditingController _phoneCtrl = TextEditingController();
  final TextEditingController _photoUrlCtrl = TextEditingController();

  bool _submitting = false;
  String? _resultMessage;
  String? _error;

  @override
  void dispose() {
    _descriptionCtrl.dispose();
    _peopleCtrl.dispose();
    _casualtiesCtrl.dispose();
    _phoneCtrl.dispose();
    _photoUrlCtrl.dispose();
    super.dispose();
  }

  Future<Position?> _getLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) return null;
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

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      final pos = await _getLocation();
      final lat = pos?.latitude ?? 19.076;
      final lon = pos?.longitude ?? 72.877;

      final result = await LiveGisApi.submitCrowdReport(
        category: _category,
        severity: _severity,
        latitude: lat,
        longitude: lon,
        description: _descriptionCtrl.text.trim(),
        peopleAffected: int.tryParse(_peopleCtrl.text.trim()),
        casualties: int.tryParse(_casualtiesCtrl.text.trim()),
        photoUrl: _photoUrlCtrl.text.trim().isEmpty ? null : _photoUrlCtrl.text.trim(),
        contactPhone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
        token: _authService.accessToken,
      );

      if (result != null && result['accepted'] == true) {
        setState(() {
          _resultMessage = 'Report submitted successfully. Report ID: ${result['report_id']}';
        });
        _descriptionCtrl.clear();
        _peopleCtrl.clear();
        _casualtiesCtrl.clear();
        _phoneCtrl.clear();
        _photoUrlCtrl.clear();
      } else {
        setState(() {
          _resultMessage = 'Report staged locally — backend was unreachable. It will be retried when connectivity returns.';
        });
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        elevation: 0,
        title: const Text('Report Damage', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF000000))),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Help responders by reporting damage near you.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
              const SizedBox(height: 20),

              const Text('Category', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  'FLOOD',
                  'LANDSLIDE',
                  'ROAD_BLOCKED',
                  'STRUCTURE_DAMAGE',
                  'FIRE',
                  'WATERLOGGING',
                  'MEDICAL',
                  'STRANDED',
                  'OTHER',
                ].map((cat) {
                  final selected = _category == cat;
                  return ChoiceChip(
                    label: Text(cat.replaceAll('_', ' ')),
                    selected: selected,
                    onSelected: (_) => setState(() => _category = cat),
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

              const Text('Severity', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: ['LOW', 'MEDIUM', 'HIGH', 'CRITICAL'].map((sev) {
                  final selected = _severity == sev;
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
                    onSelected: (_) => setState(() => _severity = sev),
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

              TextField(
                controller: _descriptionCtrl,
                maxLines: 4,
                maxLength: 1000,
                decoration: const InputDecoration(
                  labelText: 'Describe what you see',
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 16),

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
                      controller: _casualtiesCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Casualties',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Contact phone (optional)',
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _photoUrlCtrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Photo URL (optional)',
                  labelStyle: TextStyle(fontSize: 12),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 20),

              if (_resultMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF059669), size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_resultMessage!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECACA)),
                  ),
                  child: Text(_error!, style: const TextStyle(fontSize: 12.5, color: Color(0xFFB91C1C))),
                ),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : const Text('Submit Report', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
