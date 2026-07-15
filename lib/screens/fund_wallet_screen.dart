import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'kyc_setup_screen.dart';
import 'payment_webview_screen.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({Key? key}) : super(key: key);

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  bool _isLoading = true;
  bool _isProcessingPayment = false;
  String? _errorMessage;
  
  Map<String, dynamic>? _providers;
  List<dynamic> _monnifyAccounts = [];

  String _activeTab = ''; 
  final TextEditingController _amountController = TextEditingController();
  String _selectedGateway = '';

  @override
  void initState() {
    super.initState();
    _fetchFundingMethods();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _fetchFundingMethods() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}get_funding_methods.php'), 
        body: {'token': token}
      );
      final data = json.decode(response.body);

      if (data['success'] == true) {
        if (mounted) {
          setState(() { 
            _providers = data['providers'];
            _monnifyAccounts = _providers?['monnify']?['accounts'] ?? [];
            _setDefaultTabAndGateway();
            _isLoading = false; 
          });
        }
      } else if (data['kyc_required'] == true) {
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KycSetupScreen()));
      } else {
        if (mounted) setState(() { _errorMessage = data['message'] ?? 'Could not load funding methods.'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Network connection timed out.'; _isLoading = false; });
    }
  }

  void _setDefaultTabAndGateway() {
    if (_activeTab.isEmpty) {
      if (hasMonnify) _activeTab = 'auto';
      else if (hasCard) _activeTab = 'card';
      else if (hasManual) _activeTab = 'manual';
    }
    if (hasPaystack) _selectedGateway = 'paystack';
    else if (hasFlutterwave) _selectedGateway = 'flutterwave';
  }

  bool get hasMonnify => _providers?['monnify']?['is_active'] == true;
  bool get hasPaystack => _providers?['paystack']?['is_active'] == true;
  bool get hasFlutterwave => _providers?['flutterwave']?['is_active'] == true;
  bool get hasManual => _providers?['manual']?['is_active'] == true;
  bool get hasCard => hasPaystack || hasFlutterwave;

  double _getCalculatedFee(double amount, String method) {
    if (_providers == null || _providers![method] == null) return 0.0;
    final config = _providers![method];
    double chargeValue = (config['charge_value'] ?? 0).toDouble();
    return config['charge_type'] == 'percentage' ? amount * (chargeValue / 100) : chargeValue;
  }

  String _formatFeeText(String method) {
    if (_providers == null || _providers![method] == null) return "Free";
    final config = _providers![method];
    double chargeValue = (config['charge_value'] ?? 0).toDouble();
    if (chargeValue <= 0) return "Free";
    return config['charge_type'] == 'percentage' ? "${chargeValue.toStringAsFixed(1)}%" : "₦${chargeValue.toStringAsFixed(2)}";
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied!'), backgroundColor: Colors.green));
  }

  Future<void> _processCardPayment() async {
    double amount = double.tryParse(_amountController.text) ?? 0;
    if (amount < 100) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Minimum amount is ₦100'), backgroundColor: Colors.red));
      return;
    }

    setState(() { _isProcessingPayment = true; });

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}init_card_funding.php'),
        body: {'token': token, 'amount': amount.toString(), 'gateway': _selectedGateway},
      );

      final data = json.decode(response.body);

      if (data['success'] == true && data['checkout_url'] != null) {
        // Navigate to our Custom Webview
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => PaymentWebViewScreen(url: data['checkout_url'], reference: data['reference'])),
        );
        
        if (result == true) {
           _amountController.clear();
           _fetchFundingMethods(); // Refresh balance!
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Failed to initialize payment'), backgroundColor: Colors.red));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error initializing payment.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() { _isProcessingPayment = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fund Wallet', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      ),
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF9FAFB),
      body: RefreshIndicator(
        onRefresh: _fetchFundingMethods,
        color: primaryColor,
        child: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null
            ? _buildErrorState(primaryColor)
            : _providers == null || _providers!.isEmpty
                ? _buildEmptyState()
                : _buildMainContent(primaryColor, isDark),
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Column(children: [const SizedBox(height: 60), Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400), const SizedBox(height: 16), Text(_errorMessage!, textAlign: TextAlign.center), const SizedBox(height: 24), ElevatedButton(onPressed: _fetchFundingMethods, child: const Text('Try Again'))]))),
    );
  }

  Widget _buildEmptyState() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey.shade400), const SizedBox(height: 16), const Text('Funding Unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))]));
  }

  Widget _buildMainContent(Color primaryColor, bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        _buildTabs(primaryColor, isDark),
        const SizedBox(height: 24),
        if (_activeTab == 'auto') _buildAutoTransferTab(primaryColor, isDark),
        if (_activeTab == 'card') _buildCardTab(primaryColor, isDark),
        if (_activeTab == 'manual') _buildManualTab(primaryColor, isDark),
      ],
    );
  }

  Widget _buildTabs(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasMonnify) _buildTabItem('auto', 'Auto Transfer', Icons.account_balance, primaryColor, isDark),
            if (hasCard) _buildTabItem('card', 'Fund with Card', Icons.credit_card, primaryColor, isDark),
            if (hasManual) _buildTabItem('manual', 'Manual', Icons.menu_book, primaryColor, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(String id, String title, IconData icon, Color primaryColor, bool isDark) {
    bool isActive = _activeTab == id;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
        margin: const EdgeInsets.only(right: 4),
        decoration: BoxDecoration(color: isActive ? primaryColor : Colors.transparent, borderRadius: BorderRadius.circular(12)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
            const SizedBox(width: 6),
            Text(title, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w600, color: isActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600))),
          ],
        ),
      ),
    );
  }

  Widget _buildAutoTransferTab(Color primaryColor, bool isDark) {
    if (_monnifyAccounts.isEmpty) return const Center(child: Text("Accounts are generating..."));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._monnifyAccounts.map((acct) => _buildAccountCard(acct['bank_name'], acct['account_number'], acct['account_name'], primaryColor, isDark)).toList(),
      ],
    );
  }

  Widget _buildCardTab(Color primaryColor, bool isDark) {
    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double fee = _getCalculatedFee(amount, _selectedGateway);
    double total = amount + fee;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount to Fund', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('₦', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: primaryColor))),
                  prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  hintText: '1000',
                  hintStyle: TextStyle(fontSize: 20, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: primaryColor, width: 2)),
                ),
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 24),
              if (hasPaystack && hasFlutterwave) ...[
                Row(children: [Expanded(child: _buildGatewaySelector('paystack', 'Paystack', primaryColor, isDark)), const SizedBox(width: 12), Expanded(child: _buildGatewaySelector('flutterwave', 'Flutterwave', primaryColor, isDark))]),
                const SizedBox(height: 24),
              ],
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Processing Fee', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)), Text('₦${fee.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))]), Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 1)), Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Total Charge', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)), Text('₦${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor))])]),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  onPressed: amount >= 100 && !_isProcessingPayment ? _processCardPayment : null,
                  style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                  child: _isProcessingPayment ? const CircularProgressIndicator(color: Colors.white) : const Text('Proceed to Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildGatewaySelector(String id, String title, Color primaryColor, bool isDark) {
    bool isSelected = _selectedGateway == id;
    return GestureDetector(onTap: () => setState(() => _selectedGateway = id), child: Container(padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? Colors.black26 : Colors.white), border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade200)), borderRadius: BorderRadius.circular(12)), child: Center(child: Text(title, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? primaryColor : Colors.grey.shade500)))));
  }

  Widget _buildManualTab(Color primaryColor, bool isDark) {
    final config = _providers?['manual'] ?? {};
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Corporate Bank Transfer', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 6),
        Text('Please transfer funds to the account below.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        _buildAccountCard(config['manual_bank'], config['manual_account'], config['manual_name'], primaryColor, isDark),
        if ((config['instructions'] ?? '').isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
            child: Text(config['instructions'], style: TextStyle(color: isDark ? Colors.grey.shade300 : Colors.grey.shade700, fontSize: 13, height: 1.5)),
          )
        ]
      ],
    );
  }

  Widget _buildAccountCard(String? bankName, String? accNumber, String? accName, Color primaryColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 40, height: 40, decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.account_balance, color: primaryColor, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Bank Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)), Text(bankName ?? 'N/A', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87))])),
            ],
          ),
          const SizedBox(height: 20),
          Text('Account Number', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(accNumber ?? 'N/A', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.5)),
                GestureDetector(onTap: () => _copyText(accNumber ?? '', 'Account Number'), child: Icon(Icons.copy, size: 20, color: Colors.grey.shade500)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Account Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(accName ?? 'N/A', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
        ],
      ),
    );
  }
}
