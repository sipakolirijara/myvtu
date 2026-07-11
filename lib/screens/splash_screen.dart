import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../main.dart';
import 'login_screen.dart';
import 'dashboard_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  String _appName = 'Kainuwa VTU';

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));
    
    _animationController.forward();
    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _appName = prefs.getString('app_name') ?? 'Kainuwa VTU';
    });

    // 1. Fetch live settings from backend to sync instantly
    try {
      final response = await http.get(Uri.parse(ApiConfig.baseUrl + 'get_settings.php')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final liveName = data['settings']['website_name'] ?? 'Kainuwa VTU';
          final liveColorHex = data['settings']['primary_color'] ?? '#7351FF';
          
          await prefs.setString('app_name', liveName);
          await prefs.setString('primary_color', liveColorHex);
          
          // Instantly update the app's global theme color
          primaryColorNotifier.value = Color(int.parse(liveColorHex.replaceAll('#', '0xFF')));
          
          if (mounted) {
            setState(() => _appName = liveName);
          }
        }
      }
    } catch (_) {
      // Fail silently and use cached data if network is unavailable
    }

    // Ensure the splash screen shows for at least 2 seconds for smooth UX
    await Future.delayed(const Duration(seconds: 1));

    // 2. Check Auth Status and Navigate
    if (!mounted) return;
    
    final token = prefs.getString('api_token');
    final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
    
    if (token != null && token.isNotEmpty) {
      // TODO: Phase 3 (App Lock) goes here later. For now, go to Dashboard.
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    } else {
      if (hasSeenOnboarding) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const OnboardingScreen()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold uses the dynamically updated primary color
    return Scaffold(
      backgroundColor: primaryColorNotifier.value,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // White circular background for the app icon
              Container(
                width: 120,
                height: 120,
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, 10)),
                  ],
                ),
                child: Image.asset(
                  'assets/icon.png',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Icon(Icons.flash_on, size: 60, color: primaryColorNotifier.value),
                ),
              ),
              const SizedBox(height: 24),
              // Dynamic Website Name
              Text(
                _appName,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
