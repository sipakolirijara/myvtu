import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  Future<String?> _getValidToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('api_token');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kainuwa VTU',
      theme: ThemeData(
        primaryColor: Colors.blue, // Dynamic theming anchor
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
      ),
      home: FutureBuilder<String?>(
        future: _getValidToken(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          
          if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty) {
            return const DashboardScreen();
          }
          
          return const LoginScreen();
        },
      ),
    );
  }
}
