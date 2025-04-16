import 'package:cloud_firestore/cloud_firestore.dart';

enum GameResult {
  win,
  loss,
  draw,
}

class GameHistory {
  final String id;
  final String userId;
  final String opponent; // Can be AI difficulty level or other player's name
  final GameResult result;
  final int durationSeconds;
  final int moveCount;
  final DateTime timestamp;
  final bool wasOnline;
  final int? ratingChange; // Only applicable for online games

  GameHistory({
    required this.id,
    required this.userId,
    required this.opponent,
    required this.result,
    required this.durationSeconds,
    required this.moveCount,
    required this.timestamp,
    required this.wasOnline,
    this.ratingChange,
  });

  // Create from Firestore document
  factory GameHistory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    return GameHistory(
      id: doc.id,
      userId: data['userId'] ?? '',
      opponent: data['opponent'] ?? 'Unknown',
      result: GameResult.values[data['result'] ?? 0],
      durationSeconds: data['durationSeconds'] ?? 0,
      moveCount: data['moveCount'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      wasOnline: data['wasOnline'] ?? false,
      ratingChange: data['ratingChange'],
    );
  }

  // Convert to map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'opponent': opponent,
      'result': result.index,
      'durationSeconds': durationSeconds,
      'moveCount': moveCount,
      'timestamp': Timestamp.fromDate(timestamp),
      'wasOnline': wasOnline,
      'ratingChange': ratingChange,
    };
  }
}
