import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

// GLOBAL THEME CONTROLLER
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _fetchAndCacheSettings();
  
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  runApp(const MyApp());
}

Future<void> _fetchAndCacheSettings() async {
  try {
    final response = await http.get(Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_settings.php')).timeout(const Duration(seconds: 5));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('app_name', data['settings']['website_name'] ?? 'Kainuwa Data');
        await prefs.setString('primary_color', data['settings']['primary_color'] ?? '#7351FF');
      }
    }
  } catch (_) {}
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Color _primaryColor = const Color(0xFF7351FF);
  String? _initialRoute;

  @override
  void initState() {
    super.initState();
    _loadInitData();
  }

  Future<void> _loadInitData() async {
    final prefs = await SharedPreferences.getInstance();
    final hexColor = prefs.getString('primary_color') ?? '#7351FF';
    setState(() {
      _primaryColor = Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    });

    final token = prefs.getString('api_token');
    setState(() {
      _initialRoute = (token != null && token.isNotEmpty) ? 'dashboard' : 'login';
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_initialRoute == null) {
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentMode, __) {
        return MaterialApp(
          title: 'Dynamic VTU App',
          debugShowCheckedModeBanner: false,
          themeMode: currentMode,
          theme: ThemeData(
            primaryColor: _primaryColor,
            colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor, brightness: Brightness.light),
            scaffoldBackgroundColor: const Color(0xFFF4F6F9),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.black)),
          ),
          darkTheme: ThemeData(
            primaryColor: _primaryColor,
            colorScheme: ColorScheme.fromSeed(seedColor: _primaryColor, brightness: Brightness.dark),
            scaffoldBackgroundColor: const Color(0xFF121212),
            appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
            cardColor: const Color(0xFF1E1E1E),
          ),
          home: _initialRoute == 'dashboard' ? const DashboardScreen() : const LoginScreen(),
        );
      },
    );
  }
}
