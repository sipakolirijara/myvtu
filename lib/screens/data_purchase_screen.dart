import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DataPurchaseScreen extends StatefulWidget {
  const DataPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<DataPurchaseScreen> createState() => _DataPurchaseScreenState();
}

class _DataPurchaseScreenState extends State<DataPurchaseScreen> {
  String _selectedNetwork = '';
  final _phoneController = TextEditingController();
  
  bool _isLoadingPlans = false;
  bool _isPurchasing = false;
  
  List<dynamic> _allPlans = [];
  List<dynamic> _filteredPlans = [];
  String? _selectedPlanId;

  // We fetch all data plans from the server when the screen loads
  @override
  void initState() {
    super.initState();
    _fetchPlans();
  }

  Future<void> _fetchPlans() async {
    setState(() => _isLoadingPlans = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';

      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_data_plans.php'),
        body: {'token': token},
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _allPlans = data['plans'];
          });
        }
      }
    } catch (e) {
      // Silently fail for now, user will see empty dropdowns
    } finally {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  // Filter plans when the user taps a network chip (MTN, AIRTEL, etc.)
  void _onNetworkSelected(String network) {
    setState(() {
      _selectedNetwork = network;
      _selectedPlanId = null; // Reset plan selection
      _filteredPlans = _allPlans.where((plan) => 
        plan['network'].toString().toUpperCase() == network.toUpperCase()
      ).toList();
    });
  }

  Future<void> _buyData() async {
    if (_selectedNetwork.isEmpty || _phoneController.text.length < 10 || _selectedPlanId == null) {
      _showError('Please select a network, plan, and enter a valid phone number.');
      return;
    }

    setState(() => _isPurchasing = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';

      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/buy_data.php'),
        body: {
          'token': token,
          'network': _selectedNetwork,
          'plan_id': _selectedPlanId.toString(),
          'phone': _phoneController.text.trim(),
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          _showSuccess(data['message'] ?? 'Transaction Successful!');
          setState(() {
            _phoneController.clear();
            _selectedPlanId = null;
          });
        } else {
          _showError(data['message'] ?? 'Transaction failed.');
        }
      } else {
        _showError('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Buy Internet Data', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('1. Select Network'),
            const SizedBox(height: 12),
            _buildNetworkSelector(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('2. Phone Number'),
            const SizedBox(height: 12),
            _buildTextField(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('3. Data Plan'),
            const SizedBox(height: 12),
            _isLoadingPlans 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF7351FF)))
              : _buildPlanDropdown(),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _buyData,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7351FF),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                ),
                child: _isPurchasing
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Buy Data Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87));
  }

  Widget _buildNetworkSelector() {
    final networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: networks.map((network) {
        final isSelected = _selectedNetwork == network;
        return GestureDetector(
          onTap: () => _onNetworkSelected(network),
          child: Container(
            width: 75,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF7351FF).withOpacity(0.1) : Colors.white,
              border: Border.all(
                color: isSelected ? const Color(0xFF7351FF) : Colors.grey.shade300,
                width: isSelected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                network,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF7351FF) : Colors.grey.shade600),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(Icons.smartphone, color: Colors.grey.shade400, size: 20),
          hintText: '08012345678',
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildPlanDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(
            _selectedNetwork.isEmpty ? 'Select a network first' : 'Choose a data bundle',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          value: _selectedPlanId,
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
          items: _filteredPlans.map<DropdownMenuItem<String>>((dynamic plan) {
            return DropdownMenuItem<String>(
              value: plan['id'].toString(),
              child: Text('${plan['plan_name']} - ₦${plan['retail_price']}'),
            );
          }).toList(),
          onChanged: _selectedNetwork.isEmpty ? null : (String? newValue) {
            setState(() {
              _selectedPlanId = newValue;
            });
          },
        ),
      ),
    );
  }
}
