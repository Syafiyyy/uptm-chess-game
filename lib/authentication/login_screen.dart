import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/widgets/widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String email = '';
  String password = '';
  bool obscureText = true;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // signIn user
  Future<void> signInUser() async {
    try {
      if (_emailController.text.isEmpty || _passwordController.text.isEmpty) {
        showSnackBar(
          context: context,
          content: 'Please enter both email and password',
          backgroundColor: Colors.red,
        );
        return;
      }

      final authProvider = context.read<AuthenticationProvider>();
      authProvider.setIsLoading(value: true);

      try {
        // First try to sign in with Firebase Auth
        final userCredential =
            await authProvider.signInUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        if (userCredential == null) {
          if (!mounted) return;
          authProvider.setIsLoading(value: false);
          showSnackBar(
            context: context,
            content: 'Login failed. Please try again.',
            backgroundColor: Colors.red,
          );
          return;
        }

        // Check if user exists in our database
        final userExists = await authProvider.checkUserExist();
        if (userExists) {
          debugPrint('User exists, loading data from Firestore');

          // Try to get user data from Firestore
          bool gotUserData = false;
          try {
            gotUserData = await authProvider.getUserDataFromFireStore();
          } catch (e) {
            debugPrint('Error getting user data from Firestore: $e');
            // Continue with SharedPreferences as fallback
          }

          if (!gotUserData) {
            debugPrint(
                'Failed to get user data from Firestore, trying SharedPreferences');
            final sharedPrefData = await authProvider.getUserDataToSharedPref();
            if (!sharedPrefData) {
              if (!mounted) return;
              authProvider.setIsLoading(value: false);
              showSnackBar(
                context: context,
                content:
                    'Failed to load user data. Please check your internet connection and try again.',
                backgroundColor: Colors.red,
              );
              return;
            }
          }

          // Try to save user data to SharedPreferences for offline access
          try {
            debugPrint('Saving user data to SharedPreferences');
            await authProvider.saveUserDataToSharedPref();
          } catch (e) {
            debugPrint(
                'Warning: Failed to save user data to SharedPreferences: $e');
            // Continue anyway, this is not critical
          }

          debugPrint('Setting user as signed in');
          final signInSuccess = await authProvider.setSignedIn();

          // Always make sure to set isLoading to false before navigating
          authProvider.setIsLoading(value: false);

          if (!signInSuccess) {
            debugPrint('Failed to set user as signed in');
            if (!mounted) return;
            showSnackBar(
              context: context,
              content: 'Failed to complete login. Please try again.',
              backgroundColor: Colors.red,
            );
            return;
          }

          if (!mounted) return;

          debugPrint('Login successful, navigating to home screen');
          Navigator.pushNamedAndRemoveUntil(
            context,
            Constants.homeScreen,
            (route) => false,
          );
        } else {
          authProvider.setIsLoading(value: false);
          if (!mounted) return;
          showSnackBar(
            context: context,
            content: 'User account not found',
            backgroundColor: Colors.red,
          );
          await authProvider.signOutUser();
        }
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        authProvider.setIsLoading(value: false);
        showSnackBar(
          context: context,
          content: e.message ?? 'Authentication failed',
          backgroundColor: Colors.red,
        );
      }
    } catch (e) {
      final authProvider = context.read<AuthenticationProvider>();
      authProvider.setIsLoading(value: false);
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: 'An error occurred: ${e.toString()}',
        backgroundColor: Colors.red,
      );
    }
  }

  navigate({required bool isSignedIn}) {
    if (isSignedIn) {
      Navigator.pushNamedAndRemoveUntil(
          context, Constants.homeScreen, (route) => false);
    } else {
      Navigator.pushNamedAndRemoveUntil(
          context, Constants.signUpScreen, (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthenticationProvider>();
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Form(
                key: formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 60),
                    // Logo
                    Container(
                      width: 120,
                      height: 120,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.blue.shade50,
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Welcome text
                    const Text(
                      'Welcome Back!',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Sign in to continue playing chess',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Form fields
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Email field
                          Text(
                            'Email',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              hintText: 'Enter your email',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                color: Colors.grey.shade600,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Email cannot be empty';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                                  .hasMatch(value)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Password field
                          Text(
                            'Password',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: obscureText,
                            decoration: InputDecoration(
                              hintText: 'Enter your password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  obscureText
                                      ? Icons.visibility_off
                                      : Icons.visibility,
                                  color: Colors.grey.shade600,
                                ),
                                onPressed: () {
                                  setState(() {
                                    obscureText = !obscureText;
                                  });
                                },
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.grey.shade200,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: Colors.blue,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Password cannot be empty';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Sign In button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: authProvider.isLoading ? null : signInUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: authProvider.isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    // Sign up link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            Constants.signUpScreen,
                            (route) => false,
                          ),
                          child: const Text(
                            'Sign Up',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
