import 'package:uptm_chess/constants.dart';

class UserModel {
  String uid;
  String name;
  String email;
  String image;
  int lastUsernameChange;
  int playerRating;
  String createdAt;
  String aiDifficulty;
  String preferredColor;
  String preferredTimeControl;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.image,
    required this.lastUsernameChange,
    required this.playerRating,
    required this.createdAt,
    this.aiDifficulty = 'Intermediate',
    this.preferredColor = 'White',
    this.preferredTimeControl = '10 Minutes',
  });

  Map<String, dynamic> toMap() {
    return {
      Constants.uid: uid,
      Constants.name: name,
      Constants.email: email,
      Constants.image: image,
      Constants.lastUsernameChange: lastUsernameChange,
      Constants.playerRating: playerRating,
      Constants.createdAt: createdAt,
      'aiDifficulty': aiDifficulty,
      'preferredColor': preferredColor,
      'preferredTimeControl': preferredTimeControl,
    };
  }

  factory UserModel.fromMap(Map<String, dynamic> map) {
    return UserModel(
      uid: map[Constants.uid] ?? '',
      name: map[Constants.name] ?? '',
      email: map[Constants.email] ?? '',
      image: map[Constants.image] ?? '',
      lastUsernameChange: map[Constants.lastUsernameChange] ?? DateTime.now().millisecondsSinceEpoch,
      playerRating: map[Constants.playerRating] ?? 1200,
      createdAt: map[Constants.createdAt] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      aiDifficulty: map['aiDifficulty'] ?? 'Intermediate',
      preferredColor: map['preferredColor'] ?? 'White',
      preferredTimeControl: map['preferredTimeControl'] ?? '10 Minutes',
    );
  }

  bool canChangeUsername() {
    final lastChange = DateTime.fromMillisecondsSinceEpoch(lastUsernameChange);
    final now = DateTime.now();
    final difference = now.difference(lastChange);
    return difference.inDays >= 7;
  }

  int daysUntilUsernameChange() {
    if (canChangeUsername()) return 0;
    
    final lastChange = DateTime.fromMillisecondsSinceEpoch(lastUsernameChange);
    final now = DateTime.now();
    final difference = now.difference(lastChange);
    return 7 - difference.inDays;
  }
}
