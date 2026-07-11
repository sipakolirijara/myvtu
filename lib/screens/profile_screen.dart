import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'login_screen.dart';
import 'app_lock_screen.dart';
import '../main.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  bool _appLockEnabled = false;
  bool _lockOnResume = true;
  bool _useBiometric = false;
  bool _biometricAvailable = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _loadAppLockSettings();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    final LocalAuthentication auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics || await auth.isDeviceSupported();
    if (mounted) setState(() => _biometricAvailable = canCheck);
  }

  Future<void> _loadAppLockSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _appLockEnabled = prefs.getBool('app_lock_enabled') ?? false;
        _lockOnResume = prefs.getBool('lock_on_resume') ?? true;
        _useBiometric = prefs.getBool('use_biometric') ?? false;
      });
    }
  }

  Future<void> _fetchProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_profile.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) setState(() => _profile = data);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('api_token');
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  Future<void> _toggleAppLock(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    if (enable) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AppLockScreen(
            isSetup: true,
            onSuccess: () {
              _loadAppLockSettings(); 
            },
          ),
        ),
      );
    } else {
      await prefs.setBool('app_lock_enabled', false);
      await prefs.remove('app_lock_pin');
      await prefs.setBool('use_biometric', false);
      _loadAppLockSettings();
    }
  }

  Future<void> _toggleLockOnResume(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lock_on_resume', enable);
    setState(() => _lockOnResume = enable);
  }

  Future<void> _toggleBiometric(bool enable) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('use_biometric', enable);
    setState(() => _useBiometric = enable);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Profile & Security', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.bold, fontSize: 18)),
      ),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: primaryColor))
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 80, height: 80,
                        decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                        child: Center(child: Text(_profile!['first_name'][0].toUpperCase(), style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: primaryColor))),
                      ),
                      const SizedBox(height: 16),
                      Text('${_profile!['first_name']} ${_profile!['last_name']}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                      Text(_profile!['email'], style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text('APP SECURITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                Container(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
                  child: Column(
                    children: [
                      SwitchListTile(
                        activeColor: primaryColor,
                        title: Text('App Lock PIN', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text('Require a 6-digit PIN when opening app', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        value: _appLockEnabled,
                        onChanged: _toggleAppLock,
                        secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.phonelink_lock, color: primaryColor)),
                      ),
                      if (_appLockEnabled) ...[
                        const Divider(height: 1),
                        SwitchListTile(
                          activeColor: primaryColor,
                          title: Text('Lock on App Exit', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                          subtitle: Text('Ask PIN every single time app is minimized', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                          value: _lockOnResume,
                          onChanged: _toggleLockOnResume,
                          secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.timer_outlined, color: primaryColor)),
                        ),
                        if (_biometricAvailable) ...[
                          const Divider(height: 1),
                          SwitchListTile(
                            activeColor: primaryColor,
                            title: Text('Fingerprint Unlock', style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                            subtitle: Text('Use device biometrics to unlock', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            value: _useBiometric,
                            onChanged: _toggleBiometric,
                            secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.fingerprint, color: primaryColor)),
                          ),
                        ]
                      ]
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                Text('ACCOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                const SizedBox(height: 12),
                
                _buildProfileMenu(Icons.shield_outlined, 'Change Password', 'Update your login password', null, primaryColor, isDark),
                _buildProfileMenu(Icons.logout, 'Log Out', 'Sign out of your account', _logout, primaryColor, isDark, isDestructive: true),
              ],
            ),
          ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle, VoidCallback? onTap, Color primaryColor, bool isDark, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDestructive ? Colors.red.withOpacity(0.1) : primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isDestructive ? Colors.red : primaryColor)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87))),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)) : null,
        trailing: isDestructive ? null : Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
      ),
    );
  }
}
