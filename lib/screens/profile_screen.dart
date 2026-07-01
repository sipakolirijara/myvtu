import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';
import '../main.dart'; // Import the global themeNotifier

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
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

  void _showSetPinDialog(bool requireCurrent) {
    // ... [Pin Dialog remains the same logic]
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        title: Text(requireCurrent ? 'Change Payment PIN' : 'Set Payment PIN', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (requireCurrent) ...[
              const Text('Current PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              TextField(controller: currentPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 8.0)),
              const SizedBox(height: 12),
            ],
            const Text('New PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            TextField(controller: newPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 8.0)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (newPinController.text.length == 4) {
                Navigator.pop(context);
                await _setPin(newPinController.text, currentPinController.text);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be 4 digits')));
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('Save', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _setPin(String newPin, String currentPin) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token') ?? '';
    final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'set_pin.php'), body: {'token': token, 'new_pin': newPin, 'current_pin': currentPin});
    final data = json.decode(response.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: data['success'] ? Colors.green : Colors.red));
    if (data['success']) _fetchProfile(); 
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor)));
    if (_profile == null) return const Scaffold(body: Center(child: Text('Error loading profile')));

    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Profile', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(radius: 40, backgroundColor: primaryColor, child: const Icon(Icons.person, size: 40, color: Colors.white)),
            const SizedBox(height: 16),
            Text('${_profile!['first_name']} ${_profile!['last_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${_profile!['email']}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('${_profile!['role']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(height: 40),
            
            // GLOBAL DARK MODE TOGGLE
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
              child: SwitchListTile(
                title: const Text('Dark Mode Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.dark_mode, color: primaryColor)),
                value: isDark,
                activeColor: primaryColor,
                onChanged: (bool value) async {
                  // Trigger the global notifier
                  themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  // Save preference
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', value);
                },
              ),
            ),

            _buildProfileMenu(Icons.phone, 'Phone Number', _profile!['phone'], null, primaryColor, isDark),
            _buildProfileMenu(Icons.lock, _profile!['has_pin'] ? 'Change Payment PIN' : 'Set Payment PIN', _profile!['has_pin'] ? '****' : 'Not Set', () => _showSetPinDialog(_profile!['has_pin']), primaryColor, isDark),
            _buildProfileMenu(Icons.logout, 'Log Out', '', _logout, primaryColor, isDark, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle, VoidCallback? onTap, Color primaryColor, bool isDark, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDestructive ? Colors.red.withOpacity(0.1) : primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isDestructive ? Colors.red : primaryColor)),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.red : (isDark ? Colors.white : Colors.black87))),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
      ),
    );
  }
}
