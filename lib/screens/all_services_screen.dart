import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'data_purchase_screen.dart';
import 'airtime_purchase_screen.dart';
import 'cable_purchase_screen.dart';
import 'electricity_purchase_screen.dart';
import 'exam_pin_purchase_screen.dart';

class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({Key? key}) : super(key: key);

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  Map<String, List<dynamic>> _groupedServices = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final response = await http.get(Uri.parse(ApiConfig.baseUrl + 'get_active_services.php'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && mounted) {
          Map<String, List<dynamic>> grouped = {};
          for (var service in data['services']) {
            String group = service['service_group'];
            if (!grouped.containsKey(group)) grouped[group] = [];
            grouped[group]!.add(service);
          }
          setState(() {
            _groupedServices = grouped;
            _isLoading = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getIconFromName(String iconName) {
    switch (iconName) {
      case 'phone_android': return Icons.phone_android;
      case 'wifi': return Icons.wifi;
      case 'tv': return Icons.tv;
      case 'bolt': return Icons.bolt;
      case 'school': return Icons.school;
      case 'verified_user': return Icons.verified_user;
      case 'contact_page': return Icons.contact_page;
      case 'sports_soccer': return Icons.sports_soccer;
      default: return Icons.grid_view_rounded;
    }
  }

  void _handleServiceNavigation(String slug) {
    switch (slug) {
      case 'airtime': Navigator.push(context, MaterialPageRoute(builder: (_) => const AirtimePurchaseScreen())); break;
      case 'data': Navigator.push(context, MaterialPageRoute(builder: (_) => const DataPurchaseScreen())); break;
      case 'cable': Navigator.push(context, MaterialPageRoute(builder: (_) => const CablePurchaseScreen())); break;
      case 'electricity': Navigator.push(context, MaterialPageRoute(builder: (_) => const ElectricityPurchaseScreen())); break;
      case 'exam_pins': Navigator.push(context, MaterialPageRoute(builder: (_) => const ExamPinPurchaseScreen())); break;
      default: ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Module coming soon!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      appBar: AppBar(title: const Text('All Services', style: TextStyle(fontWeight: FontWeight.bold))),
      body: _isLoading 
        ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
        : ListView(
            padding: const EdgeInsets.all(20),
            children: _groupedServices.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(entry.key.toUpperCase(), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade500, letterSpacing: 1.2)),
                  ),
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 3,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    children: entry.value.map((service) {
                      return _buildServiceTile(service);
                    }).toList(),
                  ),
                ],
              );
            }).toList(),
          ),
    );
  }

  Widget _buildServiceTile(dynamic service) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _handleServiceNavigation(service['service_slug']),
      child: Container(
        decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade100)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(_getIconFromName(service['icon_name']), color: Theme.of(context).primaryColor, size: 28),
            const SizedBox(height: 8),
            Text(service['service_name'], textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: isDark ? Colors.white70 : Colors.black87)),
          ],
        ),
      ),
    );
  }
}
