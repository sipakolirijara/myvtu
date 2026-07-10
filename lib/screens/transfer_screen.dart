import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _identifierController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isVerifying = false;
  bool _isSending = false;
  bool _recipientVerified = false;
  String? _recipientName;
  int? _recipientId;
  String _balance = '...';

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _identifierController.addListener(_resetRecipient);
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _identifierController.dispose();
    _amountController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _resetRecipient() {
    if (_recipientVerified) {
      setState(() {
        _recipientVerified = false;
        _recipientName = null;
        _recipientId = null;
      });
    }
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

  bool get _isValid {
    if (!_recipientVerified) return false;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 50) return false;
    return true;
  }

  Future<void> _verifyRecipient() async {
    final identifier = _identifierController.text.trim();
    if (identifier.isEmpty) return;
    setState(() => _isVerifying = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'lookup_recipient.php'),
        body: {'token': token, 'identifier': identifier},
      );
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _recipientVerified = data['success'] == true;
          _recipientName = data['name'];
          _recipientId = data['recipient_id'] != null ? int.tryParse(data['recipient_id'].toString()) : null;
        });
        if (!_recipientVerified) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Recipient not found.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
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
              Text('Confirm Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 20),
              _buildRow('Recipient', _recipientName ?? '', primaryColor, isDark),
              _buildRow('Amount', '₦${_amountController.text}', primaryColor, isDark, isAmount: true),
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
                      _sendTransfer();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid 4-digit PIN')));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Confirm & Send', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRow(String label, String value, Color primaryColor, bool isDark, {bool isAmount = false}) {
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

  Future<void> _sendTransfer() async {
    setState(() => _isSending = true);
    final txData = {
      'Service': 'Wallet Transfer',
      'Recipient': _recipientName ?? '',
      'Amount': '₦${_amountController.text}',
      'Date': DateTime.now().toString().split('.')[0],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'transfer_funds.php'),
        body: {
          'token': token,
          'recipient_id': _recipientId.toString(),
          'amount': _amountController.text.trim(),
          'pin': _pinController.text.trim(),
        },
      );
      final data = json.decode(response.body);
      if (data['success'] == true) {
        txData['Status'] = 'Successful';
        Navigator.push(context, MaterialPageRoute(builder: (_) => TransactionStatusScreen(
          isSuccess: true, message: data['message'] ?? 'Transfer successful.', transactionData: txData,
          onDone: () {
            setState(() {
              _identifierController.clear();
              _amountController.clear();
              _recipientVerified = false;
              _recipientName = null;
              _recipientId = null;
            });
            _fetchBalance();
          },
        )));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Transfer failed.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network connection timed out.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSending = false);
      _pinController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Transfer', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text('Recipient', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 6),
            Text('Email, phone number, or username', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    child: TextField(
                      controller: _identifierController,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.person_search, color: Colors.grey.shade400, size: 20),
                        hintText: 'e.g user@example.com',
                        hintStyle: TextStyle(color: Colors.grey.shade500),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _verifyRecipient,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_recipientVerified && _recipientName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('✓ $_recipientName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            const SizedBox(height: 24),
            Text('Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade400, size: 20),
                  hintText: 'Min ₦50',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (!_isValid || _isSending) ? null : _showConfirmationModal,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSending
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Send Funds', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
