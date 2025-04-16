import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/models/user_model.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthenticationProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool _isSignedIn = false;
  String? _uid;
  UserModel? _userModel;

  // getters
  bool get isLoading => _isLoading;
  bool get isSignIn => _isSignedIn;

  UserModel? get userModel => _userModel;
  String? get uid => _uid;

  void setIsLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  final FirebaseAuth firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;

  // create user with email and password
  Future<UserCredential?> createUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      // Create user with Firebase Auth
      debugPrint('Creating user with Firebase Auth...');
      UserCredential userCredential = await firebaseAuth
          .createUserWithEmailAndPassword(email: email, password: password);
      
      // Store the UID
      _uid = userCredential.user!.uid;
      
      // Critical: Force token refresh to ensure auth state is fully propagated
      debugPrint('User created, forcing token refresh...');
      await userCredential.user!.getIdToken(true); 
      
      // Add a delay to ensure token propagation through Firebase systems
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Get another token just to verify everything is working
      final token = await userCredential.user!.getIdToken(true);
      if (token != null) {
        debugPrint('Verified token available: ${token.substring(0, 10)}...');
      } else {
        debugPrint('Warning: Token is null after refresh');
      }
      
      notifyListeners();
      return userCredential;
    } catch (e) {
      debugPrint('Error creating user: $e');
      _isLoading = false;
      notifyListeners();
      rethrow; // Re-throw to allow caller to handle specific errors
    }
  }

  // sign in user with email and password
  Future<UserCredential?> signInUserWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check for internet connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          _isLoading = false;
          notifyListeners();
          throw FirebaseAuthException(
            code: 'network-request-failed',
            message:
                'No internet connection. Please check your network settings and try again.',
          );
        }
      } catch (e) {
        _isLoading = false;
        notifyListeners();
        throw FirebaseAuthException(
          code: 'network-request-failed',
          message:
              'No internet connection. Please check your network settings and try again.',
        );
      }

      // First try to validate if email exists to provide better errors
      try {
        var methods = await firebaseAuth.fetchSignInMethodsForEmail(email);
        if (methods.isEmpty) {
          _isLoading = false;
          notifyListeners();
          throw FirebaseAuthException(
            code: 'user-not-found',
            message:
                'No user found with this email. Please check your email or sign up.',
          );
        }
      } catch (e) {
        // Continue with normal authentication if this check fails
        debugPrint('Could not pre-validate email: $e');
      }

      // Proceed with Firebase authentication
      UserCredential userCredential = await firebaseAuth
          .signInWithEmailAndPassword(email: email, password: password);
      _uid = userCredential.user!.uid;

      // Try to get user data from Firestore
      try {
        debugPrint(
            'Attempting to load user data from Firestore for UID: ${userCredential.user!.uid}');
        bool success = await getUserDataFromFireStore();

        // If Firestore fetch fails, try SharedPreferences as fallback
        if (!success) {
          debugPrint(
              'Firestore fetch failed, trying SharedPreferences fallback');
          success = await getUserDataToSharedPref();

          // If SharedPreferences also fails but we have a valid user, create minimal user data
          if (!success && userCredential.user != null) {
            debugPrint(
                'Both Firestore and SharedPreferences failed, creating minimal user model');
            _userModel = UserModel(
              uid: userCredential.user!.uid,
              name: userCredential.user!.displayName ?? email.split('@')[0],
              email: email,
              image: 'avatar1',
              lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
              playerRating: 1200,
              createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
            );

            // Store this minimal model to Firestore as well
            try {
              await firebaseFirestore
                  .collection('users')
                  .doc(_userModel!.uid)
                  .set(_userModel!.toMap());
              debugPrint(
                  'Created new user document in Firestore with minimal data');
            } catch (firestoreError) {
              debugPrint(
                  'Failed to create user document in Firestore: $firestoreError');
              // Continue anyway, we'll use the in-memory model
            }
          }
        }

        // Set and persist signed in state properly
        _uid = userCredential.user!.uid;
        
        // Explicitly call setSignedIn to persist the signed-in state to SharedPreferences
        bool signedInSuccess = await setSignedIn();
        debugPrint('User set as signed in: $signedInSuccess');
        
        // Try to save user data to SharedPreferences for offline access if not already done
        if (!signedInSuccess) {
          bool savedToPrefs = await saveUserDataToSharedPref();
          debugPrint('User data saved to SharedPreferences: $savedToPrefs');
        }

        if (_userModel == null) {
          debugPrint(
              'WARNING: User model is still null after all recovery attempts');
          throw Exception('Failed to create or retrieve user data');
        }
      } catch (e) {
        debugPrint('Error loading or creating user data: $e');
        // Don't silently continue - throw the error so the UI can handle it properly
        throw Exception(
            'Failed to load user data. Please try again or contact support.');
      }

      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();

      // Provide more user-friendly error messages
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage =
              'No user found with this email. Please check your email or sign up.';
          break;
        case 'wrong-password':
          errorMessage = 'Incorrect password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Invalid email format. Please enter a valid email.';
          break;
        case 'user-disabled':
          errorMessage =
              'This account has been disabled. Please contact support.';
          break;
        case 'network-request-failed':
          errorMessage =
              'Network error. Please check your internet connection and try again.';
          break;
        case 'too-many-requests':
          errorMessage =
              'Too many failed login attempts. Please try again later.';
          break;
        default:
          errorMessage = e.message ??
              'An error occurred during sign in. Please try again.';
      }

      debugPrint('Firebase Auth Exception: ${e.code} - $errorMessage');
      throw FirebaseAuthException(
        code: e.code,
        message: errorMessage,
      );
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      debugPrint('Error signing in: $e');
      throw Exception('An unexpected error occurred. Please try again later.');
    }
  }

  // sign in with google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Create a new GoogleSignIn instance
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in with the credential
      UserCredential userCredential =
          await firebaseAuth.signInWithCredential(credential);
      _uid = userCredential.user!.uid;
      notifyListeners();
      return userCredential;
    } on FirebaseAuthException catch (e) {
      _isLoading = false;
      notifyListeners();
      throw e; // Rethrow to be caught by the UI layer
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      return null;
    }
  }

  // check if user exist
  Future<bool> checkUserExist() async {
    try {
      if (_uid == null || _uid!.isEmpty) {
        debugPrint('UID is null or empty when checking if user exists');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      DocumentSnapshot documentSnapshot =
          await firebaseFirestore.collection(Constants.users).doc(_uid).get();
      return documentSnapshot.exists;
    } catch (e) {
      debugPrint('Error checking if user exists: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // get user data from firestore
  Future<bool> getUserDataFromFireStore() async {
    try {
      // Check if currentUser is null
      if (firebaseAuth.currentUser == null) {
        debugPrint('Current user is null in getUserDataFromFireStore');
        _isLoading = false;
        notifyListeners();
        return false;
      }

      String uid = firebaseAuth.currentUser!.uid;
      _uid = uid; // Set the UID immediately when we have it
      debugPrint('Getting user data for UID: $uid');

      // Implement retry logic for network errors
      int retryCount = 0;
      const maxRetries = 3;

      while (retryCount < maxRetries) {
        try {
          DocumentSnapshot documentSnapshot = await firebaseFirestore
              .collection(Constants.users)
              .doc(uid)
              .get();

          if (!documentSnapshot.exists) {
            debugPrint('User document does not exist in Firestore');
            // Try to create a basic user document if it doesn't exist but auth user does
            if (firebaseAuth.currentUser != null) {
              debugPrint('Attempting to create missing user document');
              try {
                final user = firebaseAuth.currentUser!;
                await firebaseFirestore
                    .collection(Constants.users)
                    .doc(uid)
                    .set({
                  Constants.uid: uid,
                  Constants.name:
                      user.displayName ?? user.email?.split('@')[0] ?? 'User',
                  Constants.email: user.email ?? '',
                  Constants.image: 'avatar1',
                  Constants.playerRating: 1200,
                  Constants.createdAt:
                      DateTime.now().millisecondsSinceEpoch.toString(),
                });
                debugPrint('Created basic user document successfully');
              } catch (createError) {
                debugPrint(
                    'Failed to create missing user document: $createError');
                _isLoading = false;
                notifyListeners();
                return false;
              }
            } else {
              _isLoading = false;
              notifyListeners();
              return false;
            }
          }

          final data = documentSnapshot.data();
          if (data == null) {
            debugPrint('User document data is null');
            _isLoading = false;
            notifyListeners();
            return false;
          }

          // Ensure the UID is in the data map
          Map<String, dynamic> userData = data as Map<String, dynamic>;
          if (userData[Constants.uid] == null ||
              userData[Constants.uid].isEmpty) {
            userData[Constants.uid] = uid;
          }

          _userModel = UserModel.fromMap(userData);
          debugPrint(
              'Successfully loaded user data: ${_userModel!.name} (${_userModel!.uid})');

          // Save to SharedPreferences for offline access
          await saveUserDataToSharedPref();

          _isLoading = false;
          notifyListeners();
          return true;
        } catch (e) {
          retryCount++;
          if (e.toString().contains('network') && retryCount < maxRetries) {
            // Wait with exponential backoff before retrying
            final waitTime = Duration(milliseconds: 500 * (1 << retryCount));
            debugPrint(
                'Network error, retrying in ${waitTime.inMilliseconds}ms...');
            await Future.delayed(waitTime);
          } else {
            debugPrint('Error getting user data from Firestore: $e');
            _isLoading = false;
            notifyListeners();
            return false;
          }
        }
      }

      // If we've exhausted all retries
      debugPrint('Failed to get user data after $maxRetries attempts');
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error getting user data from Firestore: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // get user data from shared preferences
  Future<bool> getUserDataToSharedPref() async {
    try {
      SharedPreferences s = await SharedPreferences.getInstance();
      String data = s.getString(Constants.userModel) ?? '';

      if (data.isEmpty) {
        debugPrint('No user data found in SharedPreferences');
        return false;
      }

      try {
        // Parse the data as JSON
        final userData = jsonDecode(data);

        // Check if the data is valid
        if (userData is! Map<String, dynamic> ||
            !userData.containsKey(Constants.uid) ||
            !userData.containsKey(Constants.name) ||
            !userData.containsKey(Constants.email)) {
          debugPrint('Invalid or incomplete user data in SharedPreferences');
          return false;
        }

        // Create the user model from JSON
        _userModel = UserModel.fromMap(userData);
        _uid = _userModel!.uid;

        // Validate that the UID matches the current authentication state
        if (firebaseAuth.currentUser != null &&
            firebaseAuth.currentUser!.uid != _uid) {
          debugPrint('UID mismatch between Auth and SharedPreferences');
          return false;
        }

        return true;
      } catch (parseError) {
        debugPrint(
            'Error parsing user data from SharedPreferences: $parseError');
        // Clear corrupted data
        await s.remove(Constants.userModel);
        return false;
      }
    } catch (e) {
      // Handle any errors during retrieval
      debugPrint('Error getting user data from SharedPreferences: $e');
      return false;
    }
  }

  // store user data to shared preferences
  Future<bool> saveUserDataToSharedPref() async {
    try {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();

      // Ensure UID is set in user model before saving
      if (_userModel != null) {
        if (_userModel!.uid.isEmpty && firebaseAuth.currentUser != null) {
          _userModel = UserModel(
            uid: firebaseAuth.currentUser!.uid,
            name: _userModel!.name,
            email: _userModel!.email,
            image: _userModel!.image,
            lastUsernameChange: _userModel!.lastUsernameChange,
            playerRating: _userModel!.playerRating,
            createdAt: _userModel!.createdAt,
          );
          debugPrint(
              'Added missing UID to user model before saving: ${_userModel!.uid}');
        }

        // Validate the model before saving
        if (_userModel!.uid.isEmpty) {
          debugPrint('Cannot save user data with empty UID');
          return false;
        }

        if (_userModel!.email.isEmpty) {
          debugPrint('Cannot save user data with empty email');
          return false;
        }

        // Ensure lastUsernameChange is properly set
        if (_userModel!.lastUsernameChange == 0) {
          _userModel = UserModel(
            uid: _userModel!.uid,
            name: _userModel!.name,
            email: _userModel!.email,
            image: _userModel!.image,
            lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
            playerRating: _userModel!.playerRating,
            createdAt: _userModel!.createdAt,
          );
          debugPrint('Fixed lastUsernameChange timestamp');
        }

        // Use a try-catch specifically for the JSON encoding
        try {
          final userData = _userModel!.toMap();
          debugPrint('Preparing to save user data: $userData');
          final encodedData = jsonEncode(userData);
          await sharedPreferences.setString(Constants.userModel, encodedData);
          // Also set isSignedIn flag
          await sharedPreferences.setBool(Constants.isSignedIn, true);
          debugPrint(
              'User data saved to SharedPreferences: ${_userModel!.name} (UID: ${_userModel!.uid})');
          return true;
        } catch (encodeError) {
          debugPrint('Error encoding user data: $encodeError');
          return false;
        }
      } else {
        debugPrint('Warning: Cannot save user data - userModel is null');
        return false;
      }
    } catch (e) {
      debugPrint('Error saving user data to SharedPreferences: $e');
      return false;
    }
  }

  // set user as signIn
  Future<bool> setSignedIn() async {
    try {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      await sharedPreferences.setBool(Constants.isSignedIn, true);
      _isSignedIn = true;

      // Verify we have a valid user model before proceeding
      if (_userModel == null) {
        debugPrint('Warning: Setting user as signed in but userModel is null');
        bool success = await getUserDataFromFireStore();
        if (!success) {
          debugPrint(
              'Failed to load user data, user will not be properly signed in');
          return false;
        }
      }

      debugPrint(
          'User successfully set as signed in: ${_userModel?.name ?? "Unknown"}');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error setting user as signed in: $e');
      return false;
    }
  }

  // check if user is signed in
  Future<bool> checkIsSignedIn() async {
    try {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      _isSignedIn = sharedPreferences.getBool(Constants.isSignedIn) ?? false;

      // If signed in, try to load user data
      if (_isSignedIn) {
        // First try to get user from Firestore
        bool firestoreSuccess = await getUserDataFromFireStore();

        // If Firestore fails, try shared preferences
        if (!firestoreSuccess) {
          bool sharedPrefSuccess = await getUserDataToSharedPref();
          if (!sharedPrefSuccess) {
            debugPrint(
                'Failed to load user data from both Firestore and SharedPreferences');
            _isSignedIn = false;
            notifyListeners();
            return false;
          }
        }

        // Verify that we have a valid user model with a non-empty UID
        if (_userModel == null || _userModel!.uid.isEmpty) {
          debugPrint(
              'User is signed in but userModel is null or has empty UID');
          _isSignedIn = false;
          notifyListeners();
          return false;
        }

        debugPrint(
            'User is signed in: ${_userModel!.name} (${_userModel!.uid})');
      } else {
        debugPrint('User is not signed in');
      }

      notifyListeners();
      return _isSignedIn;
    } catch (e) {
      debugPrint('Error checking if user is signed in: $e');
      _isSignedIn = false;
      notifyListeners();
      return false;
    }
  }

  // save user data to firestore
  void saveUserDataToFireStore({
    required UserModel currentUser,
    required File? fileImage,
    required Function onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      // check if the fileImage is not null
      if (fileImage != null) {
        // upload the image firestore storage
        String imageUrl = await storeFileImageToStorage(
          ref: '${Constants.userImages}/$uid.jpg',
          file: fileImage,
        );

        currentUser.image = imageUrl;
      }

      currentUser.createdAt = DateTime.now().microsecondsSinceEpoch.toString();

      _userModel = currentUser;

      // save data to fireStore
      await firebaseFirestore
          .collection(Constants.users)
          .doc(uid)
          .set(currentUser.toMap());

      onSuccess();
      _isLoading = false;
      notifyListeners();
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      onFail(e.toString());
    }
  }

  // store image to storage and return the download url
  Future<String> storeFileImageToStorage({
    required String ref,
    required File file,
  }) async {
    UploadTask uploadTask = firebaseStorage.ref().child(ref).putFile(file);
    TaskSnapshot taskSnapshot = await uploadTask;
    String downloadUrl = await taskSnapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  // sign out user
  Future<void> signOutUser() async {
    try {
      SharedPreferences sharedPreferences =
          await SharedPreferences.getInstance();
      await firebaseAuth.signOut();
      _isSignedIn = false;
      await sharedPreferences.clear();
      _userModel = null;
      _uid = null;
      notifyListeners();
      debugPrint('User signed out successfully');
    } catch (e) {
      debugPrint('Error signing out user: $e');
      // Try to recover from error
      try {
        await firebaseAuth.signOut();
        _isSignedIn = false;
        notifyListeners();
      } catch (innerError) {
        debugPrint('Critical error signing out: $innerError');
      }
    }
  }

  // Reset the provider state completely
  Future<void> resetState() async {
    _isSignedIn = false;
    _uid = null;
    _userModel = null;
    _isLoading = false;
    notifyListeners();
    
    try {
      // Clear shared preferences data related to user
      SharedPreferences s = await SharedPreferences.getInstance();
      await s.remove(Constants.userModel);
      await s.setBool(Constants.isSignedIn, false);
      debugPrint('User state reset successfully');
    } catch (e) {
      debugPrint('Error clearing shared preferences during reset: $e');
      // Continue even if there's an error with shared preferences
    }

    notifyListeners();
  }
  
  // Create a UserModel from Firebase Auth user data
  void setUserModelFromAuth(User firebaseUser) {
    _uid = firebaseUser.uid;
    String displayName = firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User';
    
    _userModel = UserModel(
      uid: firebaseUser.uid,
      name: displayName,
      email: firebaseUser.email ?? '',
      image: 'avatar1',
      lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
      playerRating: 1200,
      createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
      aiDifficulty: 'Intermediate',
      preferredColor: 'White',
      preferredTimeControl: '10 Minutes',
    );
    
    debugPrint('Created minimal UserModel from Firebase Auth: ${_userModel!.name}');
    notifyListeners();
  }

  // Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Check for internet connectivity first
      try {
        final result = await InternetAddress.lookup('google.com');
        if (result.isEmpty || result[0].rawAddress.isEmpty) {
          throw 'No internet connection. Please check your network and try again.';
        }
      } catch (e) {
        throw 'No internet connection. Please check your network and try again.';
      }

      // Check if the email exists in Firebase Auth
      final methods = await firebaseAuth.fetchSignInMethodsForEmail(email);
      if (methods.isEmpty) {
        throw 'No account found with this email address.';
      }

      await firebaseAuth.sendPasswordResetEmail(email: email);
      debugPrint('Password reset email sent to $email');
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending password reset email: ${e.message}');
      switch (e.code) {
        case 'invalid-email':
          throw 'Invalid email format. Please check your email and try again.';
        case 'user-not-found':
          throw 'No account found with this email address.';
        default:
          throw e.message ??
              'Failed to send password reset email. Please try again.';
      }
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      throw e.toString();
    }
  }

  // Verify email address
  Future<void> sendEmailVerification() async {
    try {
      User? user = firebaseAuth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
        debugPrint('Verification email sent to ${user.email}');
      } else if (user == null) {
        throw 'No user is currently signed in.';
      } else if (user.emailVerified) {
        throw 'Email is already verified.';
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('Error sending verification email: ${e.message}');
      throw e.message ?? 'Failed to send verification email. Please try again.';
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      throw e.toString();
    }
  }

  // Check if email is verified
  Future<bool> isEmailVerified() async {
    try {
      User? user = firebaseAuth.currentUser;
      if (user != null) {
        // Reload user to get latest status
        await user.reload();
        return user.emailVerified;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking email verification: $e');
      return false;
    }
  }

  // Recover account if Firebase Auth and Firestore are out of sync
  Future<bool> recoverAccount(String email, String password) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Try to sign in
      UserCredential? userCredential = await signInUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential == null) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check if Firestore document exists
      bool userExists = await checkUserExist();

      // If user exists in Auth but not in Firestore, try to recreate the document
      if (!userExists && userCredential.user != null) {
        debugPrint('Account recovery: Creating missing Firestore document');
        final user = userCredential.user!;

        try {
          await firebaseFirestore
              .collection(Constants.users)
              .doc(user.uid)
              .set({
            Constants.uid: user.uid,
            Constants.name: user.displayName ?? email.split('@')[0],
            Constants.email: email,
            Constants.image: 'avatar1',
            Constants.playerRating: 1200,
            Constants.createdAt:
                DateTime.now().millisecondsSinceEpoch.toString(),
            // Set lastUsernameChange to 0 to allow immediate username change
            Constants.lastUsernameChange: 0,
          });

          // Reserve username to ensure uniqueness
          final username = email.split('@')[0].toLowerCase();
          try {
            await firebaseFirestore.collection('usernames').doc(username).set({
              'uid': user.uid,
              'timestamp': DateTime.now().millisecondsSinceEpoch,
            });
          } catch (e) {
            debugPrint('Could not reserve username during recovery: $e');
            // Continue anyway as this is not critical
          }

          // Try to get user data again
          bool success = await getUserDataFromFireStore();
          if (success) {
            await saveUserDataToSharedPref();
            await setSignedIn();
            _isLoading = false;
            notifyListeners();
            return true;
          }
        } catch (e) {
          debugPrint('Error creating user document during recovery: $e');
        }
      } else if (userExists) {
        // User exists in both Auth and Firestore, just ensure data is loaded
        await getUserDataFromFireStore();
        await saveUserDataToSharedPref();
        await setSignedIn();
        _isLoading = false;
        notifyListeners();
        return true;
      }

      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      debugPrint('Error in account recovery: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Check if username meets all requirements
  Future<String?> validateUsername(String username) async {
    // Basic validation
    if (username.isEmpty) {
      return 'Username cannot be empty';
    }
    if (username.length < 3) {
      return 'Username must be at least 3 characters';
    }
    if (username.length > 20) {
      return 'Username must be less than 20 characters';
    }

    // Check uniqueness
    try {
      final usernameDoc = await firebaseFirestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .get();

      if (usernameDoc.exists) {
        return 'Username is already taken';
      }
    } catch (e) {
      return 'Error checking username availability';
    }

    return null; // Username is valid
  }

  // Check if user can change username (7-day restriction)
  Future<String?> canChangeUsername(String uid) async {
    try {
      final userDoc =
          await firebaseFirestore.collection('users').doc(uid).get();
      if (!userDoc.exists) return null; // New user can set username

      final data = userDoc.data() as Map<String, dynamic>;
      final lastChange = data['lastUsernameChange'] as int?;

      if (lastChange == null) return null; // No previous changes

      final lastChangeDate = DateTime.fromMillisecondsSinceEpoch(lastChange);
      final now = DateTime.now();
      final difference = now.difference(lastChangeDate);

      if (difference.inDays < 7) {
        final daysLeft = 7 - difference.inDays;
        return 'You can change your username again in $daysLeft days';
      }

      return null; // Can change username
    } catch (e) {
      return 'Error checking username change eligibility';
    }
  }

  // Update username with all validations
  Future<void> updateUsername(String uid, String newUsername) async {
    // Check 7-day restriction
    final restrictionError = await canChangeUsername(uid);
    if (restrictionError != null) {
      throw restrictionError;
    }

    // Validate new username
    final validationError = await validateUsername(newUsername);
    if (validationError != null) {
      throw validationError;
    }

    try {
      // Get old username to delete from usernames collection
      final userDoc =
          await firebaseFirestore.collection('users').doc(uid).get();
      final oldUsername =
          (userDoc.data() as Map<String, dynamic>)['username'] as String?;

      // Start a batch write
      final batch = firebaseFirestore.batch();

      // Update user document
      batch.update(firebaseFirestore.collection('users').doc(uid), {
        'username': newUsername.toLowerCase(),
        'lastUsernameChange': DateTime.now().millisecondsSinceEpoch,
      });

      // Delete old username reservation
      if (oldUsername != null) {
        batch.delete(firebaseFirestore
            .collection('usernames')
            .doc(oldUsername.toLowerCase()));
      }

      // Create new username reservation
      batch.set(
          firebaseFirestore
              .collection('usernames')
              .doc(newUsername.toLowerCase()),
          {
            'uid': uid,
            'createdAt': DateTime.now().millisecondsSinceEpoch,
          });

      await batch.commit();
    } catch (e) {
      throw 'Failed to update username: ${e.toString()}';
    }
  }

  // Reserve a new username (for new users)
  Future<void> reserveUsername(String uid, String username) async {
    final validationError = await validateUsername(username);
    if (validationError != null) {
      throw validationError;
    }

    try {
      await firebaseFirestore
          .collection('usernames')
          .doc(username.toLowerCase())
          .set({
        'uid': uid,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw 'Failed to reserve username: ${e.toString()}';
    }
  }
}
