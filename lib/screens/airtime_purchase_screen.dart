import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class AirtimePurchaseScreen extends StatefulWidget {
  const AirtimePurchaseScreen({Key? key}) : super(key: key);

  @override
  State<AirtimePurchaseScreen> createState() => _AirtimePurchaseScreenState();
}

class _AirtimePurchaseScreenState extends State<AirtimePurchaseScreen> {
  String _selectedNetwork = '';
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();
  bool _isPurchasing = false;
  String _balance = '...';

  @override
  void initState() {
    super.initState();
    _fetchBalance();
  }

  Future<void> _fetchBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_dashboard.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) setState(() => _balance = data['balance']);
      }
    } catch (_) {}
  }

  void _showConfirmationModal() {
    if (_selectedNetwork.isEmpty || _phoneController.text.length < 10 || _amountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields')));
      return;
    }

    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Confirm Top-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
              const SizedBox(height: 20),
              _buildConfirmRow('Network', _selectedNetwork, primaryColor),
              _buildConfirmRow('Phone Number', _phoneController.text, primaryColor),
              _buildConfirmRow('Amount', '₦${_amountController.text}', primaryColor, isAmount: true),
              const SizedBox(height: 20),
              const Text('Enter Transaction PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold),
                decoration: InputDecoration(hintText: '****', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    if (_pinController.text.length == 4) {
                      Navigator.pop(context);
                      _buyAirtime();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid 4-digit PIN')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Confirm & Pay', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      }
    );
  }

  Widget _buildConfirmRow(String label, String value, Color primaryColor, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
          Text(value, style: TextStyle(color: isAmount ? primaryColor : Colors.black87, fontSize: 15, fontWeight: isAmount ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _buyAirtime() async {
    setState(() => _isPurchasing = true);
    
    final formattedAmount = double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00';
    
    // Construct the Detailed Receipt Data
    final txData = {
      'Service': 'Airtime Top-up',
      'Network': _selectedNetwork,
      'Number': _phoneController.text,
      'Amount': '₦$formattedAmount',
      'Date': DateTime.now().toString().split('.')[0],
    };

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
          'pin': _pinController.text.trim(),
        },
      );
      
      final data = json.decode(response.body);
      final isSuccess = data['success'] == true;
      txData['Status'] = isSuccess ? 'Successful' : 'Failed';
      
      _navigateToStatus(isSuccess, data['message'] ?? 'Transaction processed.', txData);
      
    } catch (e) {
      txData['Status'] = 'Failed';
      _navigateToStatus(false, 'Network connection timed out.', txData);
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
      _pinController.clear();
    }
  }

  void _navigateToStatus(bool isSuccess, String message, Map<String, dynamic> txData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionStatusScreen(
          isSuccess: isSuccess,
          message: message,
          transactionData: txData,
          onDone: () {
            if (isSuccess) {
              setState(() {
                _phoneController.clear();
                _amountController.clear();
              });
            }
            _fetchBalance();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Buy Airtime', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: Text('₦$_balance', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('1. Select Network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildNetworkSelector(primaryColor),
            const SizedBox(height: 24),
            const Text('2. Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.smartphone, 'e.g 08012345678', _phoneController),
            const SizedBox(height: 24),
            const Text('3. Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.payments_outlined, 'e.g 500', _amountController),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _showConfirmationModal,
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isPurchasing ? const CircularProgressIndicator(color: Colors.white) : const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSelector(Color primaryColor) {
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
            decoration: BoxDecoration(color: isSelected ? primaryColor.withOpacity(0.1) : Colors.white, border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade300, width: isSelected ? 2 : 1), borderRadius: BorderRadius.circular(12)),
            child: Center(child: Text(network, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.grey.shade600))),
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
