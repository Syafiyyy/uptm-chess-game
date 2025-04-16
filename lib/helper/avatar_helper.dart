import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../constants.dart';

class AvatarHelper {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // List of all available avatars
  static const List<String> avatarPaths = [
    'assets/avatars/avatar1.svg',
    'assets/avatars/avatar2.svg',
    'assets/avatars/avatar3.svg',
    'assets/avatars/avatar4.svg',
    'assets/avatars/avatar5.svg',
    'assets/avatars/avatar6.svg',
  ];
  
  // Default avatar if none is selected
  static const String defaultAvatar = 'assets/avatars/avatar1.svg';
  
  // Get avatar index from path
  static int getAvatarIndex(String avatarPath) {
    return avatarPaths.indexOf(avatarPath) != -1 
        ? avatarPaths.indexOf(avatarPath) 
        : 0;
  }
  
  // Get avatar path from index
  static String getAvatarPath(int index) {
    if (index >= 0 && index < avatarPaths.length) {
      return avatarPaths[index];
    }
    return defaultAvatar;
  }
  
  // Update user's avatar in Firestore
  static Future<void> updateUserAvatar(String userId, String avatarPath) async {
    try {
      await _firestore
          .collection(Constants.users)
          .doc(userId)
          .update({Constants.image: avatarPath});
    } catch (e) {
      print('Error updating avatar: $e');
      throw 'Failed to update avatar. Please try again.';
    }
  }
  
  // Widget to display avatar with consistent size and styling
  static Widget buildAvatar({
    required String avatarPath,
    double size = 40,
    BoxFit fit = BoxFit.contain,
    Color? colorFilter,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: avatarPath.endsWith('.svg')
          ? SvgPicture.asset(
              avatarPath,
              width: size,
              height: size,
              fit: fit,
              colorFilter: colorFilter != null 
                  ? ColorFilter.mode(colorFilter, BlendMode.srcIn) 
                  : null,
            )
          : Image.network(
              avatarPath,
              width: size,
              height: size,
              fit: fit,
              errorBuilder: (context, error, stackTrace) {
                return SvgPicture.asset(
                  defaultAvatar,
                  width: size,
                  height: size,
                  fit: fit,
                );
              },
            ),
    );
  }
}
