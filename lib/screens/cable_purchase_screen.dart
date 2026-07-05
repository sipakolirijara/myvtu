import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class CablePurchaseScreen extends StatefulWidget {
  const CablePurchaseScreen({Key? key}) : super(key: key);

  @override
  State<CablePurchaseScreen> createState() => _CablePurchaseScreenState();
}

class _CablePurchaseScreenState extends State<CablePurchaseScreen> {
  int? _selectedServiceId;
  String _selectedNetworkName = '';
  String? _selectedPlanId;
  final _smartCardController = TextEditingController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController();

  bool _isLoadingPlans = false;
  bool _isVerifying = false;
  bool _isPurchasing = false;
  bool _isVerified = false;
  String? _verifiedName;
  String _balance = '...';

  List<dynamic> _allPlans = [];
  List<dynamic> _filteredPlans = [];
  List<String> _availableNetworks = [];

  @override
  void initState() {
    super.initState();
    _fetchBalance();
    _fetchPlans();
    _smartCardController.addListener(() {
      setState(() { _isVerified = false; _verifiedName = null; });
    });
    _phoneController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _smartCardController.dispose();
    _phoneController.dispose();
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

  Future<void> _fetchPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_cable_plans.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _allPlans = data['plans'];
            _availableNetworks = _allPlans.map((p) => p['network'].toString()).toSet().toList();
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Could not load cable plans.'), backgroundColor: Colors.red));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  void _onNetworkSelected(String network) {
    final plansForNetwork = _allPlans.where((p) => p['network'].toString() == network).toList();
    final serviceId = plansForNetwork.isNotEmpty ? plansForNetwork.first['service_id'] as int : null;
    setState(() {
      _selectedNetworkName = network;
      _selectedServiceId = serviceId;
      _selectedPlanId = null;
      _filteredPlans = plansForNetwork;
    });
  }

  Color _getNetworkColor(String network) {
    switch (network.toUpperCase()) {
      case 'DSTV': return const Color(0xFF0047AB);
      case 'GOTV': return const Color(0xFF00A651);
      case 'STARTIMES': return const Color(0xFFE30613);
      default: return Colors.grey;
    }
  }

  bool get _isValid {
    if (_selectedServiceId == null) return false;
    if (_selectedPlanId == null) return false;
    if (_smartCardController.text.length < 5) return false;
    if (_phoneController.text.length != 11) return false;
    if (!_isVerified) return false;
    return true;
  }

  Future<void> _verifySmartCard() async {
    if (_selectedServiceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a cable provider first')));
      return;
    }
    if (_smartCardController.text.length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid smart card number')));
      return;
    }
    setState(() => _isVerifying = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'verify_cable_iuc.php'),
        body: {'token': token, 'service_id': _selectedServiceId.toString(), 'iuc': _smartCardController.text.trim()},
      );
      final data = json.decode(response.body);
      if (mounted) {
        setState(() {
          _isVerified = data['success'] == true;
          _verifiedName = data['customer_name'];
        });
        if (!_isVerified) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Could not verify smart card number.'), backgroundColor: Colors.red));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification request failed.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  void _showSelectorModal({required String title, required List<dynamic> items, required Function(dynamic) onSelect, bool isPlan = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (context, index) => Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      onTap: () {
                        Navigator.pop(context);
                        onSelect(item);
                      },
                      title: Text(isPlan ? item['plan_name'] : item.toString(), style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                      trailing: isPlan ? Text('₦${item['retail_price']}', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 15)) : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    );
                  },
                ),
              ),
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

  void _showConfirmationModal() {
    final selectedPlan = _allPlans.firstWhere((p) => p['id'].toString() == _selectedPlanId);
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
              Text('Confirm Subscription', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 20),
              _buildConfirmRow('Provider', _selectedNetworkName, primaryColor, isDark),
              _buildConfirmRow('Smart Card', _smartCardController.text, primaryColor, isDark),
              if (_verifiedName != null) _buildConfirmRow('Name', _verifiedName!, primaryColor, isDark),
              _buildConfirmRow('Plan', selectedPlan['plan_name'], primaryColor, isDark),
              _buildConfirmRow('Amount', '₦${selectedPlan['retail_price']}', primaryColor, isDark, isAmount: true),
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
                      _buyCable();
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

  Future<void> _buyCable() async {
    setState(() => _isPurchasing = true);
    final selectedPlan = _allPlans.firstWhere((p) => p['id'].toString() == _selectedPlanId);
    final txData = {
      'Service': 'Cable Subscription',
      'Provider': _selectedNetworkName,
      'Smart Card': _smartCardController.text,
      'Plan': selectedPlan['plan_name'],
      'Amount': '₦${selectedPlan['retail_price']}',
      'Date': DateTime.now().toString().split('.')[0],
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'pay_cable.php'),
        body: {
          'token': token,
          'service_id': _selectedServiceId.toString(),
          'plan_id': _selectedPlanId.toString(),
          'smart_card': _smartCardController.text.trim(),
          'phone': _phoneController.text.trim(),
          'pin': _pinController.text.trim(),
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        txData['Status'] = 'Successful';
        _navigateToStatus(true, data['message'] ?? 'Subscription processed.', txData);
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
            _smartCardController.clear();
            _phoneController.clear();
            _selectedPlanId = null;
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
    final selectedPlan = _selectedPlanId != null ? _allPlans.firstWhere((p) => p['id'].toString() == _selectedPlanId) : null;

    return Scaffold(
      appBar: AppBar(
        title: Text('Cable TV', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
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
            Text('1. Select Provider', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            _isLoadingPlans
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: _availableNetworks.map((network) {
                    final isSelected = _selectedNetworkName == network;
                    final netColor = _getNetworkColor(network);
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () => _onNetworkSelected(network),
                        child: Container(
                          width: 90,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? netColor : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                            border: Border.all(color: isSelected ? netColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300), width: isSelected ? 2 : 1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(child: Text(network, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? Colors.white : Colors.grey.shade500))),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            const SizedBox(height: 24),
            Text('2. Smart Card / IUC Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                    child: TextField(
                      controller: _smartCardController,
                      keyboardType: TextInputType.number,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.tv, color: Colors.grey.shade400, size: 20),
                        hintText: '7042946745',
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
                    onPressed: _isVerifying ? null : _verifySmartCard,
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
            Text('3. Phone Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
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
            Text('4. Subscription Plan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            InkWell(
              onTap: () {
                if (_selectedServiceId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a provider first')));
                  return;
                }
                _showSelectorModal(
                  title: 'Select Plan',
                  items: _filteredPlans,
                  isPlan: true,
                  onSelect: (plan) => setState(() => _selectedPlanId = plan['id'].toString()),
                );
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(selectedPlan != null ? '${selectedPlan['plan_name']} - ₦${selectedPlan['retail_price']}' : 'Tap to select a plan', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 15, fontWeight: FontWeight.w500))),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade500),
                  ],
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
}
