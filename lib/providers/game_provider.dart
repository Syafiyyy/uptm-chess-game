import 'dart:async';

import 'package:bishop/bishop.dart' as bishop;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:squares/squares.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/helper/uci_commands.dart';
import 'package:uptm_chess/models/user_model.dart';
import 'package:uptm_chess/models/game_model.dart';
import 'package:uptm_chess/models/game_history.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/providers/game_history_provider.dart';
import 'package:provider/provider.dart';
import 'package:square_bishop/square_bishop.dart';
import 'package:stockfish/stockfish.dart';
import 'package:uuid/uuid.dart';

class GameProvider extends ChangeNotifier {
  late bishop.Game _game = bishop.Game(variant: bishop.Variant.standard());
  late SquaresState _state = SquaresState.initial(0);
  bool _aiThinking = false;
  bool _flipBoard = false;
  bool _vsComputer = false;
  bool _isLoading = false;
  bool _playWhitesTimer = true;
  bool _playBlacksTimer = true;
  int _gameLevel = 1;
  int _incrementalValue = 0;
  int _player = Squares.white;
  Timer? _whitesTimer;
  Timer? _blacksTimer;
  int _whitesScore = 0;
  int _blacksSCore = 0;
  PlayerColor _playerColor = PlayerColor.white;
  GameDifficulty _gameDifficulty = GameDifficulty.easy;
  String _gameId = '';

  String get gameId => _gameId;

  Duration _whitesTime = Duration.zero;
  Duration _blacksTime = Duration.zero;

  // saved time
  Duration _savedWhitesTime = Duration.zero;
  Duration _savedBlacksTime = Duration.zero;

  bool get playWhitesTimer => _playWhitesTimer;
  bool get playBlacksTimer => _playBlacksTimer;

  int get whitesScore => _whitesScore;
  int get blacksScore => _blacksSCore;

  Timer? get whitesTimer => _whitesTimer;
  Timer? get blacksTimer => _blacksTimer;

  bishop.Game get game => _game;
  SquaresState get state => _state;
  bool get aiThinking => _aiThinking;
  bool get flipBoard => _flipBoard;

  int get gameLevel => _gameLevel;
  GameDifficulty get gameDifficulty => _gameDifficulty;

  int get incrementalValue => _incrementalValue;
  int get player => _player;
  PlayerColor get playerColor => _playerColor;

  Duration get whitesTime => _whitesTime;
  Duration get blacksTime => _blacksTime;

  Duration get savedWhitesTime => _savedWhitesTime;
  Duration get savedBlacksTime => _savedBlacksTime;

  // get method
  bool get vsComputer => _vsComputer;
  bool get isLoading => _isLoading;

  final FirebaseFirestore firebaseFirestore = FirebaseFirestore.instance;
  final FirebaseStorage firebaseStorage = FirebaseStorage.instance;

  // set play whitesTimer
  Future<void> setPlayWhitesTimer({required bool value}) async {
    _playWhitesTimer = value;
    notifyListeners();
  }

  // set play blacksTimer
  Future<void> setPlayBlactsTimer({required bool value}) async {
    _playBlacksTimer = value;
    notifyListeners();
  }

  // get position fen
  getPositionFen() {
    return game.fen;
  }

  // reset game
  void resetGame({required bool newGame}) {
    if (newGame) {
      // check if the player was white in the previous game
      // change the player
      if (_player == Squares.white) {
        _player = Squares.black;
      } else {
        _player = Squares.white;
      }
      notifyListeners();
    }
    // reset game
    _game = bishop.Game(variant: bishop.Variant.standard());
    _state = game.squaresState(_player);
  }

  // make squre move
  bool makeSquaresMove(Move move) {
    bool result = game.makeSquaresMove(move);
    notifyListeners();
    return result;
  }

  // make squre move
  bool makeStringMove(String bestMove) {
    bool result = game.makeMoveString(bestMove);
    notifyListeners();
    return result;
  }

  // set sqaures state
  Future<void> setSquaresState() async {
    _state = game.squaresState(player);
    notifyListeners();
  }

  // make random move
  void makeRandomMove() {
    _game.makeRandomMove();
    notifyListeners();
  }

  void flipTheBoard() {
    _flipBoard = !_flipBoard;
    notifyListeners();
  }

  void setAiThinking(bool value) {
    _aiThinking = value;
    notifyListeners();
  }

  // set incremental value
  void setIncrementalValue({required int value}) {
    _incrementalValue = value;
    notifyListeners();
  }

  // set vs computer
  void setVsComputer({required bool value}) {
    _vsComputer = value;
    notifyListeners();
  }

  void setIsLoading({required bool value}) {
    _isLoading = value;
    notifyListeners();
  }

  // set game time
  Future<void> setGameTime({
    required String newSavedWhitesTime,
    required String newSavedBlacksTime,
  }) async {
    // save the times
    _savedWhitesTime = Duration(minutes: int.parse(newSavedWhitesTime));
    _savedBlacksTime = Duration(minutes: int.parse(newSavedBlacksTime));
    notifyListeners();
    // set times
    setWhitesTime(_savedWhitesTime);
    setBlacksTime(_savedBlacksTime);
  }

  void setWhitesTime(Duration time) {
    _whitesTime = time;
    notifyListeners();
  }

  void setBlacksTime(Duration time) {
    _blacksTime = time;
    notifyListeners();
  }

  // set playerColor
  void setPlayerColor({required int player}) {
    _player = player;
    _playerColor =
        player == Squares.white ? PlayerColor.white : PlayerColor.black;
    notifyListeners();
  }

  // set difficulty
  void setGameDifficulty({required int level}) {
    _gameLevel = level;
    _gameDifficulty = level == 1
        ? GameDifficulty.easy
        : level == 2
            ? GameDifficulty.medium
            : GameDifficulty.hard;
    notifyListeners();
  }

  // pause whites timer
  void pauseWhitesTimer() {
    if (_whitesTimer != null) {
      _whitesTime += Duration(seconds: _incrementalValue);
      _whitesTimer!.cancel();
      notifyListeners();
    }
  }

  // pause blacks timer
  void pauseBlacksTimer() {
    if (_blacksTimer != null) {
      _blacksTime += Duration(seconds: _incrementalValue);
      _blacksTimer!.cancel();
      notifyListeners();
    }
  }

  // start blacks timer
  void startBlacksTimer({
    required BuildContext context,
    Stockfish? stockfish,
    required Function onNewGame,
  }) {
    _blacksTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _blacksTime = _blacksTime - const Duration(seconds: 1);
      notifyListeners();

      if (_blacksTime <= Duration.zero) {
        // blacks timeout - black has lost the game
        _blacksTimer!.cancel();
        notifyListeners();

        // show game over dialog
        if (context.mounted) {
          gameOverDialog(
            context: context,
            stockfish: stockfish,
            timeOut: true,
            whiteWon: true,
            onNewGame: onNewGame,
          );
        }
      }
    });
  }

  // start blacks timer
  void startWhitesTimer({
    required BuildContext context,
    Stockfish? stockfish,
    required Function onNewGame,
  }) {
    _whitesTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _whitesTime = _whitesTime - const Duration(seconds: 1);
      notifyListeners();

      if (_whitesTime <= Duration.zero) {
        // whites timeout - white has lost the game
        _whitesTimer!.cancel();
        notifyListeners();

        // show game over dialog
        if (context.mounted) {
          gameOverDialog(
            context: context,
            stockfish: stockfish,
            timeOut: true,
            whiteWon: false,
            onNewGame: onNewGame,
          );
        }
      }
    });
  }

  void gameOverListerner({
    required BuildContext context,
    Stockfish? stockfish,
    required Function onNewGame,
  }) {
    if (game.gameOver) {
      // pause the timers
      pauseWhitesTimer();
      pauseBlacksTimer();

      // cancel the gameStreamsubscription if its not null
      if (gameStreamSubScreiption != null) {
        gameStreamSubScreiption!.cancel();
      }

      // Save the game to history
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      final gameHistoryProvider =
          Provider.of<GameHistoryProvider>(context, listen: false);

      if (authProvider.userModel != null) {
        // Determine the game result
        GameResult result;
        if (game.checkmate) {
          // Determine winner based on whose turn it is (loser is in checkmate)
          // If it's white's turn and checkmate, white lost
          // If it's black's turn and checkmate, black lost
          bool whitePlayerLost = game.turn == 'w';
          
          // If player is white and white lost, or player is black and black lost -> player lost
          if ((playerColor == PlayerColor.white && whitePlayerLost) ||
              (playerColor == PlayerColor.black && !whitePlayerLost)) {
            result = GameResult.loss;
          } else {
            result = GameResult.win;
          }
        } else if (game.inDraw) {
          result = GameResult.draw;
        } else {
          // Default to draw for other game-ending conditions
          result = GameResult.draw;
        }

        // Use a default move count - we'll estimate based on typical game length
        // In a real implementation, you would track the actual number of moves during gameplay
        int moveCount = 15; // Default value for an average game

        final gameHistory = GameHistory(
          id: const Uuid().v4(),
          userId: authProvider.userModel!.uid,
          opponent: vsComputer
              ? 'AI ${gameDifficulty.toString().split('.').last}'
              : 'Online Player',
          result: result,
          durationSeconds: vsComputer
              ? _whitesTime.inSeconds + _blacksTime.inSeconds
              : savedWhitesTime.inSeconds + savedBlacksTime.inSeconds,
          moveCount: moveCount,
          timestamp: DateTime.now(),
          wasOnline: !vsComputer,
          ratingChange: !vsComputer
              ? (result == GameResult.win
                  ? 10
                  : (result == GameResult.loss ? -8 : 1))
              : null,
        );

        // Add to Firebase
        gameHistoryProvider.addGameToHistory(gameHistory);
      }

      // show game over dialog
      if (context.mounted) {
        gameOverDialog(
          context: context,
          stockfish: stockfish,
          timeOut: false,
          whiteWon: false,
          onNewGame: onNewGame,
        );
      }
    }
  }

  // game over dialog
  void gameOverDialog({
    required BuildContext context,
    Stockfish? stockfish,
    required bool timeOut,
    required bool whiteWon,
    required Function onNewGame,
  }) {
    // stop stockfish engine if running
    if (stockfish != null) {
      stockfish.stdin = UCICommands.stop;
    }

    // Determine the result details
    String resultMessage = '';
    String scoreDisplay = '';
    Color resultColor;
    IconData resultIcon;
    String resultTitle;
    int whiteScore = _whitesScore;
    int blackScore = _blacksSCore;
    bool userWon = false;
    bool isDraw = false;

    // Determine the result based on the game state
    if (timeOut) {
      if (whiteWon) {
        resultMessage = 'White won on time';
        whiteScore = _whitesScore + 1;
        scoreDisplay = '1 - 0';
        // Check if user is white
        userWon = _playerColor == PlayerColor.white;
      } else {
        resultMessage = 'Black won on time';
        blackScore = _blacksSCore + 1;
        scoreDisplay = '0 - 1';
        // Check if user is black
        userWon = _playerColor == PlayerColor.black;
      }
    } else if (game.checkmate) {
      if (game.turn == 'w') {
        // White is in checkmate, black won
        resultMessage = 'Black won by checkmate';
        blackScore = _blacksSCore + 1;
        scoreDisplay = '0 - 1';
        // If player is white, they lost (black won)
        userWon = _playerColor == PlayerColor.black;
      } else {
        // Black is in checkmate, white won
        resultMessage = 'White won by checkmate';
        whiteScore = _whitesScore + 1;
        scoreDisplay = '1 - 0';
        // If player is white, they won
        userWon = _playerColor == PlayerColor.white;
      }
    } else if (game.stalemate) {
      resultMessage = 'Draw by stalemate';
      scoreDisplay = '½ - ½';
      isDraw = true;
    } else if (game.insufficientMaterial) {
      resultMessage = 'Draw by insufficient material';
      scoreDisplay = '½ - ½';
      isDraw = true;
    } else if (game.inDraw || game.drawn) {
      resultMessage = 'Game ended in a draw';
      scoreDisplay = '½ - ½';
      isDraw = true;
    } else {
      // Fallback for other cases
      resultMessage = 'Game over';
      scoreDisplay = '½ - ½';
      isDraw = true;
    }

    // Set UI elements based on result
    if (userWon) {
      resultColor = const Color(0xFF4CAF50); // Green
      resultIcon = Icons.emoji_events_rounded;
      resultTitle = 'Victory!';
    } else if (isDraw) {
      resultColor = Colors.blue;
      resultIcon = Icons.handshake_rounded;
      resultTitle = 'Draw';
    } else {
      resultColor = Colors.red;
      resultIcon = Icons.close_rounded;
      resultTitle = 'Defeat';
    }

    // Calculate game duration
    int gameDurationInSeconds = vsComputer
        ? _whitesTime.inSeconds + _blacksTime.inSeconds
        : _savedWhitesTime.inSeconds + _savedBlacksTime.inSeconds;

    // Show enhanced dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.zero,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Result header
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: resultColor.withOpacity(0.1),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(
                    bottom: BorderSide(color: resultColor.withOpacity(0.3))),
              ),
              child: Column(
                children: [
                  Icon(resultIcon, color: resultColor, size: 36),
                  const SizedBox(height: 8),
                  Text(
                    resultTitle,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: resultColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scoreDisplay,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: resultColor,
                    ),
                  ),
                ],
              ),
            ),

            // Game info
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Game end reason
                  Text(
                    resultMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Game stats
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Icon(Icons.access_time, color: Colors.grey),
                          const SizedBox(height: 4),
                          Text(
                            '${gameDurationInSeconds ~/ 60}:${(gameDurationInSeconds % 60).toString().padLeft(2, '0')}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Text('Duration',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      Column(
                        children: [
                          const Icon(Icons.auto_graph, color: Colors.grey),
                          const SizedBox(height: 4),
                          Text(
                            '${(game.history.length ~/ 2)}', // Number of moves made
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const Text('Moves',
                              style:
                                  TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                      if (!vsComputer)
                        Column(
                          children: [
                            Icon(
                                userWon
                                    ? Icons.trending_up
                                    : (isDraw
                                        ? Icons.trending_flat
                                        : Icons.trending_down),
                                color: userWon
                                    ? Colors.green
                                    : (isDraw ? Colors.blue : Colors.red)),
                            const SizedBox(height: 4),
                            Text(
                              userWon ? '+10' : (isDraw ? '+1' : '-8'),
                              style: TextStyle(
                                fontWeight: FontWeight.w500,
                                color: userWon
                                    ? Colors.green
                                    : (isDraw ? Colors.blue : Colors.red),
                              ),
                            ),
                            const Text('Rating',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Row(
                children: [
                  // Cancel button - save game and return to home screen
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        // Save scores before returning to home screen
                        _whitesScore = whiteScore;
                        _blacksSCore = blackScore;

                        // Create and save game history
                        final authProvider =
                            Provider.of<AuthenticationProvider>(context,
                                listen: false);
                        final gameHistoryProvider =
                            Provider.of<GameHistoryProvider>(context,
                                listen: false);

                        if (authProvider.userModel != null) {
                          // Determine result based on UI results
                          GameResult result;
                          if (userWon) {
                            result = GameResult.win;
                          } else if (isDraw) {
                            result = GameResult.draw;
                          } else {
                            result = GameResult.loss;
                          }

                          // Calculate move count based on game history
                          int moveCount = (game.history.length ~/ 2);
                          if (moveCount == 0)
                            moveCount = 1; // Ensure at least 1 move

                          // Create game history object
                          final gameHistory = GameHistory(
                            id: const Uuid().v4(),
                            userId: authProvider.userModel!.uid,
                            opponent: vsComputer
                                ? 'AI ${gameDifficulty.toString().split('.').last}'
                                : 'Online Player',
                            result: result,
                            durationSeconds: gameDurationInSeconds,
                            moveCount: moveCount,
                            timestamp: DateTime.now(),
                            wasOnline: !vsComputer,
                            ratingChange: !vsComputer
                                ? (result == GameResult.win
                                    ? 10
                                    : (result == GameResult.loss ? -8 : 1))
                                : null,
                          );

                          // Save to database
                          gameHistoryProvider.addGameToHistory(gameHistory);
                        }

                        Navigator.pop(context);
                        // Return to home screen
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          Constants.homeScreen,
                          (route) => false,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey.shade700,
                        side: BorderSide(color: Colors.grey.shade300),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Home'),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // New Game button - save game and start a new one
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Save scores
                        _whitesScore = whiteScore;
                        _blacksSCore = blackScore;

                        // Create and save game history
                        final authProvider =
                            Provider.of<AuthenticationProvider>(context,
                                listen: false);
                        final gameHistoryProvider =
                            Provider.of<GameHistoryProvider>(context,
                                listen: false);

                        if (authProvider.userModel != null) {
                          // Determine result based on UI results
                          GameResult result;
                          if (userWon) {
                            result = GameResult.win;
                          } else if (isDraw) {
                            result = GameResult.draw;
                          } else {
                            result = GameResult.loss;
                          }

                          // Calculate move count based on game history
                          int moveCount = (game.history.length ~/ 2);
                          if (moveCount == 0)
                            moveCount = 1; // Ensure at least 1 move

                          // Create game history object
                          final gameHistory = GameHistory(
                            id: const Uuid().v4(),
                            userId: authProvider.userModel!.uid,
                            opponent: vsComputer
                                ? 'AI ${gameDifficulty.toString().split('.').last}'
                                : 'Online Player',
                            result: result,
                            durationSeconds: gameDurationInSeconds,
                            moveCount: moveCount,
                            timestamp: DateTime.now(),
                            wasOnline: !vsComputer,
                            ratingChange: !vsComputer
                                ? (result == GameResult.win
                                    ? 10
                                    : (result == GameResult.loss ? -8 : 1))
                                : null,
                          );

                          // Save to database
                          gameHistoryProvider.addGameToHistory(gameHistory);
                        }

                        Navigator.pop(context);
                        onNewGame(); // Start new game
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: resultColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('New Game'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _waitingText = '';

  String get waitingText => _waitingText;

  setWaitingText() {
    _waitingText = '';
    notifyListeners();
  }

  // search for player
  Future searchPlayer({
    required UserModel userModel,
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      debugPrint('=== ONLINE GAME DEBUG LOGS ===');
      debugPrint(
          'Starting searchPlayer with user: ${userModel.name}, UID: ${userModel.uid}');

      try {
        // First verify that current user is authenticated
        final auth = FirebaseAuth.instance;
        if (auth.currentUser == null) {
          debugPrint('ERROR: Auth user is null when trying to start a game');
          onFail('User is not authenticated. Please login again.');
          return;
        }

        // Force token refresh again to ensure authentication is current
        debugPrint('Forcing token refresh before querying games...');
        await auth.currentUser!.getIdToken(true);
        debugPrint('Auth token refreshed successfully');
      } catch (authError) {
        debugPrint('Auth error: $authError');
        // Continue anyway
      }

      // Get all available games
      debugPrint('Attempting to query the availableGames collection...');
      final availableGames =
          await firebaseFirestore.collection(Constants.availableGames).get();
      debugPrint(
          'Successfully retrieved ${availableGames.docs.length} available games');

      //check if there are any available games
      if (availableGames.docs.isNotEmpty) {
        final List<DocumentSnapshot> gamesList = availableGames.docs
            .where((element) => element[Constants.isPlaying] == false)
            .toList();

        // check if there are no games where isPlaying == false
        if (gamesList.isEmpty) {
          _waitingText = Constants.searchingPlayerText;
          notifyListeners();
          // create a new game
          createNewGameInFireStore(
            userModel: userModel,
            onSuccess: onSuccess,
            onFail: onFail,
          );
        } else {
          _waitingText = Constants.joiningGameText;
          notifyListeners();
          // join a game
          joinGame(
            game: gamesList.first,
            userModel: userModel,
            onSuccess: onSuccess,
            onFail: onFail,
          );
        }
      } else {
        _waitingText = Constants.searchingPlayerText;
        notifyListeners();
        // we don not have any available games - create a game
        createNewGameInFireStore(
          userModel: userModel,
          onSuccess: onSuccess,
          onFail: onFail,
        );
      }
    } on FirebaseException catch (e) {
      _isLoading = false;
      notifyListeners();
      onFail(e.toString());
    }
  }

  // create a game
  void createNewGameInFireStore({
    required UserModel userModel,
    required Function onSuccess,
    required Function(String) onFail,
  }) async {
    // create a game id
    _gameId = const Uuid().v4();
    notifyListeners();

    try {
      // Generate a unique game ID if not already set
      if (_gameId.isEmpty) {
        _gameId = const Uuid().v4();
        notifyListeners();
      }

      // Use the gameId as the document ID instead of the user's UID
      // This matches the security rules expectations
      await firebaseFirestore
          .collection(Constants.availableGames)
          .doc(_gameId) // Use gameId instead of userModel.uid
          .set({
        Constants.uid: '',
        Constants.name: '',
        Constants.image: '',
        Constants.userRating: 1200,
        Constants.gameCreatorUid: userModel.uid,
        Constants.gameCreatorName: userModel.name,
        Constants.gameCreatorImage: userModel.image,
        Constants.gameCreatorRating: userModel.playerRating,
        Constants.isPlaying: false,
        Constants.gameId: gameId,
        Constants.dateCreated: DateTime.now().microsecondsSinceEpoch.toString(),
        Constants.whitesTime: _savedWhitesTime.toString(),
        Constants.blacksTime: _savedBlacksTime.toString(),
      });

      onSuccess();
    } on FirebaseException catch (e) {
      onFail(e.toString());
    }
  }

  String _gameCreatorUid = '';
  String _gameCreatorName = '';
  String _gameCreatorPhoto = '';
  int _gameCreatorRating = 1200;
  String _userId = '';
  String _userName = '';
  String _userPhoto = '';
  int _userRating = 1200;

  String get gameCreatorUid => _gameCreatorUid;
  String get gameCreatorName => _gameCreatorName;
  String get gameCreatorPhoto => _gameCreatorPhoto;
  int get gameCreatorRating => _gameCreatorRating;
  String get userId => _userId;
  String get userName => _userName;
  String get userPhoto => _userPhoto;
  int get userRating => _userRating;

  /// Refresh user data from AuthenticationProvider
  /// Call this before displaying the game screen to ensure latest avatar is shown
  void refreshUserData(AuthenticationProvider authProvider) {
    if (authProvider.userModel != null) {
      if (authProvider.userModel!.uid == _gameCreatorUid) {
        _gameCreatorPhoto = authProvider.userModel!.image;
      } else {
        _userPhoto = authProvider.userModel!.image;
      }
      notifyListeners();
    }
  }

  // join game
  void joinGame({
    required DocumentSnapshot<Object?> game,
    required UserModel userModel,
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      // Store the gameId of the game we're joining
      final joiningGameId = game[Constants.gameId] as String;

      // Check if we have our own created game (now using gameId as document ID)
      String? ourGameId;
      // Find our created game by querying where gameCreatorUid matches our UID
      final ourGames = await firebaseFirestore
          .collection(Constants.availableGames)
          .where(Constants.gameCreatorUid, isEqualTo: userModel.uid)
          .get();

      if (ourGames.docs.isNotEmpty) {
        ourGameId = ourGames.docs.first.id;
      }

      // Debug log the state
      debugPrint('Joining game ID: $joiningGameId');
      debugPrint('Our created game ID (if any): $ourGameId');

      // get data from the game we are joining
      _gameCreatorUid = game[Constants.gameCreatorUid];
      _gameCreatorName = game[Constants.gameCreatorName];
      _gameCreatorPhoto = game[Constants.gameCreatorImage];
      _gameCreatorRating = game[Constants.gameCreatorRating];
      _userId = userModel.uid;
      _userName = userModel.name;
      _userPhoto = userModel.image;
      _userRating = userModel.playerRating;
      _gameId = game[Constants.gameId];
      notifyListeners();

      // If we had created our own game, delete it since we're joining another
      if (ourGameId != null) {
        debugPrint('Deleting our created game with ID: $ourGameId');
        await firebaseFirestore
            .collection(Constants.availableGames)
            .doc(ourGameId)
            .delete();
      }

      // initialize the gameModel
      final gameModel = GameModel(
        gameId: gameId,
        gameCreatorUid: _gameCreatorUid,
        userId: userId,
        positonFen: getPositionFen(),
        winnerId: '',
        whitesTime: game[Constants.whitesTime],
        blacksTime: game[Constants.blacksTime],
        whitsCurrentMove: '',
        blacksCurrentMove: '',
        boardState: state.board.flipped().toString(),
        playState: PlayState.ourTurn.name.toString(),
        isWhitesTurn: true,
        isGameOver: false,
        squareState: state.player,
        moves: state.moves.toList(),
      );

      // IMPORTANT: Create the parent document FIRST to satisfy security rules
      // Create a new game directory in fireStore
      debugPrint('Creating parent game document for gameId: $gameId');
      await firebaseFirestore
          .collection(Constants.runningGames)
          .doc(gameId)
          .set({
        // Make sure to include all necessary fields here
        Constants.gameCreatorUid: gameCreatorUid,
        Constants.gameCreatorName: gameCreatorName,
        Constants.gameCreatorImage: gameCreatorPhoto,
        Constants.gameCreatorRating: gameCreatorRating,
        Constants.userId: userId,
        Constants.name: userName, // Using name consistently across the app
        Constants.userImage: userPhoto,
        Constants.userRating: userRating,
        Constants.isPlaying: true,
        Constants.dateCreated: DateTime.now().microsecondsSinceEpoch.toString(),
        Constants.gameScore: '0-0',
      });

      // ONLY AFTER parent document exists, create the subcollection document
      debugPrint('Creating game subcollection document for gameId: $gameId');
      await firebaseFirestore
          .collection(Constants.runningGames)
          .doc(gameId)
          .collection(Constants.game)
          .doc(gameId)
          .set(gameModel.toMap());

      // update game settings depending on the data of the game we are joining
      await setGameDataAndSettings(game: game, userModel: userModel);

      onSuccess();
    } on FirebaseException catch (e) {
      onFail(e.toString());
    }
  }

  StreamSubscription? isPlayingStreamSubScription;

  // check if the other player has joined
  void checkIfOpponentJoined({
    required UserModel userModel,
    required Function() onSuccess,
  }) async {
    // First, find our game by gameCreatorUid
    final ourGames = await firebaseFirestore
        .collection(Constants.availableGames)
        .where(Constants.gameCreatorUid, isEqualTo: userModel.uid)
        .limit(1)
        .get();

    if (ourGames.docs.isEmpty) {
      debugPrint('No available game found with creator UID: ${userModel.uid}');
      return;
    }

    final ourGameId = ourGames.docs.first.id;
    debugPrint('Found our created game with ID: $ourGameId');

    // Stream firestore to check if a player has joined
    isPlayingStreamSubScription = firebaseFirestore
        .collection(Constants.availableGames)
        .doc(ourGameId)
        .snapshots()
        .listen((event) async {
      // chech if the game exist
      if (event.exists) {
        final DocumentSnapshot game = event;

        // chech if itsPlaying == true
        if (game[Constants.isPlaying]) {
          isPlayingStreamSubScription!.cancel();
          await Future.delayed(const Duration(milliseconds: 100));
          // get data from the game we are joining
          _gameCreatorUid = game[Constants.gameCreatorUid];
          _gameCreatorName = game[Constants.gameCreatorName];
          _gameCreatorPhoto = game[Constants.gameCreatorImage];
          _userId = game[Constants.uid];
          _userName = game[Constants.name];
          _userPhoto =
              game[Constants.image]; // Updated to use image consistently

          setPlayerColor(player: 0);
          notifyListeners();

          onSuccess();
        }
      }
    });
  }

  // set game data and settings
  Future<void> setGameDataAndSettings({
    required DocumentSnapshot<Object?> game,
    required UserModel userModel,
  }) async {
    // Get the gameId of the game we are joining
    final joiningGameId = game[Constants.gameId];

    // Use the gameId as the document ID, not the creator's UID
    final opponentsGame = firebaseFirestore
        .collection(Constants.availableGames)
        .doc(joiningGameId);

    // time - 0:10:00.0000000
    List<String> whitesTimeParts = game[Constants.whitesTime].split(':');
    List<String> blacksTimeParts = game[Constants.blacksTime].split(':');

    int whitesGameTime =
        int.parse(whitesTimeParts[0]) * 60 + int.parse(whitesTimeParts[1]);
    int blacksGamesTime =
        int.parse(blacksTimeParts[0]) * 60 + int.parse(blacksTimeParts[1]);

    // set game time
    await setGameTime(
      newSavedWhitesTime: whitesGameTime.toString(),
      newSavedBlacksTime: blacksGamesTime.toString(),
    );

    // update the created game in fireStore with consistent field names
    await opponentsGame.update({
      Constants.isPlaying: true,
      Constants.uid: userModel.uid,
      Constants.name: userModel.name,
      Constants.image:
          userModel.image, // Use image consistently instead of photoUrl
      Constants.userRating: userModel.playerRating,
    });

    // set the player state
    setPlayerColor(player: 1);
    notifyListeners();
  }

  bool _isWhitesTurn = true;
  String blacksMove = '';
  String whitesMove = '';
  bool _hasResigned = false;
  String _resignedPlayerId = '';

  bool get isWhitesTurn => _isWhitesTurn;
  bool get hasResigned => _hasResigned;
  String get resignedPlayerId => _resignedPlayerId;

  StreamSubscription? gameStreamSubScreiption;

  // Method to resign from an online game
  Future<void> resignGame({
    required UserModel userModel,
    required Function() onSuccess,
    required Function(String) onFail,
  }) async {
    try {
      if (_vsComputer || _gameId.isEmpty) {
        debugPrint('Cannot resign: not an online game or game ID is empty');
        onFail('Cannot resign from this game');
        return;
      }

      debugPrint(
          'Player ${userModel.name} (${userModel.uid}) is resigning from game $_gameId');

      // Update the game state in Firestore
      final gameRef = firebaseFirestore
          .collection(Constants.runningGames)
          .doc(_gameId)
          .collection(Constants.game)
          .doc(_gameId);

      // Get current game state
      final gameDoc = await gameRef.get();
      if (!gameDoc.exists) {
        debugPrint('Cannot resign: game document does not exist');
        onFail('Game not found');
        return;
      }

      // Set the resignation status
      await gameRef.update({
        Constants.hasResigned: true,
        Constants.resignedPlayerId: userModel.uid,
        Constants.isGameOver: true,
        Constants.winnerId:
            userModel.uid == _gameCreatorUid ? _userId : _gameCreatorUid,
      });

      // Update local state
      _hasResigned = true;
      _resignedPlayerId = userModel.uid;
      notifyListeners();

      onSuccess();
    } catch (e) {
      debugPrint('Error resigning from game: $e');
      onFail(e.toString());
    }
  }

  // listen for game changes in fireStore
  Future<void> listenForGameChanges({
    required BuildContext context,
    required UserModel userModel,
  }) async {
    CollectionReference gameCollectionReference = firebaseFirestore
        .collection(Constants.runningGames)
        .doc(gameId)
        .collection(Constants.game);

    gameStreamSubScreiption =
        gameCollectionReference.snapshots().listen((event) {
      if (event.docs.isNotEmpty) {
        // get the game
        final DocumentSnapshot game = event.docs.first;

        // check if we are white - this means we are the game creator
        if (game[Constants.gameCreatorUid] == userModel.uid) {
          // check if is white's turn
          if (game[Constants.isWhitesTurn]) {
            _isWhitesTurn = true;

            // check if blacksCurrentMove is not empty or equal the old move - means black has played his move
            // this means its our tuen to play
            if (game[Constants.blacksCurrentMove] != blacksMove) {
              // update the whites UI

              Move convertedMove = convertMoveStringToMove(
                moveString: game[Constants.blacksCurrentMove],
              );

              bool result = makeSquaresMove(convertedMove);
              if (result) {
                setSquaresState().whenComplete(() {
                  pauseBlacksTimer();
                  startWhitesTimer(context: context, onNewGame: () {});

                  gameOverListerner(context: context, onNewGame: () {});
                });
              }
            }
            notifyListeners();
          }
        } else {
          // not the game creator
          _isWhitesTurn = false;

          // check is white played his move
          if (game[Constants.whitsCurrentMove] != whitesMove) {
            Move convertedMove = convertMoveStringToMove(
              moveString: game[Constants.whitsCurrentMove],
            );
            bool result = makeSquaresMove(convertedMove);

            if (result) {
              setSquaresState().whenComplete(() {
                pauseWhitesTimer();
                startBlacksTimer(context: context, onNewGame: () {});

                gameOverListerner(context: context, onNewGame: () {});
              });
            }
          }
          notifyListeners();
        }
      }
    });
  }

  // convert move string to move format
  Move convertMoveStringToMove({required String moveString}) {
    // Split the move string intp its components
    List<String> parts = moveString.split('-');

    // Extract 'from' and 'to'
    int from = int.parse(parts[0]);
    int to = int.parse(parts[1].split('[')[0]);

    // Extract 'promo' and 'piece' if available
    String? promo;
    String? piece;
    if (moveString.contains('[')) {
      String extras = moveString.split('[')[1].split(']')[0];
      List<String> extraList = extras.split(',');
      promo = extraList[0];
      if (extraList.length > 1) {
        piece = extraList[1];
      }
    }

    // Create and return a new Move object
    return Move(
      from: from,
      to: to,
      promo: promo,
      piece: piece,
    );
  }

  // play move and save to fireStore
  Future<void> playMoveAndSaveToFireStore({
    required BuildContext context,
    required Move move,
    required bool isWhitesMove,
  }) async {
    // check if its whites move
    if (isWhitesMove) {
      await firebaseFirestore
          .collection(Constants.runningGames)
          .doc(gameId)
          .collection(Constants.game)
          .doc(gameId)
          .update({
        Constants.positonFen: getPositionFen(),
        Constants.whitsCurrentMove: move.toString(),
        Constants.moves: FieldValue.arrayUnion([move.toString()]),
        Constants.isWhitesTurn: false,
        Constants.playState: PlayState.theirTurn.name.toString(),
      });

      // pause whites timer and start blacks timer
      pauseWhitesTimer();

      Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
        startBlacksTimer(
          context: context,
          onNewGame: () {},
        );
      });
    } else {
      await firebaseFirestore
          .collection(Constants.runningGames)
          .doc(gameId)
          .collection(Constants.game)
          .doc(gameId)
          .update({
        Constants.positonFen: getPositionFen(),
        Constants.blacksCurrentMove: move.toString(),
        Constants.moves: FieldValue.arrayUnion([move.toString()]),
        Constants.isWhitesTurn: true,
        Constants.playState: PlayState.ourTurn.name.toString(),
      });

      // pause blacks timer and start whites timer
      pauseBlacksTimer();

      Future.delayed(const Duration(milliseconds: 100)).whenComplete(() {
        startWhitesTimer(
          context: context,
          onNewGame: () {},
        );
      });
    }
  }
}
