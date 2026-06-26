import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'login_screen.dart';

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
      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_profile.php'),
        body: {'token': token},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() => _profile = data);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSetPinDialog() {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Transaction PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: TextField(
          controller: pinController,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 4,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 24, letterSpacing: 8.0),
          decoration: const InputDecoration(hintText: '****'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text.length == 4) {
                Navigator.pop(context);
                await _setPin(pinController.text);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7351FF)),
            child: const Text('Save PIN', style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }

  Future<void> _setPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('api_token') ?? '';
    final response = await http.post(
      Uri.parse('https://vtu.kainuwa.africa/api/mobile/set_pin.php'),
      body: {'token': token, 'pin': pin},
    );
    final data = json.decode(response.body);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: data['success'] ? Colors.green : Colors.red));
    if (data['success']) _fetchProfile(); // Refresh to update PIN status
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginScreen()), (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFF7351FF))));
    if (_profile == null) return const Scaffold(body: Center(child: Text('Error loading profile')));

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text('My Profile', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 20)), automaticallyImplyLeading: false),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const CircleAvatar(radius: 40, backgroundColor: Color(0xFF7351FF), child: Icon(Icons.person, size: 40, color: Colors.white)),
            const SizedBox(height: 16),
            Text('${_profile!['first_name']} ${_profile!['last_name']}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text('${_profile!['email']}', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Text('${_profile!['role']}', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12))),
            const SizedBox(height: 40),
            
            _buildProfileMenu(Icons.phone, 'Phone Number', _profile!['phone'], null),
            _buildProfileMenu(Icons.lock, _profile!['has_pin'] ? 'Change Transaction PIN' : 'Set Transaction PIN', _profile!['has_pin'] ? '****' : 'Not Set', _showSetPinDialog),
            _buildProfileMenu(Icons.logout, 'Log Out', '', _logout, isDestructive: true),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu(IconData icon, String title, String subtitle, VoidCallback? onTap, {bool isDestructive = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
      child: ListTile(
        onTap: onTap,
        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: isDestructive ? Colors.red.withOpacity(0.1) : const Color(0xFF7351FF).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: isDestructive ? Colors.red : const Color(0xFF7351FF))),
        title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDestructive ? Colors.red : Colors.black87)),
        subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(color: Colors.grey)) : null,
        trailing: onTap != null ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey) : null,
      ),
    );
  }
}
