import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/authentication/login_screen.dart';
import 'package:uptm_chess/main_screens/home_screen.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Check authentication state after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthState();
    });
  }

  Future<void> _checkAuthState() async {
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    
    try {
      // First check if user is signed in via shared preferences
      bool isSignedIn = await authProvider.checkIsSignedIn();
      debugPrint('User signed in status from shared preferences: $isSignedIn');
      
      if (isSignedIn) {
        // Try to load user data from shared preferences
        bool success = await authProvider.getUserDataToSharedPref();
        debugPrint('Loading user data from shared preferences: ${success ? 'Success' : 'Failed'}');
        
        // If we couldn't load user data, sign the user out
        if (!success) {
          debugPrint('Failed to load user data, signing out');
          await authProvider.signOutUser();
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error checking auth state: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthenticationProvider>(
      builder: (context, authProvider, _) {
        // Show loading indicator while checking auth state
        if (_isLoading) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }
            
            if (snapshot.hasData && snapshot.data != null) {
              // User is signed in via Firebase Auth
              debugPrint('User is signed in via Firebase Auth: ${snapshot.data!.email}');
              
              // CRITICAL FIX: Check if user data is loaded in the provider
              if (authProvider.userModel == null) {
                // If no user data yet, initiate asynchronous data loading
                WidgetsBinding.instance.addPostFrameCallback((_) async {
                  try {
                    // Set loading state
                    authProvider.setIsLoading(value: true);
                    
                    // Attempt to get user data from Firestore
                    debugPrint('Attempting to load user data for authenticated user');
                    bool success = await authProvider.getUserDataFromFireStore();
                    
                    // If Firestore fails, try SharedPreferences
                    if (!success) {
                      debugPrint('Firestore load failed, trying SharedPreferences');
                      success = await authProvider.getUserDataToSharedPref();
                    }
                    
                    // If both fails, we need to trigger the fallback logic in signInUserWithEmailAndPassword
                    if (!success && context.mounted) {
                      debugPrint('Both Firestore and SharedPreferences failed, attempting recovery');
                      
                      // Get the current Firebase user
                      final firebaseUser = snapshot.data!;
                      
                      try {
                        // Try to save data to Firestore directly which will also create a basic user document
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(firebaseUser.uid)
                            .set({
                          'uid': firebaseUser.uid,
                          'name': firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User',
                          'email': firebaseUser.email ?? '',
                          'image': 'avatar1',
                          'playerRating': 1200,
                          'lastUsernameChange': DateTime.now().millisecondsSinceEpoch,
                          'createdAt': DateTime.now().millisecondsSinceEpoch.toString(),
                          'aiDifficulty': 'Intermediate',
                          'preferredColor': 'White',
                          'preferredTimeControl': '10 Minutes',
                        });
                        
                        // Try to load the user data again from Firestore
                        success = await authProvider.getUserDataFromFireStore();
                        debugPrint('Created and loaded user document: $success');
                        
                        // Ensure isSignedIn flag is set in shared preferences
                        if (success) {
                          await authProvider.setSignedIn();
                        }
                      } catch (e) {
                        debugPrint('Error in recovery process: $e');
                      }
                    }
                  } finally {
                    if (authProvider.isLoading && context.mounted) {
                      authProvider.setIsLoading(value: false);
                    }
                  }
                });
                
                // Show loading indicator while fetching data
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }
              
              // If user is signed in and user data is loaded, proceed to HomeScreen
              return const HomeScreen();
            } else {
              // Check if we have user data in the provider (from shared preferences)
              if (authProvider.userModel != null) {
                debugPrint('User data found in provider: ${authProvider.userModel!.name}');
                return const HomeScreen();
              } else {
                // User is not signed in
                debugPrint('User is not signed in, showing login screen');
                return const LoginScreen();
              }
            }
          },
        );
      },
    );
  }
}
