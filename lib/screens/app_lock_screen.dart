import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import 'dashboard_screen.dart';

class AppLockScreen extends StatefulWidget {
  final bool isSetup;
  final bool isFromResume;
  final VoidCallback? onSuccess;

  const AppLockScreen({
    Key? key,
    this.isSetup = false,
    this.isFromResume = false,
    this.onSuccess,
  }) : super(key: key);

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  String _enteredPin = '';
  String _firstPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  bool _useBiometric = false;

  @override
  void initState() {
    super.initState();
    if (!widget.isSetup) {
      _checkBiometricSupport();
    }
  }

  Future<void> _checkBiometricSupport() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _useBiometric = prefs.getBool('use_biometric') ?? false;
    });
    
    if (_useBiometric) {
      try {
        final canCheck = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
        if (canCheck && mounted) {
          _authenticate();
        }
      } catch (e) {
        // Do not block UI if checks fail
      }
    }
  }

  Future<void> _authenticate() async {
    try {
      final authenticated = await _auth.authenticate(
        localizedReason: 'Scan your fingerprint to unlock the app',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
          useErrorDialogs: true,
        ),
      );
      if (authenticated) {
        _unlockSuccess();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fingerprint Error: ${e.message ?? 'Unknown error'}'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fingerprint hardware not available or not configured.'), 
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    }
  }

  void _onKeyPressed(String value) {
    if (_enteredPin.length < 6) {
      setState(() {
        _enteredPin += value;
        _hasError = false;
      });
      if (_enteredPin.length == 6) {
        _processPin();
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isNotEmpty) {
      setState(() {
        _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1);
        _hasError = false;
      });
    }
  }

  Future<void> _processPin() async {
    final prefs = await SharedPreferences.getInstance();

    if (widget.isSetup) {
      if (!_isConfirming) {
        setState(() {
          _firstPin = _enteredPin;
          _enteredPin = '';
          _isConfirming = true;
        });
      } else {
        if (_enteredPin == _firstPin) {
          await prefs.setString('app_lock_pin', _enteredPin);
          await prefs.setBool('app_lock_enabled', true);
          await prefs.setInt('lock_setting', 2); // Default to "Always Ask"
          
          final hardwareSupport = await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
          if (hardwareSupport && mounted) {
            _showBiometricPrompt(prefs);
          } else {
            _finishSetup();
          }
        } else {
          setState(() {
            _hasError = true;
            _enteredPin = '';
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PINs do not match. Try again.'), backgroundColor: Colors.red));
        }
      }
    } else {
      final savedPin = prefs.getString('app_lock_pin');
      if (_enteredPin == savedPin) {
        _unlockSuccess();
      } else {
        setState(() {
          _hasError = true;
          _enteredPin = '';
        });
      }
    }
  }

  void _showBiometricPrompt(SharedPreferences prefs) {
    final primaryColor = Theme.of(context).primaryColor;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, size: 60, color: primaryColor),
              const SizedBox(height: 16),
              const Text('Enable Fingerprint?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              const Text('Use your device fingerprint scanner for a faster and more secure login.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        prefs.setBool('use_biometric', false);
                        Navigator.pop(context);
                        _finishSetup();
                      },
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('No, Thanks', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        prefs.setBool('use_biometric', true);
                        Navigator.pop(context);
                        _finishSetup();
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('Enable', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }

  void _finishSetup() {
    if (widget.onSuccess != null) {
      widget.onSuccess!();
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  void _unlockSuccess() {
    if (widget.isFromResume) {
      Navigator.pop(context); 
    } else if (widget.onSuccess != null) {
      widget.onSuccess!(); 
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const DashboardScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String titleText = widget.isSetup ? (_isConfirming ? 'Confirm 6-Digit PIN' : 'Create 6-Digit App PIN') : 'Enter App PIN';

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      appBar: widget.isSetup
          ? AppBar(elevation: 0, backgroundColor: Colors.transparent, leading: IconButton(icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black), onPressed: () => Navigator.pop(context)))
          : null,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline, size: 50, color: primaryColor),
                  const SizedBox(height: 16),
                  Text(titleText, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 30),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(6, (index) {
                      bool isFilled = index < _enteredPin.length;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 16, height: 16,
                        decoration: BoxDecoration(shape: BoxShape.circle, color: isFilled ? primaryColor : Colors.transparent, border: Border.all(color: _hasError ? Colors.red : (isFilled ? primaryColor : Colors.grey), width: 2)),
                      );
                    }),
                  ),
                  if (_hasError && !widget.isSetup)
                    const Padding(padding: EdgeInsets.only(top: 16), child: Text('Incorrect PIN', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))),
                ],
              ),
            ),
            
            Container(
              padding: const EdgeInsets.only(bottom: 40, left: 40, right: 40),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                childAspectRatio: 1.4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildNumBtn('1'), _buildNumBtn('2'), _buildNumBtn('3'),
                  _buildNumBtn('4'), _buildNumBtn('5'), _buildNumBtn('6'),
                  _buildNumBtn('7'), _buildNumBtn('8'), _buildNumBtn('9'),
                  _buildBiometricOrEmpty(), _buildNumBtn('0'), _buildBackspace(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNumBtn(String num) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: () => _onKeyPressed(num),
      borderRadius: BorderRadius.circular(40),
      child: Center(child: Text(num, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87))),
    );
  }

  Widget _buildBackspace() {
    return InkWell(
      onTap: _onBackspace,
      borderRadius: BorderRadius.circular(40),
      child: Center(child: Icon(Icons.backspace_outlined, size: 28, color: Theme.of(context).primaryColor)),
    );
  }

  Widget _buildBiometricOrEmpty() {
    if (!widget.isSetup && _useBiometric) {
      return InkWell(
        onTap: _authenticate,
        borderRadius: BorderRadius.circular(40),
        child: Center(child: Icon(Icons.fingerprint, size: 36, color: Theme.of(context).primaryColor)),
      );
    }
    return const SizedBox.shrink();
  }
}
