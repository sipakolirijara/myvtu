import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/app_lock_screen.dart';

// Global notifiers so the app updates instantly without a restart
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(const Color(0xFF7351FF));
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  
  // Load cached theme mode
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  // Load cached primary color
  final cachedColorHex = prefs.getString('primary_color') ?? '#7351FF';
  primaryColorNotifier.value = Color(int.parse(cachedColorHex.replaceAll('#', '0xFF')));
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

// WidgetsBindingObserver listens to the app going to the background/foreground
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLockScreenShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    // If the app is brought back from the background
    if (state == AppLifecycleState.resumed) {
      final prefs = await SharedPreferences.getInstance();
      final isLocked = prefs.getBool('app_lock_enabled') ?? false;
      final lockOnResume = prefs.getBool('lock_on_resume') ?? true;
      final token = prefs.getString('api_token');

      // Only lock if enabled, not already showing, and user is actually logged in
      if (isLocked && lockOnResume && !_isLockScreenShowing && token != null && token.isNotEmpty) {
        _isLockScreenShowing = true;
        await navigatorKey.currentState?.push(
          PageRouteBuilder(
            opaque: false, // Makes it behave like an overlay
            pageBuilder: (context, _, __) => AppLockScreen(
              isFromResume: true,
              onSuccess: () {
                _isLockScreenShowing = false;
                navigatorKey.currentState?.pop(); // Remove the lock screen overlay
              },
            ),
          ),
        );
        _isLockScreenShowing = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Color>(
      valueListenable: primaryColorNotifier,
      builder: (_, Color primaryColor, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, ThemeMode currentMode, __) {
            return MaterialApp(
              navigatorKey: navigatorKey, // Allows global navigation interception
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
              home: const SplashScreen(),
            );
          },
        );
      },
    );
  }
}
