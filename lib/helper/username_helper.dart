import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uptm_chess/constants.dart';

class UsernameHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Check if username is unique
  static Future<bool> isUsernameUnique(String username) async {
    // Basic validation
    if (username.isEmpty || username.trim().isEmpty) {
      throw 'Username cannot be empty';
    }

    username = username.trim().toLowerCase();
    
    if (username.length < 3 || username.length > 20) {
      throw 'Username must be between 3 and 20 characters';
    }

    // Check for invalid characters
    final RegExp validChars = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!validChars.hasMatch(username)) {
      throw 'Username can only contain letters, numbers, and underscores';
    }
    
    try {
      // Check in usernames collection (reserved usernames)
      final DocumentSnapshot usernameDoc = await _firestore
          .collection('usernames')
          .doc(username)
          .get();
            
      return !usernameDoc.exists;
    } catch (e) {
      print('Error checking username uniqueness: $e');
      throw 'Unable to verify username availability. Please check your internet connection and try again.';
    }
  }

  // Update username and timestamp
  static Future<void> updateUsername(String userId, String newUsername) async {
    try {
      final batch = _firestore.batch();
      final userDoc = _firestore.collection(Constants.users).doc(userId);
      final oldData = await userDoc.get();
      
      if (oldData.exists) {
        final oldUsername = oldData.data()?[Constants.name]?.toString().toLowerCase();
        if (oldUsername != null) {
          // Delete old username reservation
          batch.delete(_firestore.collection('usernames').doc(oldUsername));
        }
      }

      // Update user document
      batch.update(userDoc, {
        Constants.name: newUsername.trim(),
        Constants.lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
      });

      // Create new username reservation
      batch.set(_firestore.collection('usernames').doc(newUsername.toLowerCase()), {
        'uid': userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await batch.commit();
    } catch (e) {
      print('Error updating username: $e');
      throw 'Failed to update username. Please try again.';
    }
  }

  // Check if user can change username (1 week restriction)
  static Future<bool> canChangeUsername(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection(Constants.users)
          .doc(userId)
          .get();

      if (!userDoc.exists) return false;

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return false;

      final int? lastUsernameChange = userData[Constants.lastUsernameChange] as int?;
      if (lastUsernameChange == null) return true;

      final DateTime lastChangeDate = DateTime.fromMillisecondsSinceEpoch(lastUsernameChange);
      final Duration difference = DateTime.now().difference(lastChangeDate);
      return difference.inDays >= 7;
    } catch (e) {
      print('Error checking username change eligibility: $e');
      throw 'Unable to verify username change eligibility. Please try again.';
    }
  }

  // Get days remaining until next username change
  static Future<int> getDaysUntilNextChange(String userId) async {
    try {
      final DocumentSnapshot userDoc = await _firestore
          .collection(Constants.users)
          .doc(userId)
          .get();

      if (!userDoc.exists) return 0;

      final userData = userDoc.data() as Map<String, dynamic>?;
      if (userData == null) return 0;

      final int? lastUsernameChange = userData[Constants.lastUsernameChange] as int?;
      if (lastUsernameChange == null) return 0;

      final DateTime lastChangeDate = DateTime.fromMillisecondsSinceEpoch(lastUsernameChange);
      final DateTime nextChangeDate = lastChangeDate.add(const Duration(days: 7));
      final int daysRemaining = nextChangeDate.difference(DateTime.now()).inDays;
      return daysRemaining < 0 ? 0 : daysRemaining;
    } catch (e) {
      print('Error getting days until next change: $e');
      throw 'Unable to check remaining days for username change. Please try again.';
    }
  }
}
