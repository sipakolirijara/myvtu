import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class UpdatePinScreen extends StatefulWidget {
  final bool hasPin;
  const UpdatePinScreen({Key? key, required this.hasPin}) : super(key: key);

  @override
  State<UpdatePinScreen> createState() => _UpdatePinScreenState();
}

class _UpdatePinScreenState extends State<UpdatePinScreen> {
  final _currentPinController = TextEditingController();
  final _newPinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  bool _isLoading = false;

  Future<void> _savePin() async {
    if (widget.hasPin && _currentPinController.text.length != 4) {
      _showError('Please enter your current 4-digit PIN.');
      return;
    }
    if (_newPinController.text.length != 4) {
      _showError('New PIN must be exactly 4 digits.');
      return;
    }
    if (_newPinController.text != _confirmPinController.text) {
      _showError('New PINs do not match.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'set_pin.php'),
        body: {
          'token': token,
          'current_pin': _currentPinController.text,
          'new_pin': _newPinController.text,
        }
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.green));
          Navigator.pop(context, true);
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
        title: Text(widget.hasPin ? 'Change PIN' : 'Set PIN', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            if (widget.hasPin) ...[
              _buildPinField('Current PIN', _currentPinController, isDark),
              const SizedBox(height: 24),
            ],
            _buildPinField('New PIN', _newPinController, isDark),
            const SizedBox(height: 24),
            _buildPinField('Confirm New PIN', _confirmPinController, isDark),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _savePin,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : Text(widget.hasPin ? 'Update PIN' : 'Set PIN', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildPinField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
          child: TextField(
            controller: controller,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 4,
            textAlign: TextAlign.center,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87, letterSpacing: 16.0, fontSize: 24, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(vertical: 16), counterText: ""),
          ),
        ),
      ],
    );
  }
}
