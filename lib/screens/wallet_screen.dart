import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'transaction_status_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({Key? key}) : super(key: key);

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  List<dynamic> _transactions = [];
  bool _isLoading = true;

  // Filter States
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = 'All';
  DateTimeRange? _selectedDateRange;

  final List<String> _categories = ['All', 'Airtime', 'Data', 'Cable', 'Electricity', 'Fund'];

  @override
  void initState() {
    super.initState();
    _fetchTransactions();
  }

  Future<void> _fetchTransactions() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      
      // Format Dates manually to avoid external package dependencies
      String startDate = '';
      String endDate = '';
      if (_selectedDateRange != null) {
        final start = _selectedDateRange!.start;
        final end = _selectedDateRange!.end;
        startDate = "${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}";
        endDate = "${end.year}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}";
      }

      final response = await http.post(
        Uri.parse('https://vtu.kainuwa.africa/api/mobile/get_transactions.php'),
        body: {
          'token': token,
          'search': _searchController.text.trim(),
          'category': _selectedCategory,
          'start_date': startDate,
          'end_date': endDate,
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          setState(() => _transactions = data['transactions']);
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final primaryColor = Theme.of(context).primaryColor;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _selectedDateRange = picked);
      _fetchTransactions();
    }
  }

  void _openReceipt(dynamic t) {
    final isSuccess = t['status'].toString().toLowerCase() == 'success';
    final amountFormatted = double.tryParse(t['amount'].toString())?.toStringAsFixed(2) ?? '0.00';
    
    final txData = {
      'Service': t['category'].toString().toLowerCase() == 'vtu_purchase' ? 'SERVICE PAYMENT' : t['category'].toString().toUpperCase().replaceAll('_', ' '),
      'Reference': t['reference'] ?? 'N/A',
      'Target/Phone': t['recipient_target'] ?? 'N/A',
      'Amount': '₦$amountFormatted',
      'Date': t['created_at'],
      'Status': t['status'].toString().toUpperCase(),
    };

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionStatusScreen(
          isSuccess: isSuccess,
          message: isSuccess ? 'Transaction was successful' : 'Transaction failed or is pending',
          transactionData: txData,
          onDone: () => Navigator.pop(context),
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
        title: const Text('Wallet History', style: TextStyle(color: Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 20)),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search phone or reference...',
                    prefixIcon: const Icon(Icons.search, color: Colors.grey),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.send, color: Colors.blue),
                      onPressed: _fetchTransactions,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                  ),
                  onSubmitted: (_) => _fetchTransactions(),
                ),
                const SizedBox(height: 12),
                
                // Category & Date Row
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedCategory,
                            isExpanded: true,
                            icon: const Icon(Icons.filter_list, size: 20),
                            items: _categories.map((String cat) {
                              return DropdownMenuItem(value: cat, child: Text(cat, style: const TextStyle(fontSize: 14)));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCategory = val);
                                _fetchTransactions();
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: GestureDetector(
                        onTap: _pickDateRange,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: Icon(Icons.calendar_month, color: primaryColor),
                        ),
                      ),
                    ),
                    if (_selectedDateRange != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          setState(() => _selectedDateRange = null);
                          _fetchTransactions();
                        },
                        child: const Icon(Icons.cancel, color: Colors.redAccent),
                      )
                    ]
                  ],
                ),
              ],
            ),
          ),

          // Transactions List
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator(color: primaryColor))
              : _transactions.isEmpty
                ? const Center(child: Text('No transactions found.', style: TextStyle(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _fetchTransactions,
                    color: primaryColor,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _transactions.length,
                      itemBuilder: (context, index) {
                        final t = _transactions[index];
                        final isCredit = t['type'] == 'credit';
                        final amountStr = double.tryParse(t['amount'].toString())?.toStringAsFixed(2) ?? '0.00';
                        final rawStatus = t['status'].toString().toLowerCase();
                        final statusColor = (rawStatus == 'success' || rawStatus == 'successful') ? Colors.green : (rawStatus == 'pending' ? Colors.orange : Colors.red);
                        final bgStatusColor = isCredit ? Colors.green.withOpacity(0.1) : Colors.red.withOpacity(0.1);
                        
                        return GestureDetector(
                          onTap: () => _openReceipt(t),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: bgStatusColor,
                                  child: Icon(isCredit ? Icons.arrow_downward : Icons.arrow_upward, color: isCredit ? Colors.green : Colors.redAccent, size: 20),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t['category'].toString().toLowerCase() == 'vtu_purchase' ? 'SERVICE PAYMENT' : t['category'].toString().toUpperCase().replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 4),
                                      Text(t['created_at'], style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text('${isCredit ? '+' : '-'}₦$amountStr', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isCredit ? Colors.green : Colors.black87)),
                                    const SizedBox(height: 4),
                                    Text(t['status'].toString().toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor)),
                                  ],
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
