import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class ExamPinPurchaseScreen extends StatefulWidget {
  const ExamPinPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<ExamPinPurchaseScreen> createState() => _ExamPinPurchaseScreenState();
}

class _ExamPinPurchaseScreenState extends State<ExamPinPurchaseScreen> {
  String _selectedExam = '';
  double _selectedPrice = 0;
  int _quantity = 1;
  final _pinController = TextEditingController();

  bool _isLoadingExams = false;
  bool _isPurchasing = false;
  String _balance = '...';
  List<dynamic> _exams = [];

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchExams();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _fetchBalance() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_dashboard.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) setState(() => _balance = data['balance']);
      }
    } catch (_) {}
  }

  Future<void> _fetchExams() async {
    setState(() => _isLoadingExams = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_exam_pricing.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) setState(() => _exams = data['exams']);
      }
    } finally {
      if (mounted) setState(() => _isLoadingExams = false);
    }
  }

  bool get _isValid => _selectedExam.isNotEmpty && _quantity >= 1 && _quantity <= 5;

  double get _totalPrice => _selectedPrice * _quantity;

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
              Text('Confirm Purchase', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 20),
              _buildConfirmRow('Exam', _selectedExam, primaryColor, isDark),
              _buildConfirmRow('Quantity', _quantity.toString(), primaryColor, isDark),
              _buildConfirmRow('Amount', '₦${_totalPrice.toStringAsFixed(2)}', primaryColor, isDark, isAmount: true),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                      _buyExamPin();
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

  Future<void> _buyExamPin() async {
    setState(() => _isPurchasing = true);
    final txData = {
      'Service': 'Exam Pin',
      'Exam': _selectedExam,
      'Quantity': _quantity.toString(),
      'Amount': '₦${_totalPrice.toStringAsFixed(2)}',
      'Date': DateTime.now().toString().split('.')[0],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'buy_exam_pins.php'),
        body: {'token': token, 'exam_name': _selectedExam, 'quantity': _quantity.toString(), 'pin': _pinController.text.trim()},
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        txData['Status'] = 'Successful';
        final List<dynamic> pins = data['pins'] ?? [];
        if (pins.isNotEmpty) {
          for (var i = 0; i < pins.length; i++) {
            txData['Pin ${i + 1}'] = pins[i].toString();
          }
        }
        _navigateToStatus(true, data['message'] ?? 'Purchase processed.', txData);
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
        if (isSuccess) setState(() { _selectedExam = ''; _selectedPrice = 0; _quantity = 1; });
        _fetchBalance();
      },
    )));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Exam Pins', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text('1. Examination Body', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _isLoadingExams
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Row(
                  children: _exams.map((exam) {
                    final name = exam['name'].toString();
                    final price = double.tryParse(exam['price'].toString()) ?? 0;
                    final isSelected = _selectedExam == name;
                    return Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setState(() { _selectedExam = name; _selectedPrice = price; }),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                              border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300), width: isSelected ? 2 : 1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black87))),
                                const SizedBox(height: 4),
                                Text('₦${price.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            const SizedBox(height: 24),
            Text('2. Quantity (max 5)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildQtyButton(Icons.remove, () { if (_quantity > 1) setState(() => _quantity--); }, isDark),
                Expanded(
                  child: Center(
                    child: Text(_quantity.toString(), style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ),
                ),
                _buildQtyButton(Icons.add, () { if (_quantity < 5) setState(() => _quantity++); }, isDark),
              ],
            ),
            const SizedBox(height: 40),
            if (_selectedExam.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                    Text('₦${_totalPrice.toStringAsFixed(2)}', style: TextStyle(color: primaryColor, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (!_isValid || _isPurchasing) ? null : _showConfirmationModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Widget _buildQtyButton(IconData icon, VoidCallback onTap, bool isDark) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: isDark ? Colors.white : Colors.black87),
      ),
    );
  }
}
