import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';

// Global notifiers so the app updates instantly without a restart
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(const Color(0xFF7351FF));

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // Load cached theme mode
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  // Load cached primary color
  final cachedColorHex = prefs.getString('primary_color') ?? '#7351FF';
  primaryColorNotifier.value = Color(int.parse(cachedColorHex.replaceAll('#', '0xFF')));
  
  // We do NOT fetch network data here anymore. 
  // We instantly run the app and let the SplashScreen handle the loading!
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: primaryColorNotifier,
      builder: (_, Color primaryColor, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, ThemeMode currentMode, __) {
            return MaterialApp(
              title: 'Kainuwa VTU',
              debugShowCheckedModeBanner: false,
              themeMode: currentMode,
              theme: ThemeData(
                primaryColor: primaryColor,
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
                colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.light),
                scaffoldBackgroundColor: const Color(0xFFF4F6F9),
                appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.black)),
              ),
              darkTheme: ThemeData(
                primaryColor: primaryColor,
                textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
                colorScheme: ColorScheme.fromSeed(seedColor: primaryColor, brightness: Brightness.dark),
                scaffoldBackgroundColor: const Color(0xFF121212),
                appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, elevation: 0, iconTheme: IconThemeData(color: Colors.white)),
                cardColor: const Color(0xFF1E1E1E),
              ),
              // CRITICAL FIX: The app must start at the Splash Screen
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
