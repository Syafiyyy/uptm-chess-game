import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/widgets/widgets.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String selectedAvatar = 'avatar1';
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool obscureText = true;
  bool isCheckingUsername = false;
  Timer? _debounce;
  String? _usernameError;

  Widget _buildAvatarImage(String avatarName) {
    return SvgPicture.asset(
      'assets/avatars/$avatarName.svg',
      fit: BoxFit.contain,
      placeholderBuilder: (BuildContext context) => Container(
        padding: const EdgeInsets.all(16.0),
        child: const CircularProgressIndicator(),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    nameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  GlobalKey<FormState> formKey = GlobalKey<FormState>();

  // Check if username is valid with debouncing
  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Always immediately set not checking when text changes
    setState(() {
      isCheckingUsername = false;
    });
    
    // Don't check empty values
    if (value.trim().isEmpty) return;
    
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Start checking
      setState(() => isCheckingUsername = true);

      try {
        final trimmedUsername = value.trim();

        // Basic validation
        if (trimmedUsername.length < 3 || trimmedUsername.length > 20) {
          setState(() {
            _usernameError = 'Username must be between 3 and 20 characters';
            isCheckingUsername = false;
          });
          return;
        }

        // Check for invalid characters
        final RegExp validChars = RegExp(r'^[a-zA-Z0-9_]+$');
        if (!validChars.hasMatch(trimmedUsername)) {
          setState(() {
            _usernameError =
                'Username can only contain letters, numbers, and underscores';
            isCheckingUsername = false;
          });
          return;
        }

        setState(() {
          _usernameError = null;
          isCheckingUsername = false;
        });
      } catch (e) {
        setState(() {
          _usernameError = 'Error validating username';
          isCheckingUsername = false;
        });
      }
    });
  }

  // Track if signup is in process to prevent multiple submissions
  bool _isSigningUp = false;
  
  Future<void> signUpUser() async {
    // Prevent multiple submissions
    if (_isSigningUp) return;
    
    if (!formKey.currentState!.validate()) return;
    
    // Get the username value for validation
    final trimmedUsername = nameController.text.trim();
    
    // Validate username based on our rules (3-20 chars)
    if (trimmedUsername.isEmpty || trimmedUsername.length < 3 || trimmedUsername.length > 20) {
      showSnackBar(
        context: context,
        content: 'Username must be between 3 and 20 characters',
        backgroundColor: Colors.red,
      );
      return;
    }
    
    // Set signing up flag and show loading state
    setState(() {
      isCheckingUsername = false; // Reset username checking
      _isSigningUp = true;
    });
    
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    authProvider.setIsLoading(value: true);

    try {
      // Basic validation
      if (nameController.text.trim().isEmpty) {
        showSnackBar(
          context: context,
          content: 'Username cannot be empty',
          backgroundColor: Colors.red,
        );
        return;
      }

      if (nameController.text.trim().length < 3 || nameController.text.trim().length > 20) {
        showSnackBar(
          context: context,
          content: 'Username must be between 3 and 20 characters',
          backgroundColor: Colors.red,
        );
        return;
      }

      // Check for invalid characters
      final RegExp validChars = RegExp(r'^[a-zA-Z0-9_]+$');
      if (!validChars.hasMatch(nameController.text.trim())) {
        showSnackBar(
          context: context,
          content:
              'Username can only contain letters, numbers, and underscores',
          backgroundColor: Colors.red,
        );
        return;
      }

      // Check if username is available in usernames collection
      try {
        final usernameDoc = await FirebaseFirestore.instance
            .collection('usernames')
            .doc(nameController.text.trim().toLowerCase())
            .get();

        if (usernameDoc.exists) {
          authProvider.setIsLoading(value: false);
          if (!mounted) return;
          showSnackBar(
            context: context,
            content: 'Username is already taken. Please choose another one.',
            backgroundColor: Colors.red,
          );
          return;
        }
      } catch (e) {
        debugPrint('Error checking username: $e');
        // If it's a Firestore unavailability error, show a specific message
        if (e.toString().contains('unavailable')) {
          authProvider.setIsLoading(value: false);
          if (!mounted) return;
          showSnackBar(
            context: context,
            content:
                'Firebase service is temporarily unavailable. Please try again in a few moments.',
            backgroundColor: Colors.orange,
          );
          return;
        }
      }

      // Check if email already exists first
      try {
        // Try to fetch sign in methods for email - this will tell us if the email is already registered
        final methods = await FirebaseAuth.instance.fetchSignInMethodsForEmail(emailController.text.trim());
        if (methods.isNotEmpty) {
          // Email already exists
          setState(() => _isSigningUp = false);
          authProvider.setIsLoading(value: false);
          if (!mounted) return;
          
          showSnackBar(
            context: context,
            content: 'This email is already registered. Please sign in instead.',
            backgroundColor: Colors.red,
          );
          return;
        }
      } catch (e) {
        // Error checking email existence, continue with signup attempt
        debugPrint('Error checking email existence: $e');
      }
      
      // Create user account using the AuthenticationProvider
      UserCredential? userCredential;
      try {
        debugPrint(
            'Creating Firebase Auth user account via AuthenticationProvider...');
        userCredential = await authProvider.createUserWithEmailAndPassword(
            email: emailController.text, password: passwordController.text);

        if (userCredential == null) {
          throw Exception(
              'Failed to create user account - returned null credential');
        }

        // Add a delay to ensure auth token is fully propagated
        try {
          await userCredential.user!.getIdToken(true);
          debugPrint('Token refreshed successfully');
          // Shorter delay to keep things moving
          await Future.delayed(const Duration(milliseconds: 800));
        } catch (tokenError) {
          debugPrint('Token refresh error: $tokenError');
          // Continue anyway
        }

        // Prepare user data for saving

        // Create a proper UserModel object
        debugPrint('Saving user data through AuthenticationProvider...');
        // Simplify the user document - remove preference fields
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          Constants.uid: userCredential.user!.uid,
          Constants.name: nameController.text.trim(),
          Constants.email: emailController.text,
          Constants.image: selectedAvatar,
          Constants.lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
          Constants.playerRating: 1200,
          Constants.createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
          // Removing the preference fields that might cause issues
        });

        // Set signed in state
        await authProvider.setSignedIn();
        debugPrint('User successfully signed in after registration');

        // Reserve username manually
        // We do this as a separate step with retries
        int retryCount = 0;
        const maxRetries = 3;
        debugPrint(
            'CRITICAL: Attempting to reserve username: ${nameController.text.trim().toLowerCase()} for uid: ${userCredential.user!.uid}');

        // Get the auth token again before username reservation
        await userCredential.user!.getIdToken(true);
        debugPrint(
            'CRITICAL: Auth token refreshed before username reservation');

        // Verify we can read from Firestore before trying to write
        try {
          final testRead = await FirebaseFirestore.instance
              .collection('users')
              .doc(userCredential.user!.uid)
              .get();
          debugPrint(
              'CRITICAL: Test Firestore read result: ${testRead.exists ? 'Document exists' : 'Document does not exist yet'}');
        } catch (readError) {
          debugPrint('CRITICAL: Test Firestore read failed: $readError');
        }

        // Using reserveUsername method from the AuthenticationProvider
        await authProvider.reserveUsername(
            userCredential.user!.uid, nameController.text.trim().toLowerCase());
        debugPrint('CRITICAL: Username reservation successful');

        // Verify username was reserved
        try {
          final usernameDoc = await FirebaseFirestore.instance
              .collection('usernames')
              .doc(nameController.text.trim().toLowerCase())
              .get();
          debugPrint(
              'CRITICAL: Username document check: ${usernameDoc.exists ? 'Exists' : 'Does not exist'}');
          if (usernameDoc.exists) {
            final data = usernameDoc.data();
            debugPrint('CRITICAL: Username document data: $data');
          }
        } catch (verifyError) {
          debugPrint('CRITICAL: Username verification failed: $verifyError');
        }

        retryCount = 0;
        while (retryCount < maxRetries) {
          try {
            // Using reserveUsername method from the AuthenticationProvider
            await authProvider.reserveUsername(
                userCredential.user!.uid, nameController.text.trim().toLowerCase());
            debugPrint('CRITICAL: Username reservation successful');

            // Verify username was reserved
            try {
              final usernameDoc = await FirebaseFirestore.instance
                  .collection('usernames')
                  .doc(nameController.text.trim().toLowerCase())
                  .get();
              debugPrint(
                  'CRITICAL: Username document check: ${usernameDoc.exists ? 'Exists' : 'Does not exist'}');
              if (usernameDoc.exists) {
                final data = usernameDoc.data();
                debugPrint('CRITICAL: Username document data: $data');
              }
            } catch (verifyError) {
              debugPrint(
                  'CRITICAL: Username verification failed: $verifyError');
            }

            break;
          } catch (usernameError) {
            debugPrint(
                'Username reservation failed (attempt ${retryCount + 1}): $usernameError');
            retryCount++;

            if (retryCount >= maxRetries) {
              // If we've reached max retries, warn but don't fail completely
              // since the user document is already created
              debugPrint('Could not reserve username after max retries');
              if (!mounted) return;
              showSnackBar(
                context: context,
                content:
                    'Account created, but username reservation had issues.',
                backgroundColor: Colors.orange,
              );
              break;
            }

            // Wait before retrying
            await Future.delayed(
                Duration(milliseconds: 1000 * (1 << retryCount)));
          }
        }
      } catch (e) {
        debugPrint('Error setting signed-in state: $e');
        throw e; // Re-throw to be caught by outer catch
      }

      if (!mounted) return;
      
      // Clear the loading state
      authProvider.setIsLoading(value: false);
      
      // Show success message with a more prominent dialog instead of just a snackbar
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 28),
              SizedBox(width: 8),
              Text('Success!'),
            ],
          ),
          content: Text(
            'Your account has been created successfully. Please sign in with your new credentials.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () {
                // Close dialog and navigate to login screen
                Navigator.of(context).pop();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  Constants.loginScreen,
                  (route) => false,
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: Colors.blue,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('Sign In Now', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      
      // Format the error message to be more user-friendly
      String errorMessage = e.toString();
      if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'email-already-in-use':
            errorMessage = 'This email address is already in use. Please try logging in instead.';
            break;
          case 'weak-password':
            errorMessage = 'Your password is too weak. Please choose a stronger password.';
            break;
          case 'invalid-email':
            errorMessage = 'The email address you entered is invalid. Please check and try again.';
            break;
          default:
            errorMessage = 'Registration failed: ${e.message ?? e.code}';
        }
      }
      
      showSnackBar(
        context: context,
        content: errorMessage,
        backgroundColor: Colors.red,
      );
    } finally {
      if (mounted) {
        setState(() => _isSigningUp = false);
        final authProvider = context.read<AuthenticationProvider>();
        authProvider.setIsLoading(value: false);
      }
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
                    const SizedBox(height: 40),
                    // Avatar selection
                    GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (context) => Dialog(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Choose Avatar',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                  GridView.builder(
                                    shrinkWrap: true,
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                    ),
                                    itemCount: 6,
                                    itemBuilder: (context, index) {
                                      final avatarNumber = index + 1;
                                      final avatarName = 'avatar$avatarNumber';
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedAvatar = avatarName;
                                            isCheckingUsername = false; // Reset checking state
                                          });
                                          Navigator.pop(context);
                                        },
                                        child: Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.grey.shade50,
                                            border: Border.all(
                                              color:
                                                  selectedAvatar == avatarName
                                                      ? Colors.blue
                                                      : Colors.grey.shade200,
                                              width: 2,
                                            ),
                                          ),
                                          child: _buildAvatarImage(avatarName),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.grey.shade50,
                              border: Border.all(
                                color: Colors.blue.shade100,
                                width: 2,
                              ),
                            ),
                            child: _buildAvatarImage(selectedAvatar),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Welcome text
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Join us and start playing chess',
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
                          // Username field
                          Text(
                            'Username',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: nameController,
                            decoration: InputDecoration(
                              hintText: 'Choose a username',
                              prefixIcon: Icon(
                                Icons.person_outline,
                                color: Colors.grey.shade600,
                              ),
                              suffixIcon: isCheckingUsername
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                            Colors.blue.shade300,
                                          ),
                                        ),
                                      ),
                                    )
                                  : _usernameError != null
                                      ? Icon(
                                          Icons.error_outline,
                                          color: Colors.red.shade400,
                                        )
                                      : Icon(
                                          Icons.check_circle_outline,
                                          color: Colors.green.shade400,
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
                              errorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade300,
                                ),
                              ),
                              focusedErrorBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(
                                  color: Colors.red.shade300,
                                ),
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 16,
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Username cannot be empty';
                              }
                              if (value.length < 3) {
                                return 'Username must be at least 3 characters';
                              }
                              if (value.length > 20) {
                                setState(() {
                                  _usernameError = null;
                                  isCheckingUsername = false;
                                });
                                return null;
                              }
                              if (_usernameError != null) {
                                return _usernameError;
                              }
                              return null;
                            },
                            onChanged: _onUsernameChanged,
                          ),
                          const SizedBox(height: 20),
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
                            controller: emailController,
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
                            controller: passwordController,
                            obscureText: obscureText,
                            decoration: InputDecoration(
                              hintText: 'Create a password',
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
                                  authProvider.setIsLoading(value: false);
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
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 20),
                          // Confirm Password field
                          Text(
                            'Confirm Password',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            obscureText: obscureText,
                            decoration: InputDecoration(
                              hintText: 'Confirm your password',
                              prefixIcon: Icon(
                                Icons.lock_outline,
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
                                return 'Please confirm your password';
                              }
                              if (value != passwordController.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                    // Sign Up button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: (isCheckingUsername || _isSigningUp || authProvider.isLoading)
                            ? null // Disable when checking username, signing up, or loading
                            : () {
                                // Reset any checking state first 
                                setState(() {
                                  isCheckingUsername = false;
                                });
                                signUpUser();
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: (isCheckingUsername || _isSigningUp || authProvider.isLoading)
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                ),
                              )
                            : const Text(
                                'Create Account',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Sign in link
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamedAndRemoveUntil(
                            context,
                            Constants.loginScreen,
                            (route) => false,
                          ),
                          child: const Text(
                            'Sign In',
                            style: TextStyle(
                              color: Colors.blue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),
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
