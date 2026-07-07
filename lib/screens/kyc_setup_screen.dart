import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'fund_wallet_screen.dart';

class KycSetupScreen extends StatefulWidget {
  const KycSetupScreen({Key? key}) : super(key: key);

  @override
  State<KycSetupScreen> createState() => _KycSetupScreenState();
}

class _KycSetupScreenState extends State<KycSetupScreen> {
  String _idType = 'bvn';
  final _idNumberController = TextEditingController();
  DateTime? _dateOfBirth;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _idNumberController.dispose();
    super.dispose();
  }

  bool get _isValid {
    if (_idNumberController.text.length != 11) return false;
    if (_idType == 'bvn' && _dateOfBirth == null) return false;
    return true;
  }

  Future<void> _pickDateOfBirth() async {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year - 16),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: isDark
                ? ColorScheme.dark(primary: primaryColor, onPrimary: Colors.white, surface: const Color(0xFF1E1E1E), onSurface: Colors.white)
                : ColorScheme.light(primary: primaryColor, onPrimary: Colors.white, surface: Colors.white, onSurface: Colors.black),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('api_token') ?? '';
      final dobString = _dateOfBirth != null
          ? "${_dateOfBirth!.year}-${_dateOfBirth!.month.toString().padLeft(2, '0')}-${_dateOfBirth!.day.toString().padLeft(2, '0')}"
          : '';

      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'kyc_verify.php'),
        body: {
          'token': token,
          'id_type': _idType,
          'id_number': _idNumberController.text.trim(),
          'date_of_birth': dobString,
        },
      );

      final data = json.decode(response.body);
      if (data['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Verified!'), backgroundColor: Colors.green));
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const FundWalletScreen()));
        }
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Verification failed.'), backgroundColor: Colors.red));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network connection timed out.'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Identity Verification', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: primaryColor.withOpacity(0.08), borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(color: primaryColor, shape: BoxShape.circle),
                    child: const Icon(Icons.shield_outlined, color: Colors.white, size: 28),
                  ),
                  const SizedBox(height: 12),
                  Text('Verify your identity', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 6),
                  Text(
                    'To comply with CBN regulations, we need to verify your identity before generating your dedicated virtual account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text('Verification Method', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildMethodChip('bvn', 'BVN', 'Recommended', primaryColor, isDark)),
                const SizedBox(width: 12),
                Expanded(child: _buildMethodChip('nin', 'NIN', 'Coming soon', primaryColor, isDark, disabled: true)),
              ],
            ),
            const SizedBox(height: 24),
            Text('11-Digit Number', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
              child: TextField(
                controller: _idNumberController,
                keyboardType: TextInputType.number,
                maxLength: 11,
                onChanged: (_) => setState(() {}),
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  counterText: '',
                  prefixIcon: Icon(Icons.badge_outlined, color: Colors.grey.shade400, size: 20),
                  hintText: 'e.g 22234567890',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 6.0, left: 4.0),
              child: Text('Dial *565*0# to check your BVN.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
            const SizedBox(height: 24),
            Text('Date of Birth', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDateOfBirth,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade200)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _dateOfBirth == null ? 'Must match your BVN record' : "${_dateOfBirth!.day.toString().padLeft(2, '0')}/${_dateOfBirth!.month.toString().padLeft(2, '0')}/${_dateOfBirth!.year}",
                      style: TextStyle(color: _dateOfBirth == null ? Colors.grey.shade500 : (isDark ? Colors.white : Colors.black87), fontSize: 15, fontWeight: FontWeight.w500),
                    ),
                    Icon(Icons.calendar_today, size: 18, color: Colors.grey.shade500),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: (!_isValid || _isSubmitting) ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  disabledBackgroundColor: primaryColor.withOpacity(0.3),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('Verify My Identity', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMethodChip(String value, String label, String subtitle, Color primaryColor, bool isDark, {bool disabled = false}) {
    final isSelected = _idType == value;
    return GestureDetector(
      onTap: disabled ? null : () => setState(() => _idType = value),
      child: Opacity(
        opacity: disabled ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? primaryColor.withOpacity(0.1) : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
            border: Border.all(color: isSelected ? primaryColor : (isDark ? Colors.grey.shade800 : Colors.grey.shade300), width: isSelected ? 2 : 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isSelected ? primaryColor : (isDark ? Colors.white : Colors.black87))),
              const SizedBox(height: 2),
              Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}
