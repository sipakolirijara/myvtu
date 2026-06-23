import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AirtimePurchaseScreen extends StatefulWidget {
  const AirtimePurchaseScreen({Key? key}) : super(key: key);

  @override
  State<AirtimePurchaseScreen> createState() => _AirtimePurchaseScreenState();
}

class _AirtimePurchaseScreenState extends State<AirtimePurchaseScreen> {
  String _selectedNetwork = '';
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  bool _isPurchasing = false;

  Future<void> _buyAirtime() async {
    if (_selectedNetwork.isEmpty || _phoneController.text.length < 10 || _amountController.text.isEmpty) {
      _showError('Please complete all fields correctly.');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';

      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/buy_airtime.php'),
        body: {
          'token': token,
          'network': _selectedNetwork,
          'amount': _amountController.text.trim(),
          'phone': _phoneController.text.trim(),
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        _showSuccess(data['message'] ?? 'Airtime top-up successful!');
        setState(() {
          _phoneController.clear();
          _amountController.clear();
        });
      } else {
        _showError(data['message'] ?? 'Transaction failed.');
      }
    } catch (e) {
      _showError('Network error connecting to API.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Buy Airtime VTU', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Select Network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildNetworkSelector(),
            const SizedBox(height: 24),
            
            const Text('2. Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.smartphone, '08012345678', _phoneController),
            const SizedBox(height: 24),
            
            const Text('3. Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.payments_outlined, 'e.g. 500', _amountController),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _buyAirtime,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4CAF50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isPurchasing ? const CircularProgressIndicator(color: Colors.white) : const Text('Top-up Airtime Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSelector() {
    final networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: networks.map((network) {
        final isSelected = _selectedNetwork == network;
        return GestureDetector(
          onTap: () => setState(() => _selectedNetwork = network),
          child: Container(
            width: 75,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4CAF50).withOpacity(0.1) : Colors.white,
              border: Border.all(color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade300, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(network, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF4CAF50) : Colors.grey.shade600))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(IconData icon, String hint, TextEditingController controller) {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20), hintText: hint, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }
}
