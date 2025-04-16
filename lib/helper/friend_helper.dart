import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../constants.dart';

class FriendHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Field names used in friends subcollections
  static const String usernameField = 'username';
  static const String imageField = 'image';
  static const String addedAtField = 'addedAt';
  static const String sentAtField = 'sentAt';

  /// Send a friend request to a user by username
  static Future<Map<String, dynamic>> sendFriendRequest(String targetUsername) async {
    try {
      // Get the target user
      final userQuery = await _firestore
          .collection(Constants.users)
          .where(Constants.name, isEqualTo: targetUsername)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return {'success': false, 'message': 'User not found'};
      }

      final friendDoc = userQuery.docs.first;
      final friendId = friendDoc.id;
      
      // Don't allow adding yourself
      if (friendId == _auth.currentUser?.uid) {
        return {'success': false, 'message': 'You cannot add yourself as a friend'};
      }

      // Check if already friends
      final friendshipCheck = await _firestore
          .collection(Constants.users)
          .doc(_auth.currentUser?.uid)
          .collection('friends')
          .doc(friendId)
          .get();

      if (friendshipCheck.exists) {
        return {'success': false, 'message': 'Already friends with this user'};
      }

      // Check if request already sent
      final requestCheck = await _firestore
          .collection(Constants.users)
          .doc(friendId)
          .collection('friendRequests')
          .doc(_auth.currentUser?.uid)
          .get();

      if (requestCheck.exists) {
        return {'success': false, 'message': 'Friend request already sent'};
      }

      // Get current user's data
      final currentUserDoc = await _firestore
          .collection(Constants.users)
          .doc(_auth.currentUser?.uid)
          .get();

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      // Send friend request
      await _firestore
          .collection(Constants.users)
          .doc(friendId)
          .collection('friendRequests')
          .doc(_auth.currentUser?.uid)
          .set({
        usernameField: currentUserData[Constants.name],
        imageField: currentUserData[Constants.image],
        sentAtField: FieldValue.serverTimestamp(),
      });

      return {'success': true, 'message': 'Friend request sent!'};
    } catch (e) {
      return {'success': false, 'message': 'Error sending friend request: $e'};
    }
  }

  /// Accept a friend request
  static Future<Map<String, dynamic>> acceptFriendRequest(String userId, String username) async {
    try {
      // Get the user's profile data
      final userData = await _firestore
          .collection(Constants.users)
          .doc(userId)
          .get();
      
      if (!userData.exists) {
        return {'success': false, 'message': 'User not found'};
      }
      
      final userDataMap = userData.data() as Map<String, dynamic>;
      
      // Get current user data
      final currentUserData = await _firestore
          .collection(Constants.users)
          .doc(_auth.currentUser?.uid)
          .get();
      
      // Add to both users' friends collections
      final batch = _firestore.batch();
      
      // Add friend to current user's friends collection
      batch.set(
        _firestore
          .collection(Constants.users)
          .doc(_auth.currentUser?.uid)
          .collection('friends')
          .doc(userId),
        {
          usernameField: userDataMap[Constants.name],
          imageField: userDataMap[Constants.image],
          addedAtField: FieldValue.serverTimestamp(),
        }
      );
      
      // Add current user to friend's friends collection
      batch.set(
        _firestore
          .collection(Constants.users)
          .doc(userId)
          .collection('friends')
          .doc(_auth.currentUser?.uid),
        {
          usernameField: currentUserData.data()?[Constants.name],
          imageField: currentUserData.data()?[Constants.image],
          addedAtField: FieldValue.serverTimestamp(),
        }
      );
      
      // Delete the friend request
      batch.delete(
        _firestore
          .collection(Constants.users)
          .doc(_auth.currentUser?.uid)
          .collection('friendRequests')
          .doc(userId)
      );
      
      await batch.commit();
      
      return {'success': true, 'message': 'Friend request accepted!'};
    } catch (e) {
      return {'success': false, 'message': 'Error accepting friend request: $e'};
    }
  }

  /// Get user's friends
  static Stream<QuerySnapshot> getFriendsStream() {
    return _firestore
        .collection(Constants.users)
        .doc(_auth.currentUser?.uid)
        .collection('friends')
        .orderBy(addedAtField, descending: true)
        .snapshots();
  }

  /// Get user's friend requests
  static Stream<QuerySnapshot> getFriendRequestsStream() {
    return _firestore
        .collection(Constants.users)
        .doc(_auth.currentUser?.uid)
        .collection('friendRequests')
        .orderBy(sentAtField, descending: true)
        .snapshots();
  }
}
