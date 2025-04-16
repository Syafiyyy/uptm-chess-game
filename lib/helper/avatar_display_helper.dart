import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A helper class to consistently display user avatars across the app.
/// This ensures avatars look the same in profiles, game UI, and friends list.
class AvatarDisplayHelper {
  /// Default avatar path to use if none provided
  static const String defaultAvatarPath = 'assets/avatars/avatar1.svg';

  /// Build a circular avatar widget with consistent styling across the app
  static Widget buildAvatar({
    required String? avatarPath,
    double size = 40.0,
    Color backgroundColor = Colors.white,
    Color borderColor = Colors.grey,
    double borderWidth = 1.0,
  }) {
    // Ensure a default avatar path if none provided or empty
    String path = defaultAvatarPath;
    
    if (avatarPath != null && avatarPath.isNotEmpty) {
      // Check if it's a valid path or URL
      if (avatarPath.startsWith('http') || avatarPath.startsWith('https')) {
        // It's a network URL
        path = avatarPath;
      } else if (avatarPath.startsWith('assets/')) {
        // It's an asset path reference
        path = avatarPath;
      } else if (!avatarPath.contains('/')) {
        // It might be just a filename like 'avatar1.svg' - assume it's in assets/avatars
        path = 'assets/avatars/$avatarPath';
      } else {
        // Use as is
        path = avatarPath;
      }
    }
    
    // Create the container with the avatar
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildAvatarImage(path, size),
    );
  }
  
  /// Helper method to build the appropriate image widget based on path type
  static Widget _buildAvatarImage(String path, double size) {
    if (path.startsWith('http') || path.startsWith('https')) {
      // Network image
      return Image.network(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return SvgPicture.asset(
            defaultAvatarPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        },
      );
    } else if (path.endsWith('.svg')) {
      // SVG asset
      return SvgPicture.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.contain,
      );
    } else {
      // Try as a regular asset
      return Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return SvgPicture.asset(
            defaultAvatarPath,
            width: size,
            height: size,
            fit: BoxFit.contain,
          );
        },
      );
    }
  }
  
  /// Build a row with player avatar and name, perfect for game UI
  static Widget buildPlayerInfo({
    required String name,
    required String? avatarPath,
    double avatarSize = 32.0,
    bool nameFirst = false,
    TextStyle? nameStyle,
    Color? borderColor,
  }) {
    final avatar = buildAvatar(
      avatarPath: avatarPath,
      size: avatarSize,
      borderColor: borderColor ?? Colors.grey,
      borderWidth: 2.0,
    );
    
    final nameText = Text(
      name,
      style: nameStyle ?? const TextStyle(fontWeight: FontWeight.bold),
      overflow: TextOverflow.ellipsis,
    );
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: nameFirst
          ? [
              nameText,
              const SizedBox(width: 8),
              avatar,
            ]
          : [
              avatar,
              const SizedBox(width: 8),
              Flexible(child: nameText),
            ],
    );
  }
  
  /// Build a player vs player header for game screens
  static Widget buildGameVersusHeader({
    required String player1Name,
    required String? player1Avatar,
    required String player2Name,
    required String? player2Avatar,
    required bool player1IsWhite,
    double avatarSize = 36.0,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // First player
        Expanded(
          child: buildPlayerInfo(
            name: player1Name,
            avatarPath: player1Avatar,
            avatarSize: avatarSize,
            nameFirst: !player1IsWhite,
            borderColor: player1IsWhite ? Colors.white : Colors.black,
          ),
        ),
        
        // VS indicator
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.black12,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Text(
            'VS',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        
        // Second player
        Expanded(
          child: buildPlayerInfo(
            name: player2Name,
            avatarPath: player2Avatar,
            avatarSize: avatarSize,
            nameFirst: player1IsWhite,
            borderColor: player1IsWhite ? Colors.black : Colors.white,
          ),
        ),
      ],
    );
  }
  
  /// Build a friend list item with avatar and name
  static Widget buildFriendItem({
    required String name,
    required String? avatarPath,
    double avatarSize = 40.0,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
        child: Row(
          children: [
            buildAvatar(
              avatarPath: avatarPath,
              size: avatarSize,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(fontSize: 16),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
