import 'dart:async';
import '../config/api_config.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  // ── Live username availability check state ──────────────
  Timer? _usernameTimer;
  bool _usernameChecking = false;
  bool _usernameAvailable = false;
  String? _usernameHint;
  Color _usernameHintColor = Colors.grey;

  @override
  void dispose() {
    _usernameTimer?.cancel();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _onUsernameChanged(String value) {
    _usernameTimer?.cancel();
    final val = value.trim();

    setState(() {
      _usernameAvailable = false;
      _usernameChecking = false;
      _usernameHint = null;
    });

    if (val.isEmpty) return;

    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(val)) {
      setState(() {
        _usernameHint = '3-20 characters: letters, numbers, underscore only';
        _usernameHintColor = Colors.redAccent;
      });
      return;
    }

    setState(() {
      _usernameChecking = true;
      _usernameHint = 'Checking…';
      _usernameHintColor = Colors.grey;
    });

    _usernameTimer = Timer(const Duration(milliseconds: 600), () async {
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}register.php?check_username=${Uri.encodeQueryComponent(val)}'),
        ).timeout(const Duration(seconds: 10));

        if (!mounted) return;

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          setState(() {
            _usernameChecking = false;
            if (data['taken'] == true) {
              _usernameHint = '✗ Username already taken';
              _usernameHintColor = Colors.redAccent;
              _usernameAvailable = false;
            } else {
              _usernameHint = '✓ Username available';
              _usernameHintColor = Colors.green;
              _usernameAvailable = true;
            }
          });
        } else {
          setState(() {
            _usernameChecking = false;
            _usernameHint = null;
          });
        }
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _usernameChecking = false;
          _usernameHint = null;
        });
      }
    });
  }

  Future<void> _register() async {
    final username = _usernameController.text.trim();

    if (!RegExp(r'^[a-zA-Z0-9_]{3,20}$').hasMatch(username)) {
      _showError('Username must be 3-20 characters, letters/numbers/underscore only');
      return;
    }

    if (!_usernameAvailable) {
      _showError('Please choose an available username');
      return;
    }

    if (_passwordController.text != _confirmController.text) {
      _showError('Passwords do not match');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConfig.baseUrl + 'register.php'),
        body: {
          'first_name': _firstNameController.text.trim(),
          'last_name': _lastNameController.text.trim(),
          'username': username,
          'email': _emailController.text.trim(),
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account created! Please log in.'), backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        } else {
          _showError(data['message'] ?? 'Registration failed');
        }
      } else {
        _showError('Server error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Network error. Please check your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create account',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF111827)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Free forever. No hidden charges.',
                style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              ),
              const SizedBox(height: 30),

              Row(
                children: [
                  Expanded(child: _buildTextField('First name', Icons.person_outline, _firstNameController, false)),
                  const SizedBox(width: 16),
                  Expanded(child: _buildTextField('Last name', Icons.person_outline, _lastNameController, false)),
                ],
              ),
              const SizedBox(height: 16),

              // ── Username field with live availability check ──
              _buildTextField(
                'Username',
                Icons.alternate_email,
                _usernameController,
                false,
                onChanged: _onUsernameChanged,
                suffixIcon: _usernameChecking
                    ? Padding(
                        padding: const EdgeInsets.all(14),
                        child: SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                        ),
                      )
                    : (_usernameHint != null
                        ? Icon(
                            _usernameAvailable ? Icons.check_circle : Icons.error,
                            color: _usernameHintColor,
                            size: 20,
                          )
                        : null),
              ),
              if (_usernameHint != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Text(
                    _usernameHint!,
                    style: TextStyle(fontSize: 12, color: _usernameHintColor, fontWeight: FontWeight.w600),
                  ),
                ),
              const SizedBox(height: 16),

              _buildTextField('Email address', Icons.email_outlined, _emailController, false),
              const SizedBox(height: 16),
              _buildTextField('Phone number', Icons.phone_outlined, _phoneController, false),
              const SizedBox(height: 16),
              _buildTextField('Password', Icons.lock_outline, _passwordController, true),
              const SizedBox(height: 16),
              _buildTextField('Confirm password', Icons.lock_outline, _confirmController, true),

              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 5,
                  ),
                  child: _isLoading
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Create account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String hint,
    IconData icon,
    TextEditingController controller,
    bool isPassword, {
    Function(String)? onChanged,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword && _obscurePassword,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF9CA3AF), size: 20),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: const Color(0xFF9CA3AF), size: 20),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                )
              : suffixIcon,
          hintText: hint,
          hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
