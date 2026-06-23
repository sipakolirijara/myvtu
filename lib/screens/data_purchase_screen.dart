import 'package:flutter/material.dart';

class DataPurchaseScreen extends StatefulWidget {
  const DataPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<DataPurchaseScreen> createState() => _DataPurchaseScreenState();
}

class _DataPurchaseScreenState extends State<DataPurchaseScreen> {
  String _selectedNetwork = '';
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: AppBar(
        title: const Text(
          'Buy Internet Data',
          style: TextStyle(
            color: Color(0xFF1E1E1E),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
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
              _buildTextField(Icons.smartphone, '08012345678', TextInputType.phone),
              const SizedBox(height: 24),
              
              _buildSectionTitle('3. Data Category'),
              const SizedBox(height: 12),
              _buildDropdown('Select a category (e.g., SME, Gifting)'),
              const SizedBox(height: 24),
              
              _buildSectionTitle('4. Data Plan'),
              const SizedBox(height: 12),
              _buildDropdown('Choose a data bundle'),
              const SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7351FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 5,
                    shadowColor: const Color(0xFF7351FF).withOpacity(0.5),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.bolt, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Buy Data Now',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Colors.black87,
      ),
    );
  }

  Widget _buildNetworkSelector() {
    final networks = ['MTN', 'AIRTEL', 'GLO', '9MOBILE'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: networks.map((network) {
        final isSelected = _selectedNetwork == network;
        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedNetwork = network;
            });
          },
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
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? const Color(0xFF7351FF) : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTextField(IconData icon, String hint, TextInputType type) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: TextField(
        keyboardType: type,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown(String hint) {
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
            hint,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
          ),
          icon: Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade400),
          items: const [], // To be populated later via API
          onChanged: (value) {},
        ),
      ),
    );
  }
}
