import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'data_purchase_screen.dart';
import 'airtime_purchase_screen.dart';
import 'cable_purchase_screen.dart';
import 'electricity_purchase_screen.dart';
import 'exam_pin_purchase_screen.dart';
import 'fund_wallet_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  DateTime? currentBackPressTime;

  List<Widget> get _screens => [
    DashboardHomeView(
      onNavigateToProfile: () => setState(() => _currentIndex = 3),
      onNavigateToHistory: () => setState(() => _currentIndex = 2),
    ),
    const ServicesPlaceholderView(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  // 1. Double tap back button to exit
  Future<bool> onWillPop() {
    DateTime now = DateTime.now();
    if (currentBackPressTime == null || now.difference(currentBackPressTime!) > const Duration(seconds: 2)) {
      currentBackPressTime = now;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)));
      return Future.value(false);
    }
    return Future.value(true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: onWillPop,
      child: Scaffold(
        body: IndexedStack(index: _currentIndex, children: _screens),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          selectedItemColor: Theme.of(context).primaryColor,
          unselectedItemColor: Colors.grey,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          type: BottomNavigationBarType.fixed,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Services'),
            BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'History'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }
}

class ServicesPlaceholderView extends StatelessWidget {
  const ServicesPlaceholderView({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('All Services', style: TextStyle(fontWeight: FontWeight.bold))),
      body: const Center(child: Text('Service categories will be configured here soon.', style: TextStyle(color: Colors.grey))),
    );
  }
}

class DashboardHomeView extends StatefulWidget {
  final VoidCallback onNavigateToProfile; 
  final VoidCallback onNavigateToHistory; 
  
  const DashboardHomeView({
    Key? key, 
    required this.onNavigateToProfile,
    required this.onNavigateToHistory,
  }) : super(key: key);

  @override
  State<DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<DashboardHomeView> {
  bool _isBalanceHidden = false;
  String _firstName = 'User';
  String _balance = '0.00';
  String _bankName = 'Loading...';
  String _accountNumber = 'Loading...';
  String _appName = 'VTU App';
  bool _isLoading = true;
  bool _isCopied = false;

  @override
  void initState() {
    super.initState();
    _loadBalanceVisibility(); // 2. Load persisted hidden state
    _fetchDashboardData();
    _enforceSecurityPin();
  }

  String _formatBalance(String balance) {
    double value = double.tryParse(balance) ?? 0.0;
    String formatted = value.toStringAsFixed(2);
    List<String> parts = formatted.split('.');
    String wholePart = parts[0];
    String decimalPart = parts.length > 1 ? parts[1] : '00';

    bool isNegative = wholePart.startsWith('-');
    if (isNegative) wholePart = wholePart.substring(1);

    String reversed = wholePart.split('').reversed.join('');
    List<String> chunks = [];
    for (int i = 0; i < reversed.length; i += 3) {
      chunks.add(reversed.substring(i, i + 3 > reversed.length ? reversed.length : i + 3));
    }
    String withCommas = chunks.join(',').split('').reversed.join('');

    return '${isNegative ? '-' : ''}$withCommas.$decimalPart';
  }

  Future<void> _loadBalanceVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBalanceHidden = prefs.getBool('hide_balance') ?? false;
    });
  }

  void _toggleBalance() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isBalanceHidden = !_isBalanceHidden;
      prefs.setBool('hide_balance', _isBalanceHidden); // Persist user choice
    });
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      
      setState(() {
        _appName = prefs.getString('app_name') ?? 'VTU App';
      });

      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_dashboard.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() {
            _firstName = data['first_name'];
            _balance = data['balance'];
            _bankName = data['bank_name'];
            _accountNumber = data['account_number'];
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _enforceSecurityPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'get_profile.php'), body: {'token': token});
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['has_pin'] == false && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showMandatoryPinSetup());
        }
      }
    } catch (_) {}
  }

  void _showMandatoryPinSetup() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isSaving = false;
    String? errorMessage;
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
        onWillPop: () async => false,
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.lock, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Set Payment PIN', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.withOpacity(0.3))),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(child: Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))),
                        ],
                      ),
                    ),
                  ],
                  const Text('Please set up your 4-digit Payment PIN to authorize transactions.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),
                  Text('Enter New PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  TextField(
                    controller: newPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, 
                    style: TextStyle(letterSpacing: 8.0, fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(filled: true, fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 12),
                  Text('Confirm PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
                  TextField(
                    controller: confirmPinController, obscureText: true, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, 
                    style: TextStyle(letterSpacing: 8.0, fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
                    decoration: InputDecoration(filled: true, fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade100, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity, height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (newPinController.text.length != 4 || newPinController.text != confirmPinController.text) {
                        setDialogState(() => errorMessage = 'PINs must be exactly 4 digits and match.');
                        return;
                      }
                      setDialogState(() {
                        isSaving = true;
                        errorMessage = null;
                      });
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('api_token') ?? '';
                        final response = await http.post(Uri.parse(ApiConfig.baseUrl + 'set_pin.php'), body: {'token': token, 'new_pin': newPinController.text, 'current_pin': ''});
                        final data = json.decode(response.body);
                        if (data['success']) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment PIN successfully configured!'), backgroundColor: Colors.green));
                        } else {
                          setDialogState(() => errorMessage = data['message']);
                        }
                      } catch (e) {
                        setDialogState(() => errorMessage = 'Network error.');
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Payment PIN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            );
          }
        ),
      ),
    );
  }

  // 4. Solid, smaller ATM Dots
  Widget _buildAtmDot(Color color) {
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.0),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    List<String> nameParts = _appName.split(' ');
    String firstWord = nameParts.isNotEmpty ? nameParts[0] : 'App';
    String secondWord = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(firstWord, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(secondWord, style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: widget.onNavigateToProfile,
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(backgroundColor: primaryColor.withOpacity(0.2), child: Icon(Icons.person, color: primaryColor)),
            ),
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDashboardData,
        color: primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Welcome back, $_firstName', style: const TextStyle(color: Colors.grey, fontSize: 14)),
              const SizedBox(height: 20),
              
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))],
                ),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        const SizedBox(height: 8),
                        _isLoading 
                          ? const SizedBox(height: 32, width: 32, child: CircularProgressIndicator(color: Colors.white))
                          : Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: _isBalanceHidden 
                                    // 5. Hide Naira sign completely -> "****"
                                    ? const Text('****', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 2.0))
                                    : RichText(
                                        text: TextSpan(
                                          children: [
                                            // 6. Reduced size to 26
                                            const TextSpan(text: '₦', style: TextStyle(fontFamily: 'Roboto', color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold)),
                                            TextSpan(text: _formatBalance(_balance), style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                                          ]
                                        )
                                      ),
                                ),
                                // 3. Toggle view moved directly next to the amount
                                GestureDetector(
                                  onTap: _toggleBalance, 
                                  child: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white, size: 24)
                                ),
                              ],
                            ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(child: Text('$_accountNumber ($_bankName)', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                            GestureDetector(
                              onTap: () async {
                                await Clipboard.setData(ClipboardData(text: _accountNumber));
                                setState(() => _isCopied = true);
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account details copied!')));
                                await Future.delayed(const Duration(seconds: 2));
                                if (mounted) setState(() => _isCopied = false);
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 300),
                                child: Icon(
                                  _isCopied ? Icons.check_circle : Icons.copy,
                                  key: ValueKey<bool>(_isCopied),
                                  color: _isCopied ? Colors.greenAccent : Colors.white70,
                                  size: 18
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                    // 4. ATM Dots: Top Right, solid colors, separated by 4px gap, smaller size
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildAtmDot(Colors.red),
                          const SizedBox(width: 4),
                          _buildAtmDot(Colors.orange),
                          const SizedBox(width: 4),
                          _buildAtmDot(Colors.yellow),
                        ],
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : const Color(0xFF1E1E1E))),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildServiceTile(context, Icons.phone_android, 'Airtime', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AirtimePurchaseScreen()))),
                  _buildServiceTile(context, Icons.wifi, 'Data Plans', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPurchaseScreen()))),
                  _buildServiceTile(context, Icons.tv, 'Cable TV', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CablePurchaseScreen()))),
                  _buildServiceTile(context, Icons.bolt, 'Electricity', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ElectricityPurchaseScreen()))),
                  _buildServiceTile(context, Icons.school, 'Exam Pins', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPinPurchaseScreen()))),
                  _buildServiceTile(context, Icons.account_balance_wallet, 'Fund Wallet', () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FundWalletScreen()))),
                  _buildServiceTile(context, Icons.receipt_long, 'Receipts', widget.onNavigateToHistory),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
