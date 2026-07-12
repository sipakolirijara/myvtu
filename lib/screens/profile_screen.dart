import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'login_screen.dart';
import 'security_settings_screen.dart';
import 'edit_profile_screen.dart';
import '../main.dart'; 

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

  // SHARE APP FEATURE
  Future<void> _shareApp() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.baseUrl + 'get_settings.php')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final message = data['settings']['share_message'] ?? 'Download Kainuwa VTU!';
          final url = data['settings']['share_url'] ?? '';
          Share.share('$message\n\n$url');
          return;
        }
      }
    } catch (_) {}
    // Fallback if network fails
    Share.share('Download Kainuwa VTU to buy cheap data and airtime instantly!');
  }

  // DYNAMIC CUSTOMER SUPPORT SHEET
  void _showSupportSheet() {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Customer Support', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text('How would you like us to help you today?', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
              const SizedBox(height: 24),
              
              FutureBuilder<http.Response>(
                future: http.get(Uri.parse(ApiConfig.baseUrl + 'get_support.php')),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Padding(padding: const EdgeInsets.all(30.0), child: CircularProgressIndicator(color: primaryColor));
                  }
                  
                  if (!snapshot.hasData || snapshot.data!.statusCode != 200) {
                    return const Padding(padding: EdgeInsets.all(20.0), child: Text('Failed to load support channels.', style: TextStyle(color: Colors.red)));
                  }

                  final data = json.decode(snapshot.data!.body);
                  if (data['success'] != true || data['contacts'].isEmpty) {
                    return const Padding(padding: EdgeInsets.all(20.0), child: Text('No active support channels at this time.'));
                  }

                  return Column(
                    children: (data['contacts'] as List).map<Widget>((contact) {
                      IconData icon;
                      Color iconColor;
                      if (contact['support_type'] == 'whatsapp') {
                        icon = Icons.chat_bubble_outline;
                        iconColor = Colors.green;
                      } else if (contact['support_type'] == 'phone') {
                        icon = Icons.phone_outlined;
                        iconColor = primaryColor;
                      } else {
                        icon = Icons.email_outlined;
                        iconColor = Colors.orange;
                      }

                      return ListTile(
                        leading: Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor)),
                        title: Text(contact['name'], style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        subtitle: Text(contact['contact_value'], style: TextStyle(color: Colors.grey.shade500, fontSize: 13)),
                        trailing: Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey.shade400),
                        onTap: () => _launchURL(contact['support_type'], contact['contact_value']),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _launchURL(String type, String value) async {
    Uri? uri;
    if (type == 'whatsapp') {
      final cleanPhone = value.replaceAll(RegExp(r'[^\d+]'), '');
      uri = Uri.parse('https://wa.me/$cleanPhone');
    } else if (type == 'phone') {
      uri = Uri.parse('tel:$value');
    } else if (type == 'email') {
      uri = Uri.parse('mailto:$value');
    }

    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch application')));
    }
  }

  void _showSetPinDialog(bool requireCurrent) {
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
    await prefs.remove('api_token');
    if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Column(
                children: [
                  CircleAvatar(radius: 40, backgroundColor: primaryColor, child: const Icon(Icons.person, size: 40, color: Colors.white)),
                  const SizedBox(height: 16),
                  Text('${_profile!['first_name']} ${_profile!['last_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  Text('${_profile!['email']}', style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('${_profile!['role']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            Text('GENERAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
            const SizedBox(height: 12),
            _buildProfileMenu(Icons.person_outline, 'Edit Profile', 'Update your personal details', () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditProfileScreen(currentProfile: _profile!)));
              if (result == true) _fetchProfile(); // Refresh if edited
            }, primaryColor, isDark),
            _buildProfileMenu(Icons.support_agent, 'Customer Support', 'Contact us for help', _showSupportSheet, primaryColor, isDark),
            _buildProfileMenu(Icons.share_outlined, 'Share App', 'Invite your friends', _shareApp, primaryColor, isDark),
            
            const SizedBox(height: 24),
            Text('SECURITY & DISPLAY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
            const SizedBox(height: 12),

            Container(
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
              child: SwitchListTile(
                title: const Text('Dark Mode Display', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.dark_mode, color: primaryColor)),
                value: isDark,
                activeColor: primaryColor,
                onChanged: (bool value) async {
                  themeNotifier.value = value ? ThemeMode.dark : ThemeMode.light;
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setBool('is_dark_mode', value);
                },
              ),
            ),
            _buildProfileMenu(Icons.security, 'App Security', 'Auto-logout & Biometrics', () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()));
            }, primaryColor, isDark),
            _buildProfileMenu(Icons.lock, _profile!['has_pin'] ? 'Change Payment PIN' : 'Set Payment PIN', _profile!['has_pin'] ? '****' : 'Not Set', () => _showSetPinDialog(_profile!['has_pin']), primaryColor, isDark),
            
            const SizedBox(height: 24),
            Text('ACCOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
            const SizedBox(height: 12),
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
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
      ),
    );
  }
}
