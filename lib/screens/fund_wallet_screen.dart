import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'kyc_setup_screen.dart';

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

  // Tab State
  String _activeTab = ''; 
  
  // Card Funding State
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
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KycSetupScreen()));
        }
      } else {
        if (mounted) setState(() { _errorMessage = data['message'] ?? 'Could not load funding methods.'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Network connection timed out.'; _isLoading = false; });
    }
  }

  void _setDefaultTabAndGateway() {
    if (hasMonnify) {
      _activeTab = 'auto';
    } else if (hasCard) {
      _activeTab = 'card';
    } else if (hasManual) {
      _activeTab = 'manual';
    }

    if (hasPaystack) {
      _selectedGateway = 'paystack';
    } else if (hasFlutterwave) {
      _selectedGateway = 'flutterwave';
    }
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
    
    if (config['charge_type'] == 'percentage') {
      return amount * (chargeValue / 100);
    } else {
      return chargeValue;
    }
  }

  String _formatFeeText(String method) {
    if (_providers == null || _providers![method] == null) return "Free";
    final config = _providers![method];
    double chargeValue = (config['charge_value'] ?? 0).toDouble();
    
    if (chargeValue <= 0) return "Free";
    return config['charge_type'] == 'percentage' 
        ? "${chargeValue.toStringAsFixed(1)}%" 
        : "₦${chargeValue.toStringAsFixed(2)}";
  }

  void _copyText(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2), backgroundColor: Colors.green)
    );
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
        body: {
          'token': token,
          'amount': amount.toString(),
          'gateway': _selectedGateway,
        },
      );

      final data = json.decode(response.body);

      if (data['success'] == true && data['checkout_url'] != null) {
        final url = Uri.parse(data['checkout_url']);
        if (!await launchUrl(url, mode: LaunchMode.inAppWebView)) {
          throw Exception('Could not launch payment gateway');
        }
        _amountController.clear();
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
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 60),
            Icon(Icons.error_outline, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(_errorMessage!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _fetchFundingMethods,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.build_circle_outlined, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('Funding Unavailable', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Wallet funding is currently under maintenance.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
        ],
      ),
    );
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          if (hasMonnify) _buildTabItem('auto', 'Auto Transfer', Icons.account_balance, primaryColor, isDark),
          if (hasCard) _buildTabItem('card', 'Pay Online', Icons.credit_card, primaryColor, isDark),
          if (hasManual) _buildTabItem('manual', 'Manual', Icons.menu_book, primaryColor, isDark),
        ],
      ),
    );
  }

  Widget _buildTabItem(String id, String title, IconData icon, Color primaryColor, bool isDark) {
    bool isActive = _activeTab == id;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? primaryColor : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isActive ? [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: isActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? Colors.white : (isDark ? Colors.grey.shade400 : Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAutoTransferTab(Color primaryColor, bool isDark) {
    if (_monnifyAccounts.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text("Virtual accounts are generating or currently unavailable.", style: TextStyle(color: Colors.grey.shade500), textAlign: TextAlign.center),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dedicated Bank Accounts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
        const SizedBox(height: 6),
        Text('Transfers to these accounts are credited instantly.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
        const SizedBox(height: 20),
        
        ..._monnifyAccounts.map((acct) => _buildMonnifyCard(acct, primaryColor, isDark)).toList(),
        
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, color: Colors.blue, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'A gateway fee of ${_formatFeeText('monnify')} applies to automated deposits.',
                  style: TextStyle(fontSize: 12, color: isDark ? Colors.blue.shade300 : Colors.blue.shade700, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMonnifyCard(dynamic acct, Color primaryColor, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.account_balance, color: primaryColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Bank Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                    Text(acct['bank_name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text('Account Number', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(10)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(acct['account_number'] ?? '', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.5)),
                GestureDetector(
                  onTap: () => _copyText(acct['account_number'] ?? '', 'Account Number'),
                  child: Icon(Icons.copy, size: 20, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text('Account Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(acct['account_name'] ?? '', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700)),
        ],
      ),
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
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount to Fund (₦)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              TextField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  prefixText: '₦ ',
                  prefixStyle: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: primaryColor),
                  filled: true,
                  fillColor: isDark ? Colors.black26 : Colors.grey.shade50,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                ),
                onChanged: (val) => setState(() {}),
              ),
              const SizedBox(height: 24),
              
              if (hasPaystack && hasFlutterwave) ...[
                Text('Select Gateway', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _buildGatewaySelector('paystack', 'Paystack', primaryColor, isDark)),
                    const SizedBox(width: 12),
                    Expanded(child: _buildGatewaySelector('flutterwave', 'Flutterwave', primaryColor, isDark)),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Processing Fee', style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                        Text('₦${fee.toStringAsFixed(2)}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: isDark ? Colors.grey.shade300 : Colors.black87)),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200, height: 1),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Charge', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                        Text('₦${total.toStringAsFixed(2)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: primaryColor)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: amount >= 100 && !_isProcessingPayment ? _processCardPayment : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    disabledBackgroundColor: primaryColor.withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: amount >= 100 ? 4 : 0,
                  ),
                  child: _isProcessingPayment
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                    : const Text('Proceed to Payment', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
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
    return GestureDetector(
      onTap: () => setState(() => _selectedGateway = id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? Colors.black26 : Colors.white),
          border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade200), width: 1.5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            title, 
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? primaryColor : (isDark ? Colors.grey.shade400 : Colors.grey.shade600)
            )
          ),
        ),
      ),
    );
  }

  Widget _buildManualTab(Color primaryColor, bool isDark) {
    final instructions = _providers?['manual']?['instructions'] ?? 'Bank details not provided.';
    
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.account_balance_wallet, color: Colors.orange, size: 32),
          ),
          const SizedBox(height: 16),
          Text('Corporate Bank Transfer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 24),
          
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: isDark ? Colors.black26 : Colors.grey.shade50, borderRadius: BorderRadius.circular(16)),
            child: Text(
              instructions,
              style: TextStyle(fontSize: 14, height: 1.6, color: isDark ? Colors.grey.shade300 : Colors.grey.shade700),
            ),
          ),
          
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
              const SizedBox(width: 8),
              Text('Processing Fee: ${_formatFeeText('manual')}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
            ],
          ),
        ],
      ),
    );
  }
}
