import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/helper/avatar_display_helper.dart';
import 'package:uptm_chess/helper/helper_methods.dart';
import 'package:uptm_chess/helper/uci_commands.dart';
import 'package:uptm_chess/models/user_model.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/providers/game_provider.dart';
import 'package:uptm_chess/service/assets_manager.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:provider/provider.dart';

import 'package:squares/squares.dart';
import 'package:stockfish/stockfish.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late Stockfish stockfish;

  @override
  void initState() {
    stockfish = Stockfish();
    final gameProvider = context.read<GameProvider>();
    gameProvider.resetGame(newGame: false);

    if (mounted) {
      letOtherPlayerPlayFirst();
    }
    super.initState();
  }

  @override
  void dispose() {
    stockfish.dispose();
    super.dispose();
  }

  void letOtherPlayerPlayFirst() {
    // wait for widget to rebuild
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final gameProvider = context.read<GameProvider>();

      if (gameProvider.vsComputer) {
        if (gameProvider.state.state == PlayState.theirTurn &&
            !gameProvider.aiThinking) {
          gameProvider.setAiThinking(true);

          // wait auntil stockfish is ready
          await waitUntilReady();

          // get the current position of the board and sent to stockfish
          stockfish.stdin =
              '${UCICommands.position} ${gameProvider.getPositionFen()}';

          // set stockfish level
          stockfish.stdin =
              '${UCICommands.goMoveTime} ${gameProvider.gameLevel * 1000}';

          stockfish.stdout.listen((event) {
            if (event.contains(UCICommands.bestMove)) {
              final bestMove = event.split(' ')[1];
              gameProvider.makeStringMove(bestMove);
              gameProvider.setAiThinking(false);
              gameProvider.setSquaresState().whenComplete(() {
                if (gameProvider.player == Squares.white) {
                  // check if we can play whitesTimer
                  if (gameProvider.playWhitesTimer) {
                    // pause timer for black
                    gameProvider.pauseBlacksTimer();

                    startTimer(
                      isWhiteTimer: true,
                      onNewGame: () {},
                    );

                    gameProvider.setPlayWhitesTimer(value: false);
                  }
                } else {
                  if (gameProvider.playBlacksTimer) {
                    // pause timer for white
                    gameProvider.pauseWhitesTimer();

                    startTimer(
                      isWhiteTimer: false,
                      onNewGame: () {},
                    );

                    gameProvider.setPlayBlactsTimer(value: false);
                  }
                }
              });
            }
          });
        }
      } else {
        final userModel = context.read<AuthenticationProvider>().userModel;
        // listen for game changes in fireStore
        gameProvider.listenForGameChanges(
            context: context, userModel: userModel!);
      }
    });
  }

  void _onMove(Move move) async {
    log('move: ${move.toString()}');
    log('String move: ${move.algebraic()}');
    final gameProvider = context.read<GameProvider>();
    bool result = gameProvider.makeSquaresMove(move);
    if (result) {
      gameProvider.setSquaresState().whenComplete(() async {
        if (gameProvider.player == Squares.white) {
          // check if we are playing vs computer
          if (gameProvider.vsComputer) {
            // pause timer for white
            gameProvider.pauseWhitesTimer();

            startTimer(
              isWhiteTimer: false,
              onNewGame: () {},
            );
            // set whites bool flag to true so that we dont run this code agin until true
            gameProvider.setPlayWhitesTimer(value: true);
          } else {
            // play and save white's move to fireStore
            await gameProvider.playMoveAndSaveToFireStore(
              context: context,
              move: move,
              isWhitesMove: true,
            );
          }
        } else {
          if (gameProvider.vsComputer) {
            // pause timer for black
            gameProvider.pauseBlacksTimer();

            startTimer(
              isWhiteTimer: true,
              onNewGame: () {},
            );
            // set blacks bool flag to true so that we dont run this code agin until true
            gameProvider.setPlayBlactsTimer(value: true);
          } else {
            // play and save black's move to fireStore
            await gameProvider.playMoveAndSaveToFireStore(
              context: context,
              move: move,
              isWhitesMove: false,
            );
          }
        }
      });
    }

    if (gameProvider.vsComputer) {
      if (gameProvider.state.state == PlayState.theirTurn &&
          !gameProvider.aiThinking) {
        gameProvider.setAiThinking(true);

        // wait until stockfish is ready
        await waitUntilReady();

        // Configure AI based on difficulty level
        final difficulty = gameProvider.gameDifficulty;
        int skillLevel;
        int searchDepth;
        int moveTime;
        
        // Set parameters based on difficulty
        switch (difficulty) {
          case GameDifficulty.easy:
            skillLevel = 5;
            searchDepth = 5;
            moveTime = 500;
            break;
          case GameDifficulty.medium:
            skillLevel = 10;
            searchDepth = 10;
            moveTime = 1000;
            break;
          case GameDifficulty.hard:
            skillLevel = 20;
            searchDepth = 15;
            moveTime = 2000;
            break;
        }
        
        // Set skill level
        stockfish.stdin = '${UCICommands.setOption} ${UCICommands.skillLevel} $skillLevel';
        await Future.delayed(const Duration(milliseconds: 100));
        
        // get the current position of the board and sent to stockfish
        stockfish.stdin = '${UCICommands.position} ${gameProvider.getPositionFen()}';
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Use both search depth and move time
        stockfish.stdin = '${UCICommands.goDepth} $searchDepth movetime $moveTime';

        stockfish.stdout.listen((event) {
          if (event.contains(UCICommands.bestMove)) {
            final bestMove = event.split(' ')[1];
            gameProvider.makeStringMove(bestMove);
            gameProvider.setAiThinking(false);
            gameProvider.setSquaresState().whenComplete(() {
              if (gameProvider.player == Squares.white) {
                // check if we can play whitesTimer
                if (gameProvider.playWhitesTimer) {
                  // pause timer for black
                  gameProvider.pauseBlacksTimer();

                  startTimer(
                    isWhiteTimer: true,
                    onNewGame: () {},
                  );

                  gameProvider.setPlayWhitesTimer(value: false);
                }
              } else {
                if (gameProvider.playBlacksTimer) {
                  // pause timer for white
                  gameProvider.pauseWhitesTimer();

                  startTimer(
                    isWhiteTimer: false,
                    onNewGame: () {},
                  );

                  gameProvider.setPlayBlactsTimer(value: false);
                }
              }
            });
          }
        });

        // await Future.delayed(
        //     Duration(milliseconds: Random().nextInt(4750) + 250));
        // gameProvider.game.makeRandomMove();
        // gameProvider.setAiThinking(false);
        // gameProvider.setSquaresState().whenComplete(() {
        //   if (gameProvider.player == Squares.white) {
        //     // pause timer for black
        //     gameProvider.pauseBlacksTimer();

        //     startTimer(
        //       isWhiteTimer: true,
        //       onNewGame: () {},
        //     );
        //   } else {
        //     // pause timer for white
        //     gameProvider.pauseWhitesTimer();

        //     startTimer(
        //       isWhiteTimer: false,
        //       onNewGame: () {},
        //     );
        //   }
        // });
      }
    }

    await Future.delayed(const Duration(seconds: 1));
    // listen if its game over
    checkGameOverListener();
  }

  Future<void> waitUntilReady() async {
    while (stockfish.state.value != StockfishState.ready) {
      await Future.delayed(const Duration(seconds: 1));
    }
  }

  void checkGameOverListener() {
    final gameProvider = context.read<GameProvider>();

    gameProvider.gameOverListerner(
      context: context,
      stockfish: stockfish,
      onNewGame: () {
        // start new game
      },
    );
  }

  void startTimer({
    required bool isWhiteTimer,
    required Function onNewGame,
  }) {
    final gameProvider = context.read<GameProvider>();
    if (isWhiteTimer) {
      // start timer for White
      gameProvider.startWhitesTimer(
        context: context,
        stockfish: stockfish,
        onNewGame: onNewGame,
      );
    } else {
      // start timer for black
      gameProvider.startBlacksTimer(
        context: context,
        stockfish: stockfish,
        onNewGame: onNewGame,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get providers and refresh avatar data
    final authProvider = context.read<AuthenticationProvider>();
    final gameProvider = context.read<GameProvider>();
    final userModel = authProvider.userModel;
    
    // Refresh user data in GameProvider to ensure avatar is up to date
    gameProvider.refreshUserData(authProvider);
    return PopScope(
      canPop: false,
      onPopInvoked: (didpop) async {
        if (didpop) return;
        bool? leave = await _showExitConfirmDialog(context);
        if (leave != null && leave) {
          stockfish.stdin = UCICommands.stop;
          await Future.delayed(const Duration(milliseconds: 200))
              .whenComplete(() {
            // if the user confirms, navigate to home screen
            Navigator.pushNamedAndRemoveUntil(
                context, Constants.homeScreen, (route) => false);
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF5F7FA),
        appBar: AppBar(
          backgroundColor: AppTheme.primaryBlue,
          centerTitle: true,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_rounded,
              color: AppTheme.primaryWhite,
              size: 22,
            ),
            onPressed: () async {
              final shouldExit = await _showExitConfirmDialog(context);
              if (shouldExit == true) {
                Navigator.pop(context);
              }
            },
          ),
          title: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_esports, color: Colors.white, size: 24),
              SizedBox(width: 8),
              Text(
                'Chess',
                style: TextStyle(
                  color: AppTheme.primaryWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 22,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        body: Consumer<GameProvider>(
          builder: (context, gameProvider, child) {
            String whitesTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: true,
            );
            String blacksTimer = getTimerToDisplay(
              gameProvider: gameProvider,
              isUser: false,
            );
            return Column(
              children: [
                const SizedBox(height: 8),
                // Opponent data - with modern styling
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.white,
                        const Color(0xFFF0F4FF),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: showOpponentsData(
                    gameProvider: gameProvider,
                    userModel: userModel!,
                    timeToShow: blacksTimer,
                  ),
                ),

                // Chess board with enhanced appearance
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlack.withOpacity(0.15),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                        spreadRadius: 0,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.8),
                        blurRadius: 8,
                        offset: const Offset(0, -4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: gameProvider.vsComputer
                        ? BoardController(
                            state: gameProvider.flipBoard
                                ? gameProvider.state.board.flipped()
                                : gameProvider.state.board,
                            playState: gameProvider.state.state,
                            pieceSet: PieceSet.merida(),
                            theme: BoardTheme.brown,
                            moves: gameProvider.state.moves,
                            onMove: _onMove,
                            onPremove: _onMove,
                            markerTheme: MarkerTheme(
                              empty: MarkerTheme.dot,
                              piece: MarkerTheme.corners(),
                            ),
                            promotionBehaviour: PromotionBehaviour.autoPremove,
                          )
                        : buildChessBoard(
                            gameProvider: gameProvider,
                            userModel: userModel,
                          ),
                  ),
                ),

                // Modern game control buttons
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 16.0),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildControlButton(
                        icon: Icons.refresh_rounded,
                        label: 'New Game',
                        color: AppTheme.primaryRed,
                        onPressed: () => gameProvider.resetGame(newGame: false),
                      ),
                      _buildControlButton(
                        icon: Icons.flip,
                        label: 'Flip',
                        color: AppTheme.primaryBlue,
                        onPressed: () => gameProvider.flipTheBoard(),
                      ),
                      _buildControlButton(
                        icon: Icons.undo_rounded,
                        label: 'Undo',
                        color: AppTheme.darkBlue,
                        onPressed:
                            () {}, // Implement undo functionality if needed
                      ),
                      // Only show resign button for online games
                      if (!gameProvider.vsComputer)
                        _buildControlButton(
                          icon: Icons.flag_outlined,
                          label: 'Resign',
                          color: Colors.orange,
                          onPressed: () => _showResignConfirmDialog(context, userModel),
                        ),
                    ],
                  ),
                ),

                // Player data - with modern styling
                Container(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 6.0),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12.0, vertical: 8.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFE6F0FF),
                        const Color(0xFFD4E6FF),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: AvatarDisplayHelper.buildAvatar(
                          avatarPath: userModel.image,
                          size: 48,
                          borderColor: AppTheme.primaryBlue,
                          borderWidth: 2.0,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              userModel.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Rating: ${userModel.playerRating}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.timer_outlined,
                                size: 16, color: AppTheme.primaryBlue),
                            const SizedBox(width: 4),
                            Text(
                              whitesTimer,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget buildChessBoard({
    required GameProvider gameProvider,
    required UserModel userModel,
  }) {
    bool isOurTurn = gameProvider.isWhitesTurn ==
        (gameProvider.gameCreatorUid == userModel.uid);

    log('CHESS UID: ${gameProvider.player}');

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: BoardController(
        state: gameProvider.flipBoard
            ? gameProvider.state.board.flipped()
            : gameProvider.state.board,
        playState: isOurTurn ? PlayState.ourTurn : PlayState.theirTurn,
        pieceSet: PieceSet.merida(),
        theme: BoardTheme.brown,
        moves: gameProvider.state.moves,
        onMove: _onMove,
        onPremove: _onMove,
        markerTheme: MarkerTheme(
          empty: MarkerTheme.dot,
          piece: MarkerTheme.corners(),
        ),
        promotionBehaviour: PromotionBehaviour.autoPremove,
      ),
    );
  }

  getState({required GameProvider gameProvider}) {
    if (gameProvider.flipBoard) {
      return gameProvider.state.board.flipped();
    } else {
      gameProvider.state.board;
    }
  }

  Widget showOpponentsData({
    required GameProvider gameProvider,
    required UserModel userModel,
    required String timeToShow,
  }) {
    if (gameProvider.vsComputer) {
      return Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 24,
              backgroundColor: Colors.transparent,
              backgroundImage: AssetImage(AssetsManager.stockfishIcon),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Stockfish',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Rating: ${gameProvider.gameLevel * 1000}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.timer_outlined,
                    size: 16, color: AppTheme.primaryBlack),
                const SizedBox(width: 4),
                Text(
                  timeToShow,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      );
    } else {
      // check is we are the creator of this game
      if (gameProvider.gameCreatorUid == userModel.uid) {
        return ListTile(
          leading: AvatarDisplayHelper.buildAvatar(
            avatarPath: gameProvider.userPhoto,
            size: 50,
            borderColor: Colors.blue.shade300,
            borderWidth: 2.0,
          ),
          title: Text(gameProvider.userName),
          subtitle: Text('Rating: ${gameProvider.userRating}'),
          trailing: Text(
            timeToShow,
            style: const TextStyle(fontSize: 16),
          ),
        );
      } else {
        return ListTile(
          leading: AvatarDisplayHelper.buildAvatar(
            avatarPath: gameProvider.gameCreatorPhoto,
            size: 50,
            borderColor: Colors.blue.shade300,
            borderWidth: 2.0,
          ),
          title: Text(gameProvider.gameCreatorName),
          subtitle: Text('Rating: ${gameProvider.gameCreatorRating}'),
          trailing: Text(
            timeToShow,
            style: const TextStyle(fontSize: 16),
          ),
        );
      }
    }
  }

  Future<bool?> _showExitConfirmDialog(BuildContext context) async {
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                color: AppTheme.primaryRed,
                size: 48,
              ),
              const SizedBox(height: 16),
              const Text(
                'Leave Game?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to leave this game?',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: BorderSide(color: AppTheme.primaryBlue),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryRed,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Leave',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show confirmation dialog for resignation
  Future<void> _showResignConfirmDialog(BuildContext context, UserModel? userModel) async {
    if (userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User data not available')),
      );
      return;
    }
    
    final gameProvider = context.read<GameProvider>();
    
    final bool? shouldResign = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Resign Game'),
        content: const Text('Are you sure you want to resign this game? This will count as a loss.'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(false),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryBlue,
                  side: BorderSide(color: AppTheme.primaryBlue),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryRed,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Resign', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
    
    if (shouldResign == true) {
      // Handle resignation
      gameProvider.resignGame(
        userModel: userModel,
        onSuccess: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You resigned the game')),
          );
          // Optional: navigate back to home screen after a short delay
          Future.delayed(const Duration(seconds: 2), () {
            Navigator.pushNamedAndRemoveUntil(
              context, Constants.homeScreen, (route) => false);
          });
        },
        onFail: (error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $error')),
          );
        },
      );
    }
  }

  // Modern stylish control button for game actions
  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
