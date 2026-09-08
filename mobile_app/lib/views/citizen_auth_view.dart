import 'package:field_app/services/auth_service.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/material.dart';

/// Citizen self-registration screen.
///
/// Two-step flow:
///   1. Enter phone number → request OTP
///   2. Enter OTP → verify → issued CITIZEN-role JWT
///
/// For demo/judging convenience, the backend returns the OTP in the
/// response message (visible in the UI), so the flow can be exercised
/// end-to-end without an actual SMS gateway.
class CitizenAuthView extends StatefulWidget {
  const CitizenAuthView({super.key});

  @override
  State<CitizenAuthView> createState() => _CitizenAuthViewState();
}

class _CitizenAuthViewState extends State<CitizenAuthView> {
  final TextEditingController _phoneCtrl = TextEditingController(text: '9876543210');
  final TextEditingController _otpCtrl = TextEditingController();
  final AuthService _authService = AuthService.instance;

  bool _loading = false;
  bool _otpRequested = false;
  String? _error;
  String? _hintMessage;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _error = 'Please enter a valid 10-digit phone number.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await LiveGisApi.citizenRequestOtp(phoneNumber: phone);
      setState(() {
        _otpRequested = true;
        _hintMessage = response['message']?.toString();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp = _otpCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _error = 'OTP must be 6 digits.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await LiveGisApi.citizenVerifyOtp(phoneNumber: phone, otp: otp);
      final token = response['access_token']?.toString();
      final user = response['user'];
      if (token != null && user != null) {
        // Stash the token in AuthService so the rest of the app sees us as logged in.
        await _authService.loginWithCitizenToken(token: token, user: Map<String, dynamic>.from(user as Map));
        if (!mounted) return;
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'Server did not return an access token.');
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFFFFFF),
        foregroundColor: const Color(0xFF000000),
        elevation: 0,
        title: const Text('Citizen Sign In', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF000000),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Become a DisasterNet Citizen',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Citizens can submit SOS alerts, view live red zones and shelters around them, '
                      'and post crowd-sourced damage reports — even without internet, via the layered '
                      'offline mesh + SMS fallback.',
                      style: TextStyle(color: Colors.grey, fontSize: 12.5, height: 1.4),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              const Text('Phone Number', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
              const SizedBox(height: 6),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: 'e.g. 9876543210',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
                  ),
                  prefixText: '+91 ',
                ),
              ),
              if (_otpRequested) ...[
                const SizedBox(height: 20),
                const Text('One-Time Password', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF6B7280))),
                const SizedBox(height: 6),
                TextField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: InputDecoration(
                    hintText: '6-digit OTP',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF000000), width: 1.5),
                    ),
                  ),
                ),
                if (_hintMessage != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFA7F3D0)),
                    ),
                    child: Text(
                      _hintMessage!,
                      style: const TextStyle(fontSize: 11.5, color: Color(0xFF065F46)),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
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
                  onPressed: _loading
                      ? null
                      : _otpRequested
                          ? _verifyOtp
                          : _requestOtp,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(
                          _otpRequested ? 'Verify & Sign In' : 'Request OTP',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              const Divider(color: Color(0xFFE5E7EB)),
              const SizedBox(height: 16),
              const Text(
                'Quick sign-in for judging:',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF6B7280), fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _quickLogin('citizen', 'ChangeMe123!'),
                      icon: const Icon(Icons.person_outline, size: 16),
                      label: const Text('Citizen demo'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF000000),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _quickLogin('field_officer', 'ChangeMe123!'),
                      icon: const Icon(Icons.shield_outlined, size: 16),
                      label: const Text('Field officer'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF000000),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _quickLogin('sdma_admin', 'ChangeMe123!'),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 16),
                  label: const Text('SDMA admin (full access)'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF000000),
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _quickLogin(String username, String password) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authService.login(username: username, password: password);
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }
}
