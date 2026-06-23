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
  String? _selectedCategory;
  String? _selectedPlanId;
  final _phoneController = TextEditingController();
  
  bool _isLoadingPlans = false;
  bool _isPurchasing = false;
  
  List<dynamic> _allPlans = [];
  List<String> _availableCategories = [];
  List<dynamic> _filteredPlans = [];

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
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() => _allPlans = data['plans']);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoadingPlans = false);
    }
  }

  void _onNetworkSelected(String network) {
    setState(() {
      _selectedNetwork = network;
      _selectedCategory = null;
      _selectedPlanId = null;
      
      // Extract unique categories for this network
      _availableCategories = _allPlans
          .where((plan) => plan['network'] == network)
          .map((plan) => plan['category'].toString())
          .toSet()
          .toList();
    });
  }

  void _onCategorySelected(String? category) {
    setState(() {
      _selectedCategory = category;
      _selectedPlanId = null;
      
      // Filter plans by both network AND category
      _filteredPlans = _allPlans.where((plan) => 
        plan['network'] == _selectedNetwork && plan['category'] == category
      ).toList();
    });
  }

  Future<void> _buyData() async {
    if (_selectedNetwork.isEmpty || _phoneController.text.length < 10 || _selectedPlanId == null) {
      _showError('Please complete all fields.');
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
      );

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
    } catch (e) {
      _showError('Network error connecting to API.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.green));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text('Buy Internet Data', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 20)),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
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
            
            _buildSectionTitle('3. Data Category'),
            const SizedBox(height: 12),
            _buildCategoryDropdown(),
            const SizedBox(height: 24),
            
            _buildSectionTitle('4. Data Plan'),
            const SizedBox(height: 12),
            _isLoadingPlans ? const Center(child: CircularProgressIndicator(color: Color(0xFF7351FF))) : _buildPlanDropdown(),
            const SizedBox(height: 40),
            
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isPurchasing ? null : _buyData,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7351FF), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: _isPurchasing ? const CircularProgressIndicator(color: Colors.white) : const Text('Buy Data Now', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87));

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
              border: Border.all(color: isSelected ? const Color(0xFF7351FF) : Colors.grey.shade300, width: isSelected ? 2 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(child: Text(network, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: isSelected ? const Color(0xFF7351FF) : Colors.grey.shade600))),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField() {
    return Container(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: TextField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(prefixIcon: Icon(Icons.smartphone, color: Colors.grey.shade400, size: 20), hintText: '08012345678', border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 16)),
      ),
    );
  }

  Widget _buildCategoryDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(_selectedNetwork.isEmpty ? 'Select a network first' : 'Select Category (e.g. SME, Gifting)', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          value: _selectedCategory,
          items: _availableCategories.map((String cat) {
            return DropdownMenuItem<String>(value: cat, child: Text(cat));
          }).toList(),
          onChanged: _selectedNetwork.isEmpty ? null : _onCategorySelected,
        ),
      ),
    );
  }

  Widget _buildPlanDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          hint: Text(_selectedCategory == null ? 'Select a category first' : 'Choose a data bundle', style: TextStyle(color: Colors.grey.shade400, fontSize: 14)),
          value: _selectedPlanId,
          items: _filteredPlans.map<DropdownMenuItem<String>>((dynamic plan) {
            return DropdownMenuItem<String>(value: plan['id'].toString(), child: Text('${plan['plan_name']} - ₦${plan['retail_price']}'));
          }).toList(),
          onChanged: _selectedCategory == null ? null : (String? newValue) => setState(() => _selectedPlanId = newValue),
        ),
      ),
    );
  }
}
