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
    
    // Listeners for real-time validation
    _phoneController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
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

  // VALIDATION LOGIC
  bool get _isValid {
    if (_selectedNetwork.isEmpty) return false;
    if (_phoneController.text.length != 11) return false;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 100) return false;
    return true;
  }

  String? get _phoneError {
    if (_phoneController.text.isNotEmpty && _phoneController.text.length != 11) {
      return 'Phone number must be exactly 11 digits';
    }
    return null;
  }

  String? get _amountError {
    if (_amountController.text.isNotEmpty) {
      final amount = double.tryParse(_amountController.text) ?? 0;
      if (amount < 100) return 'Minimum amount is ₦100';
    }
    return null;
  }

  void _showConfirmationModal() {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 24, right: 24, top: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Confirm Top-up', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 20),
              _buildConfirmRow('Network', _selectedNetwork, primaryColor, isDark),
              _buildConfirmRow('Phone Number', _phoneController.text, primaryColor, isDark),
              _buildConfirmRow('Amount', '₦${_amountController.text}', primaryColor, isDark, isAmount: true),
              const SizedBox(height: 20),
              Text('Enter Transaction PIN', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 10),
              TextField(
                controller: _pinController,
                obscureText: true,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, letterSpacing: 8.0, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '****', 
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))
                ),
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

  Widget _buildConfirmRow(String label, String value, Color primaryColor, bool isDark, {bool isAmount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
          Text(value, style: TextStyle(color: isAmount ? primaryColor : (isDark ? Colors.white : Colors.black87), fontSize: 15, fontWeight: isAmount ? FontWeight.bold : FontWeight.w600)),
        ],
      ),
    );
  }

  Future<void> _buyAirtime() async {
    setState(() => _isPurchasing = true);
    final formattedAmount = double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00';
    final txData = {'Service': 'Airtime Top-up', 'Network': _selectedNetwork, 'Number': _phoneController.text, 'Amount': '₦$formattedAmount', 'Date': DateTime.now().toString().split('.')[0]};

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/buy_airtime.php'),
        body: {'token': token, 'network': _selectedNetwork, 'amount': _amountController.text.trim(), 'phone': _phoneController.text.trim(), 'pin': _pinController.text.trim()},
      );
      
      final data = json.decode(response.body);
      if (data['success'] == true) {
        txData['Status'] = 'Successful';
        _navigateToStatus(true, data['message'] ?? 'Transaction processed.', txData);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Transaction failed.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network connection timed out.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
      _pinController.clear();
    }
  }

  void _navigateToStatus(bool isSuccess, String message, Map<String, dynamic> txData) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionStatusScreen(
      isSuccess: isSuccess, message: message, transactionData: txData, 
      onDone: () {
        if (isSuccess) setState(() { _phoneController.clear(); _amountController.clear(); });
        _fetchBalance();
      }
    )));
  }

  Color _getNetworkColor(String network) {
    switch (network) {
      case 'MTN': return const Color(0xFFFFB300); // Orange/Yellow
      case 'AIRTEL': return const Color(0xFFFF0000); // Red
      case 'GLO': return const Color(0xFF009900); // Green
      case '9MOBILE': return const Color(0xFF006600); // Dark Green
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Buy Airtime', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
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
            Text('1. Select Network', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _buildNetworkSelector(),
            const SizedBox(height: 24),
            Text('2. Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.smartphone, 'e.g 08012345678', _phoneController, isDark, maxLength: 11, errorText: _phoneError),
            const SizedBox(height: 24),
            Text('3. Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _buildTextField(Icons.payments_outlined, 'Min ₦100', _amountController, isDark, errorText: _amountError),
            const SizedBox(height: 16),
            
            // QUICK AMOUNT CHIPS
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [100, 200, 500, 1000, 2000, 10000].map((amount) {
                return InkWell(
                  onTap: () {
                    _amountController.text = amount.toString();
                    FocusScope.of(context).unfocus();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: primaryColor.withOpacity(0.3))),
                    child: Text('₦$amount', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                // Disabled if not valid or currently purchasing
                onPressed: (!_isValid || _isPurchasing) ? null : _showConfirmationModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor, 
                  disabledBackgroundColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                child: _isPurchasing 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Proceed', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNetworkSelector() {
    final networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: networks.map((network) {
        final isSelected = _selectedNetwork == network;
        final netColor = _getNetworkColor(network);
        return GestureDetector(
          onTap: () => setState(() => _selectedNetwork = network),
          child: Container(
            width: 75,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? netColor : (isDark ? const Color(0xFF1E1E1E) : Colors.white), 
              border: Border.all(color: isSelected ? netColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300), width: isSelected ? 2 : 1), 
              borderRadius: BorderRadius.circular(12)
            ),
            child: Center(child: Text(network, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade500))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(IconData icon, String hint, TextEditingController controller, bool isDark, {int? maxLength, String? errorText}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white, 
            borderRadius: BorderRadius.circular(12), 
            border: Border.all(color: errorText != null ? Colors.red : (isDark ? Colors.grey.shade800 : Colors.grey.shade200))
          ),
          child: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            maxLength: maxLength,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              counterText: '', // Hide length counter
              prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20), 
              hintText: hint, 
              hintStyle: TextStyle(color: Colors.grey.shade500), 
              border: InputBorder.none, 
              contentPadding: const EdgeInsets.symmetric(vertical: 16)
            ),
          ),
        ),
        if (errorText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0, left: 4.0),
            child: Text(errorText, style: const TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
          )
      ],
    );
  }
}
