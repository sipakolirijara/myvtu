import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/splash_screen.dart';
import 'screens/app_lock_screen.dart';

// GLOBAL VARIABLES
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<Color> primaryColorNotifier = ValueNotifier(const Color(0xFF7351FF));
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// FIX: Global tracker to prevent infinite lock screen loops
bool isAppLockActive = false;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool('is_dark_mode') ?? false;
  themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  
  final cachedColorHex = prefs.getString('primary_color') ?? '#7351FF';
  primaryColorNotifier.value = Color(int.parse(cachedColorHex.replaceAll('#', '0xFF')));
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
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
    final prefs = await SharedPreferences.getInstance();
    
    if (state == AppLifecycleState.paused) {
      await prefs.setInt('last_background_time', DateTime.now().millisecondsSinceEpoch);
    } 
    else if (state == AppLifecycleState.resumed) {
      final token = prefs.getString('api_token');
      final isLocked = prefs.getBool('app_lock_enabled') ?? false;
      final lockSetting = prefs.getInt('lock_setting') ?? 2; // Default Always

      // FIX: Only trigger if the lock screen IS NOT already showing!
      if (isLocked && !isAppLockActive && token != null && token.isNotEmpty) {
        bool shouldLock = false;
        
        if (lockSetting == 2) {
          shouldLock = true; 
        } else if (lockSetting == 1) {
          // 60-Minute Rule
          final lastTime = prefs.getInt('last_background_time') ?? 0;
          final diff = DateTime.now().millisecondsSinceEpoch - lastTime;
          if (diff > (60 * 60 * 1000)) { 
            shouldLock = true;
          }
        }

        if (shouldLock) {
          isAppLockActive = true; // Lock immediately to prevent loops
          await navigatorKey.currentState?.push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (context, _, __) => const AppLockScreen(isFromResume: true),
            ),
          );
        }
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
              navigatorKey: navigatorKey,
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
