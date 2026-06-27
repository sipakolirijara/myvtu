import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'wallet_screen.dart';
import 'profile_screen.dart';
import 'data_purchase_screen.dart';
import 'airtime_purchase_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardHomeView(),
    const WalletScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}

class DashboardHomeView extends StatefulWidget {
  const DashboardHomeView({Key? key}) : super(key: key);

  @override
  State<DashboardHomeView> createState() => _DashboardHomeViewState();
}

class _DashboardHomeViewState extends State<DashboardHomeView> {
  bool _isBalanceHidden = false;
  String _firstName = 'User';
  String _balance = '0.00';
  String _bankName = 'Loading...';
  String _accountNumber = 'Loading...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardData();
    _enforceSecurityPin();
  }

  Future<void> _fetchDashboardData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_dashboard.php'),
        body: {'token': token},
      );
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
      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_profile.php'),
        body: {'token': token},
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // If profile loads successfully but user has no PIN
        if (data['success'] == true && data['has_pin'] == false && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showMandatoryPinSetup();
          });
        }
      }
    } catch (_) {}
  }

  void _showMandatoryPinSetup() {
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    bool isSaving = false;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      barrierDismissible: false, // Prevents closing by tapping outside
      builder: (context) => WillPopScope(
        onWillPop: () async => false, // Disables the Android back button
        child: StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Row(
                children: [
                  Icon(Icons.security, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text('Security Lock', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('For your protection, you must create a 4-digit PIN before you can use the application.', style: TextStyle(fontSize: 13, color: Colors.grey)),
                  const SizedBox(height: 20),
                  const Text('Enter New PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: newPinController, 
                    obscureText: true, 
                    keyboardType: TextInputType.number, 
                    maxLength: 4, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(letterSpacing: 8.0, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text('Confirm PIN', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  TextField(
                    controller: confirmPinController, 
                    obscureText: true, 
                    keyboardType: TextInputType.number, 
                    maxLength: 4, 
                    textAlign: TextAlign.center, 
                    style: const TextStyle(letterSpacing: 8.0, fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: isSaving ? null : () async {
                      if (newPinController.text.length != 4) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN must be exactly 4 digits.')));
                        return;
                      }
                      if (newPinController.text != confirmPinController.text) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match. Please try again.')));
                        return;
                      }

                      setDialogState(() => isSaving = true);
                      
                      try {
                        final prefs = await SharedPreferences.getInstance();
                        final token = prefs.getString('api_token') ?? '';
                        final response = await http.post(
                          Uri.parse('https://vtu.kainuwa.africa/api/mobile/set_pin.php'),
                          body: {'token': token, 'new_pin': newPinController.text, 'current_pin': ''},
                        );
                        final data = json.decode(response.body);
                        
                        if (data['success']) {
                          Navigator.pop(context); // Unlocks the app
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Security PIN successfully configured!'), backgroundColor: Colors.green));
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message']), backgroundColor: Colors.red));
                        }
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network error. Check your connection.')));
                      } finally {
                        setDialogState(() => isSaving = false);
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: primaryColor, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    child: isSaving 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                        : const Text('Secure My Account', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                )
              ],
            );
          }
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
        elevation: 0,
        backgroundColor: Colors.transparent,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            const Text('Kainuwa', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            Text('Data', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Icon(Icons.person, color: primaryColor),
              ),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Balance', style: TextStyle(color: Colors.white70, fontSize: 14)),
                        GestureDetector(
                          onTap: () => setState(() => _isBalanceHidden = !_isBalanceHidden),
                          child: Icon(_isBalanceHidden ? Icons.visibility_off : Icons.visibility, color: Colors.white70, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _isLoading 
                      ? const SizedBox(height: 38, width: 38, child: CircularProgressIndicator(color: Colors.white))
                      : Text(_isBalanceHidden ? '₦ •••••' : '₦ $_balance', style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: Text('$_accountNumber ($_bankName)', style: const TextStyle(color: Colors.white70, fontSize: 12), overflow: TextOverflow.ellipsis)),
                        const Icon(Icons.copy, color: Colors.white70, size: 16),
                      ],
                    )
                  ],
                ),
              ),
              const SizedBox(height: 30),
              
              const Text('Services', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E1E))),
              const SizedBox(height: 16),

              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildServiceTile(context, Icons.phone_android, 'Airtime', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AirtimePurchaseScreen()));
                  }),
                  _buildServiceTile(context, Icons.wifi, 'Data Plans', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPurchaseScreen()));
                  }),
                  _buildServiceTile(context, Icons.history, 'History', () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()));
                  }),
                ],
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
