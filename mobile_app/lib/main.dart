import 'package:field_app/core/database.dart';
import 'package:field_app/role_aware_shell.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await DatabaseService().initialize();
  } catch (e) {
    debugPrint('Database initialization warning: $e');
  }
  runApp(const DisasterNetApp());
}

class DisasterNetApp extends StatelessWidget {
  const DisasterNetApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DisasterNet',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.black,
          primary: Colors.black,
          surface: Colors.white,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        fontFamily: 'Roboto',
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFFFFFFF),
          foregroundColor: Color(0xFF000000),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF000000),
            foregroundColor: const Color(0xFFFFFFFF),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const RoleAwareShell(),
    );
  }
}
