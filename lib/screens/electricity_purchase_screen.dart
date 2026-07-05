import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class ElectricityPurchaseScreen extends StatefulWidget {
  const ElectricityPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<ElectricityPurchaseScreen> createState() => _ElectricityPurchaseScreenState();
}

class _ElectricityPurchaseScreenState extends State<ElectricityPurchaseScreen> {
  int? _selectedDiscoId;
  String _selectedDiscoName = '';
  String _meterType = 'prepaid';
  final _meterController = TextEditingController();
  final _phoneController = TextEditingController();
  final _amountController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoadingDiscos = false;
  bool _isVerifying = false;
  bool _isPurchasing = false;
  bool _isVerified = false;
  String? _verifiedName;
  String _balance = '...';

  List<dynamic> _discos = [];

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchDiscos();
    _meterController.addListener(() {
      setState(() { _isVerified = false; _verifiedName = null; });
    });
    _phoneController.addListener(() => setState(() {}));
    _amountController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _meterController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
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

  Future<void> _fetchDiscos() async {
    setState(() => _isLoadingDiscos = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_electricity_discos.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() => _discos = data['discos']);
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Could not load DISCOs.'), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingDiscos = false);
    }
  }

  bool get _isValid {
    if (_selectedDiscoId == null) return false;
    if (_meterController.text.length < 6) return false;
    if (_phoneController.text.length != 11) return false;
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 500 || amount > 200000) return false;
    if (!_isVerified) return false;
    return true;
  }

  Future<void> _verifyMeter() async {
    if (_selectedDiscoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a DISCO first')));
      return;
    }
    if (_meterController.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid meter number')));
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'verify_meter.php'),
        body: {'token': token, 'service_id': _selectedDiscoId.toString(), 'meter': _meterController.text.trim(), 'meter_type': _meterType},
      );
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _isVerified = data['success'] == true;
          _verifiedName = data['customer_name'];
        });
        if (!_isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Could not verify meter number.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification request failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
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
              Text('Confirm Bill Payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 6),
              Text('Tokens cannot be reversed once generated.', style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600)),
              const SizedBox(height: 16),
              _buildConfirmRow('DISCO', _selectedDiscoName, primaryColor, isDark),
              _buildConfirmRow('Meter', _meterController.text, primaryColor, isDark),
              if (_verifiedName != null) _buildConfirmRow('Name', _verifiedName!, primaryColor, isDark),
              _buildConfirmRow('Type', _meterType == 'prepaid' ? 'Prepaid' : 'Postpaid', primaryColor, isDark),
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
                      _payElectricity();
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

  Future<void> _payElectricity() async {
    setState(() => _isPurchasing = true);
    final formattedAmount = double.tryParse(_amountController.text)?.toStringAsFixed(2) ?? '0.00';
    final txData = {
      'Service': 'Electricity Bill',
      'DISCO': _selectedDiscoName,
      'Meter': _meterController.text,
      'Type': _meterType == 'prepaid' ? 'Prepaid' : 'Postpaid',
      'Amount': '₦$formattedAmount',
      'Date': DateTime.now().toString().split('.')[0],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'pay_electricity.php'),
        body: {
          'token': token,
          'service_id': _selectedDiscoId.toString(),
          'meter_type': _meterType,
          'meter': _meterController.text.trim(),
          'phone': _phoneController.text.trim(),
          'amount': _amountController.text.trim(),
          'pin': _pinController.text.trim(),
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        txData['Status'] = 'Successful';
        if (data['token'] != null) txData['Token'] = data['token'];
        _navigateToStatus(true, data['message'] ?? 'Payment processed.', txData);
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
        if (isSuccess) {
          setState(() {
            _meterController.clear();
            _phoneController.clear();
            _amountController.clear();
            _isVerified = false;
            _verifiedName = null;
          });
        }
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
        title: Text('Electricity', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text('1. Distribution Company', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _isLoadingDiscos
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Container(
                  decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _selectedDiscoId,
                      isExpanded: true,
                      hint: Text('Select your DISCO', style: TextStyle(color: Colors.grey.shade500)),
                      dropdownColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      items: _discos.map<DropdownMenuItem<int>>((d) {
                        return DropdownMenuItem<int>(value: d['id'] as int, child: Text(d['name'].toString(), style: TextStyle(color: isDark ? Colors.white : Colors.black87)));
                      }).toList(),
                      onChanged: (val) {
                        final disco = _discos.firstWhere((d) => d['id'] == val);
                        setState(() {
                          _selectedDiscoId = val;
                          _selectedDiscoName = disco['name'].toString();
                          _isVerified = false;
                          _verifiedName = null;
                        });
                      },
                    ),
                  ),
                ),
            const SizedBox(height: 24),
            Text('2. Meter Type', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMeterTypeChip('prepaid', 'Prepaid', primaryColor, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildMeterTypeChip('postpaid', 'Postpaid', primaryColor, isDark)),
              ],
            ),
            const SizedBox(height: 24),
            Text('3. Meter Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    child: TextField(
                      controller: _meterController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.speed, color: Colors.grey.shade400, size: 20),
                        hintText: '45145984782',
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
                    onPressed: _isVerifying ? null : _verifyMeter,
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: _isVerifying
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            if (_isVerified && _verifiedName != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text('✓ $_verifiedName', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            const SizedBox(height: 24),
            Text('4. Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                maxLength: 11,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: Icon(Icons.smartphone, color: Colors.grey.shade400, size: 20),
                  hintText: 'e.g 08012345678',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('5. Amount (₦)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              child: TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  prefixIcon: Icon(Icons.payments_outlined, color: Colors.grey.shade400, size: 20),
                  hintText: 'Min ₦500',
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

  Widget _buildMeterTypeChip(String value, String label, Color primaryColor, bool isDark) {
    final isSelected = _meterType == value;
    return GestureDetector(
      onTap: () => setState(() { _meterType = value; _isVerified = false; _verifiedName = null; }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300), width: isSelected ? 2 : 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.grey.shade500))),
      ),
    );
  }
}
