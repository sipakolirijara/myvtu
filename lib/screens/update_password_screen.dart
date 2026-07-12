import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UpdatePasswordScreen extends StatefulWidget {
  const UpdatePasswordScreen({Key? key}) : super(key: key);

  @override
  State<UpdatePasswordScreen> createState() => _UpdatePasswordScreenState();
}

class _UpdatePasswordScreenState extends State<UpdatePasswordScreen> {
  final _currentPassController = TextEditingController();
  final _newPassController = TextEditingController();
  final _confirmPassController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrent = true;
  bool _obscureNew = true;

  Future<void> _savePassword() async {
    if (_currentPassController.text.isEmpty || _newPassController.text.isEmpty) {
      _showError('All fields are required.');
      return;
    }
    if (_newPassController.text.length < 6) {
      _showError('Password must be at least 6 characters long.');
      return;
    }
    if (_newPassController.text != _confirmPassController.text) {
      _showError('New passwords do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'update_password.php'),
        body: {
          'token': token,
          'current_password': _currentPassController.text,
          'new_password': _newPassController.text,
        }
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
          Navigator.pop(context);
        }
      } else {
        _showError(data['message']);
      }
    } catch (e) {
      _showError('Network Error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Change Password', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            _buildPassField('Current Password', _currentPassController, isDark, _obscureCurrent, () => setState(() => _obscureCurrent = !_obscureCurrent)),
            const SizedBox(height: 24),
            _buildPassField('New Password', _newPassController, isDark, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 24),
            _buildPassField('Confirm New Password', _confirmPassController, isDark, _obscureNew, () => setState(() => _obscureNew = !_obscureNew)),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePassword,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Update Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPassField(String label, TextEditingController controller, bool isDark, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              border: InputBorder.none, 
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey.shade400),
                onPressed: toggle,
              )
            ),
          ),
        ),
      ],
    );
  }
}
