import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/models/game_model.dart';
import 'package:squares/squares.dart';

class RealtimeDatabaseService {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  
  // Reference to the games node in Realtime Database
  DatabaseReference get _gamesRef => _database.ref().child('games');
  
  // Reference to a specific game
  DatabaseReference gameRef(String gameId) => _gamesRef.child(gameId);
  
  // Create a new game in Realtime Database
  Future<void> createGame(GameModel game) async {
    try {
      await gameRef(game.gameId).set(game.toMap());
    } catch (e) {
      throw Exception('Failed to create game: $e');
    }
  }
  
  // Update game state
  Future<void> updateGameState(String gameId, Map<String, dynamic> updates) async {
    try {
      await gameRef(gameId).update(updates);
    } catch (e) {
      throw Exception('Failed to update game state: $e');
    }
  }
  
  // Update game position
  Future<void> updateGamePosition(String gameId, String positionFen) async {
    try {
      await gameRef(gameId).child(Constants.positonFen).set(positionFen);
    } catch (e) {
      throw Exception('Failed to update game position: $e');
    }
  }
  
  // Update player's time
  Future<void> updatePlayerTime(String gameId, bool isWhite, String time) async {
    try {
      final String timeKey = isWhite ? Constants.whitesTime : Constants.blacksTime;
      await gameRef(gameId).child(timeKey).set(time);
    } catch (e) {
      throw Exception('Failed to update player time: $e');
    }
  }
  
  // Update current move
  Future<void> updateCurrentMove(String gameId, bool isWhite, String move) async {
    try {
      final String moveKey = isWhite ? Constants.whitsCurrentMove : Constants.blacksCurrentMove;
      await gameRef(gameId).child(moveKey).set(move);
    } catch (e) {
      throw Exception('Failed to update current move: $e');
    }
  }
  
  // Listen for game changes
  StreamSubscription listenForGameChanges({
    required String gameId,
    required Function(GameModel) onGameChange,
    required Function(Object) onError,
  }) {
    return gameRef(gameId).onValue.listen(
      (event) {
        try {
          if (event.snapshot.value != null) {
            final data = event.snapshot.value as Map<dynamic, dynamic>;
            final gameModel = GameModel.fromMap(Map<String, dynamic>.from(data));
            onGameChange(gameModel);
          }
        } catch (e) {
          onError(e);
        }
      },
      onError: onError,
    );
  }
  
  // Listen for specific game property changes
  Stream<T> listenForPropertyChange<T>(String gameId, String property) {
    return gameRef(gameId).child(property).onValue.map((event) {
      return event.snapshot.value as T;
    });
  }
  
  // Record a move in the game
  Future<void> recordMove(String gameId, Move move, bool isWhitesTurn) async {
    try {
      // Convert move to string format
      final String moveString = '${move.from}${move.to}${move.promotion}';
      
      // Update the current move
      await updateCurrentMove(gameId, isWhitesTurn, moveString);
      
      // Add to moves list
      final DatabaseReference movesRef = gameRef(gameId).child(Constants.moves).push();
      await movesRef.set({
        'from': move.from,
        'to': move.to,
        'promotion': move.promotion,
        'isWhite': isWhitesTurn,
        'timestamp': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Failed to record move: $e');
    }
  }
  
  // End game and record result
  Future<void> endGame(String gameId, String winnerId, bool isGameOver) async {
    try {
      await gameRef(gameId).update({
        Constants.winnerId: winnerId,
        Constants.isGameOver: isGameOver,
      });
    } catch (e) {
      throw Exception('Failed to end game: $e');
    }
  }
  
  // Delete a game when it's completed
  Future<void> deleteGame(String gameId) async {
    try {
      await gameRef(gameId).remove();
    } catch (e) {
      throw Exception('Failed to delete game: $e');
    }
  }
  
  // Check if a game exists
  Future<bool> gameExists(String gameId) async {
    try {
      final snapshot = await gameRef(gameId).once();
      return snapshot.snapshot.exists;
    } catch (e) {
      throw Exception('Failed to check if game exists: $e');
    }
  }
  
  // Create a game node for move synchronization
  Future<void> createGameNode(String gameNode) async {
    try {
      final nodePath = gameNode.split('/');
      if (nodePath.length < 2) {
        throw Exception('Invalid game node path: $gameNode');
      }
      
      // Check if the node exists, if not create it
      final ref = _database.ref().child(nodePath[0]);
      final snapshot = await ref.child(nodePath[1]).once();
      
      if (!snapshot.snapshot.exists) {
        await ref.child(nodePath[1]).set({
          'initialized': true,
          'lastUpdated': ServerValue.timestamp,
        });
      }
    } catch (e) {
      throw Exception('Failed to create game node: $e');
    }
  }
  
  // Listen for opponent moves
  StreamSubscription listenForOpponentMove({
    required String gameNode,
    required Function(String, String) onNewMove,
  }) {
    final nodePath = gameNode.split('/');
    if (nodePath.length < 2) {
      throw Exception('Invalid game node path: $gameNode');
    }
    
    final movesRef = _database.ref().child(nodePath[0]).child(nodePath[1]);
    
    return movesRef.onChildAdded.listen((event) {
      try {
        if (event.snapshot.key != 'initialized' && event.snapshot.key != 'lastUpdated') {
          final moveData = event.snapshot.value as Map<dynamic, dynamic>;
          final from = moveData['from'] as String;
          final to = moveData['to'] as String;
          
          onNewMove(from, to);
        }
      } catch (e) {
        print('Error processing opponent move: $e');
      }
    });
  }
  
  // Send a move to the opponent
  Future<void> sendMove({
    required String gameNode,
    required String from,
    required String to,
    required String playerUid,
  }) async {
    try {
      final nodePath = gameNode.split('/');
      if (nodePath.length < 2) {
        throw Exception('Invalid game node path: $gameNode');
      }
      
      final movesRef = _database.ref().child(nodePath[0]).child(nodePath[1]).push();
      
      await movesRef.set({
        'from': from,
        'to': to,
        'playerUid': playerUid,
        'timestamp': ServerValue.timestamp,
      });
      
      // Update the last updated timestamp
      await _database.ref().child(nodePath[0]).child(nodePath[1]).update({
        'lastUpdated': ServerValue.timestamp,
      });
    } catch (e) {
      throw Exception('Failed to send move: $e');
    }
  }
}
