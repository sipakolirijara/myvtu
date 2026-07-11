import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_lock_screen.dart';

class SecuritySettingsScreen extends StatefulWidget {
  const SecuritySettingsScreen({Key? key}) : super(key: key);

  @override
  State<SecuritySettingsScreen> createState() => _SecuritySettingsScreenState();
}

class _SecuritySettingsScreenState extends State<SecuritySettingsScreen> {
  int _lockSetting = 2; // 0=Free, 1=60m, 2=Always
  bool _useBiometric = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lockSetting = prefs.getInt('lock_setting') ?? 2;
      _useBiometric = prefs.getBool('use_biometric') ?? false;
      
      // If app lock was completely disabled previously, set it to "Password-Free" (0)
      if (!(prefs.getBool('app_lock_enabled') ?? false)) {
        _lockSetting = 0;
      }
    });
  }

  Future<void> _updateLockSetting(int value) async {
    final prefs = await SharedPreferences.getInstance();
    
    // If they want to lock (1 or 2), verify they actually have a PIN set
    if (value == 1 || value == 2) {
      final hasPin = prefs.getString('app_lock_pin') != null;
      if (!hasPin) {
        // Route to setup first
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => AppLockScreen(
            isSetup: true,
            onSuccess: () async {
              Navigator.pop(context);
              await _saveLockSetting(prefs, value);
            },
          )
        ));
        return;
      }
    }
    await _saveLockSetting(prefs, value);
  }

  Future<void> _saveLockSetting(SharedPreferences prefs, int value) async {
    setState(() => _lockSetting = value);
    await prefs.setInt('lock_setting', value);
    
    // Keep legacy flag accurate for background checker
    if (value == 0) {
      await prefs.setBool('app_lock_enabled', false);
    } else {
      await prefs.setBool('app_lock_enabled', true);
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _useBiometric = value);
    await prefs.setBool('use_biometric', value);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // OPay uses a teal/green for the active state
    const activeColor = Color(0xFF00C853); 

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF4F6F9),
      appBar: AppBar(
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black, size: 20), onPressed: () => Navigator.pop(context)),
        title: Text('Auto-logout Setting', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildRadioCard(
              title: 'Password-Free Login',
              subtitle: 'Keep me logged in until I log out',
              value: 0,
              groupValue: _lockSetting,
              onChanged: _updateLockSetting,
              activeColor: activeColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildRadioCard(
              title: '60-Minute Password-Free Login',
              subtitle: 'Keep me logged in for 60 minutes',
              value: 1,
              groupValue: _lockSetting,
              onChanged: _updateLockSetting,
              activeColor: activeColor,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            _buildRadioCard(
              title: 'Password Always Needed Login',
              subtitle: 'Always ask for a password or biometrics when I open the app',
              value: 2,
              groupValue: _lockSetting,
              onChanged: _updateLockSetting,
              activeColor: activeColor,
              isDark: isDark,
            ),
            
            const SizedBox(height: 32),
            Text('Biometric Login Option', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
            const SizedBox(height: 16),
            
            Container(
              decoration: BoxDecoration(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, borderRadius: BorderRadius.circular(16)),
              child: SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                title: Text('Log in with Fingerprint', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
                value: _useBiometric,
                activeColor: activeColor,
                onChanged: _toggleBiometric,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRadioCard({required String title, required String subtitle, required int value, required int groupValue, required Function(int) onChanged, required Color activeColor, required bool isDark}) {
    bool isSelected = value == groupValue;
    return GestureDetector(
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? activeColor : (isDark ? Colors.transparent : Colors.white), width: 1.5),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black87)),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
            ),
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: isSelected ? activeColor : Colors.grey.shade400, width: isSelected ? 7 : 1.5)),
              child: isSelected ? const Icon(Icons.check, size: 10, color: Colors.white) : null,
            )
          ],
        ),
      ),
    );
  }
}
