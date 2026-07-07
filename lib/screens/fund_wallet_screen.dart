import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'kyc_setup_screen.dart';

class FundWalletScreen extends StatefulWidget {
  const FundWalletScreen({Key? key}) : super(key: key);

  @override
  State<FundWalletScreen> createState() => _FundWalletScreenState();
}

class _FundWalletScreenState extends State<FundWalletScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  List<dynamic> _accounts = [];

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_virtual_accounts.php'), body: {'token': token});
      final data = json.decode(response.body);

      if (data['success'] == true) {
        if (mounted) setState(() { _accounts = data['accounts'] ?? []; _isLoading = false; });
      } else if (data['kyc_required'] == true) {
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const KycSetupScreen()));
        }
      } else {
        if (mounted) setState(() { _errorMessage = data['message'] ?? 'Could not load virtual accounts.'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _errorMessage = 'Network connection timed out.'; _isLoading = false; });
    }
  }

  void _copyAccountNumber(String accountNumber) {
    Clipboard.setData(ClipboardData(text: accountNumber));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Copied: $accountNumber'), duration: const Duration(seconds: 2)));
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Fund Wallet', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchAccounts,
        color: primaryColor,
        child: _isLoading
          ? SizedBox(height: MediaQuery.of(context).size.height * 0.6, child: Center(child: CircularProgressIndicator(color: primaryColor)))
          : _errorMessage != null
            ? _buildErrorState(primaryColor, isDark)
            : _buildAccountsList(primaryColor, isDark),
      ),
    );
  }

  Widget _buildErrorState(Color primaryColor, bool isDark) {
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
              onPressed: _fetchAccounts,
              icon: const Icon(Icons.refresh, color: Colors.white),
              label: const Text('Try Again', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccountsList(Color primaryColor, bool isDark) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Transfer to any account below', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
          const SizedBox(height: 4),
          Text('Your wallet is credited automatically within seconds.', style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
          const SizedBox(height: 20),
          ..._accounts.map((acct) => _buildAccountCard(acct, primaryColor, isDark)).toList(),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.blue.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.flash_on, color: Colors.blue, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'A standard CBN gateway fee of ₦50 applies to deposits above ₦10,000.',
                    style: TextStyle(fontSize: 12, color: Colors.blue.shade700, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(dynamic acct, Color primaryColor, bool isDark) {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.account_balance, color: primaryColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Bank Name', style: TextStyle(fontSize: 10, color: Colors.grey.shade500, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      Text(acct['bank_name'] ?? '', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                child: const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green)),
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
                Text(acct['account_number'] ?? '', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor, letterSpacing: 1.5)),
                GestureDetector(
                  onTap: () => _copyAccountNumber(acct['account_number'] ?? ''),
                  child: Icon(Icons.copy, size: 18, color: Colors.grey.shade500),
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
}
