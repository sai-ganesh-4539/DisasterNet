import 'package:field_app/core/database.dart';
import 'package:field_app/services/live_gis_api.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  AuthService._();
  static final AuthService instance = AuthService._();

  final DatabaseService _db = DatabaseService();

  bool _initialized = false;
  bool loading = false;
  String? error;
  String? _accessToken;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty && _user != null;
  String? get accessToken => _accessToken;
  Map<String, dynamic>? get user => _user;
  String get username => _user?['username']?.toString() ?? 'Unknown';
  String get role => _user?['role']?.toString() ?? 'SIGNED_OUT';
  List<String> get permissions => ((_user?['permissions'] as List?) ?? const []).map((e) => e.toString()).toList();
  String? get stateCode => _user?['state_code']?.toString();
  String? get districtCode => _user?['district_code']?.toString();

  bool get canAccessOperations {
    final roleUpper = role.toUpperCase();
    return roleUpper.contains('ADMIN') ||
        roleUpper.contains('ANALYST') ||
        roleUpper.contains('MAGISTRATE') ||
        roleUpper.contains('OFFICER') ||
        permissions.contains('ANALYZE') ||
        permissions.contains('APPROVE');
  }

  bool get isCitizen => role.toUpperCase() == 'CITIZEN';
  bool get isFieldOfficer =>
      role.toUpperCase() == 'FIELD_OFFICER' ||
      role.toUpperCase() == 'FIELD_SURVEYOR' ||
      role.toUpperCase() == 'DISTRICT_OPERATIONS_OFFICER';

  Future<void> initialize() async {
    if (_initialized) return;
    await _db.initialize();
    final session = _db.getAuthSession();
    if (session != null) {
      _accessToken = session['access_token']?.toString();
      _user = Map<String, dynamic>.from(session['user'] as Map? ?? const {});
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> login({required String username, required String password}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await LiveGisApi.login(username: username, password: password);
      _accessToken = response['access_token']?.toString();
      _user = Map<String, dynamic>.from(response['user'] as Map? ?? const {});
      if (_accessToken == null || _accessToken!.isEmpty || _user == null || _user!.isEmpty) {
        throw Exception('Backend returned an incomplete login response.');
      }
      await _db.saveAuthSession(token: _accessToken!, user: _user!);
    } catch (e) {
      error = e.toString();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// Used by the citizen OTP flow — we already have a token, just persist it.
  Future<void> loginWithCitizenToken({required String token, required Map<String, dynamic> user}) async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      _accessToken = token;
      _user = Map<String, dynamic>.from(user);
      await _db.saveAuthSession(token: token, user: _user!);
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> refreshProfile() async {
    if (_accessToken == null || _accessToken!.isEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final profile = await LiveGisApi.currentUser(_accessToken!);
      _user = Map<String, dynamic>.from(profile);
      await _db.saveAuthSession(token: _accessToken!, user: _user!);
    } catch (e) {
      error = e.toString();
      await logout();
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _accessToken = null;
    _user = null;
    error = null;
    await _db.clearAuthSession();
    notifyListeners();
  }
}
