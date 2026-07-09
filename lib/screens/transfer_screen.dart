import 'package:flutter/material.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Transfer', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1E1E1E), fontWeight: FontWeight.bold, fontSize: 18)),
        leading: IconButton(icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(color: primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.swap_horiz, color: primaryColor, size: 34),
              ),
              const SizedBox(height: 20),
              Text('Coming Soon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
              const SizedBox(height: 8),
              Text(
                'Wallet-to-wallet transfers between Kainuwa users will be available here soon.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
