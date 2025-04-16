import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:uptm_chess/authentication/landing_screen.dart';
import 'package:uptm_chess/authentication/login_screen.dart';
import 'package:uptm_chess/authentication/sign_up_screen.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/firebase_options.dart';
import 'package:uptm_chess/main_screens/menu_screen.dart';
import 'package:uptm_chess/main_screens/game_screen.dart';
import 'package:uptm_chess/main_screens/game_time_screen.dart';
import 'package:uptm_chess/main_screens/settings_screen.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/providers/game_provider.dart';
import 'package:uptm_chess/providers/game_history_provider.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/wrapper/auth_wrapper.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set up FlutterError observer to catch and log Flutter framework errors
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('Flutter error caught: ${details.exception}');
    // You could add additional error reporting here
  };

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Prevent multiple instances error by explicitly handling the error scenario
  bool isFirstInstance = true;

  try {
    // Initialize shared preferences to track app instance
    final prefs = await SharedPreferences.getInstance();
    final lastRunTimestamp = prefs.getInt('last_run_timestamp');
    final currentTimestamp = DateTime.now().millisecondsSinceEpoch;

    // If app was opened in the last 2 seconds, we might have a duplicate instance
    if (lastRunTimestamp != null &&
        currentTimestamp - lastRunTimestamp < 2000) {
      debugPrint(
          'Potential duplicate instance detected. Current timestamp: $currentTimestamp, Last run: $lastRunTimestamp');
      isFirstInstance = false;
    }

    // Update the timestamp for the next instance check
    await prefs.setInt('last_run_timestamp', currentTimestamp);
  } catch (e) {
    debugPrint('Error during instance validation: $e');
  }

  if (isFirstInstance) {
    try {
      // Initialize and configure Firebase Realtime Database
      try {
        FirebaseDatabase database = FirebaseDatabase.instance;
        database.setPersistenceEnabled(true);
        database.setPersistenceCacheSizeBytes(10000000); // 10MB cache
        debugPrint('Firebase Realtime Database initialized successfully');
      } catch (e) {
        debugPrint('Error initializing Firebase Realtime Database: $e');
        // Continue even if Realtime Database fails to initialize
      }

      // Set up Firestore settings
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );

      // Create providers only once regardless of Firebase initialization status
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => GameProvider()),
            ChangeNotifierProvider(create: (_) => AuthenticationProvider()),
            ChangeNotifierProvider(create: (_) => GameHistoryProvider())
          ],
          child: const MyApp(),
        ),
      );
    } catch (e) {
      debugPrint('Error initializing Firebase: $e');
      // We'll continue without Firebase
      runApp(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(create: (_) => GameProvider()),
            ChangeNotifierProvider(create: (_) => AuthenticationProvider()),
            ChangeNotifierProvider(create: (_) => GameHistoryProvider())
          ],
          child: const MyApp(),
        ),
      );
    }
  } else {
    // For duplicate instances, show a simpler UI to avoid engine conflicts
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Text(
                  'UPTM Chess is already running',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Please close all instances and try again.',
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UPTM Chess',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: FutureBuilder(
        future:
            Future.delayed(const Duration(seconds: 2)), // Add a 2-second delay
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            // Show splash screen while waiting
            return Scaffold(
              backgroundColor: Colors.white,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 150,
                      height: 150,
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                  ],
                ),
              ),
            );
          }
          // After delay, show the auth wrapper
          return const AuthWrapper();
        },
      ),
      routes: {
        Constants.homeScreen: (context) => const AuthWrapper(),
        Constants.gameScreen: (context) => const GameScreen(),
        Constants.settingScreen: (context) => const SettingsScreen(),
        Constants.aboutScreen: (context) => const MenuScreen(),
        Constants.gameTimeScreen: (context) => const GameTimeScreen(),
        Constants.loginScreen: (context) => const LoginScreen(),
        Constants.signUpScreen: (context) => const SignUpScreen(),
        Constants.landingScreen: (context) => const LandingScreen(),
      },
    );
  }
}
