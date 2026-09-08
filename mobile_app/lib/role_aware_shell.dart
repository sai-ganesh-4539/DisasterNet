import 'dart:async';

import 'package:field_app/services/auth_service.dart';
import 'package:field_app/views/citizen_auth_view.dart';
import 'package:field_app/main_screen.dart';
import 'package:field_app/views/citizen_home_view.dart';
import 'package:flutter/material.dart';

/// Role-aware shell — chooses the appropriate home screen and
/// navigation based on the user's role.
///
///   * CITIZEN → CitizenHomeView (SOS, alerts, layered GIS map, report)
///   * FIELD_OFFICER / NATIONAL_ADMIN / etc → MainScreen (existing
///     operator app with relocation priority + shelter capacity)
///   * Unauthenticated → CitizenAuthView (with quick sign-in buttons)
class RoleAwareShell extends StatefulWidget {
  const RoleAwareShell({super.key});

  @override
  State<RoleAwareShell> createState() => _RoleAwareShellState();
}

class _RoleAwareShellState extends State<RoleAwareShell> {
  final AuthService _authService = AuthService.instance;
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
    _authService.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _authService.removeListener(_onAuthChanged);
    super.dispose();
  }

  void _onAuthChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _initialize() async {
    await _authService.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Color(0xFFFFFFFF),
            body: Center(child: CircularProgressIndicator(color: Colors.black)),
          );
        }
        if (!_authService.isAuthenticated) {
          return const CitizenAuthView();
        }
        if (_authService.isCitizen) {
          return const CitizenHomeView();
        }
        // Operators (field_officer, admin, analyst, etc.)
        return const MainScreen();
      },
    );
  }
}
