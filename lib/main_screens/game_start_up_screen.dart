import 'package:flutter/material.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/providers/game_provider.dart';
import 'package:uptm_chess/widgets/widgets.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uptm_chess/models/user_model.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';

class GameStartUpScreen extends StatefulWidget {
  const GameStartUpScreen({
    super.key,
    required this.isCustomTime,
    required this.gameTime,
  });

  final bool isCustomTime;
  final String gameTime;

  @override
  State<GameStartUpScreen> createState() => _GameStartUpScreenState();
}

class _GameStartUpScreenState extends State<GameStartUpScreen> {
  PlayerColor playerColorGroup = PlayerColor.white;
  GameDifficulty gameLevelGroup = GameDifficulty.easy;

  int whiteTimeInMenutes = 0;
  int blackTimeInMenutes = 0;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: AppTheme.primaryBlue,
        centerTitle: true,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.settings, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Game Setup',
              style: TextStyle(
                color: AppTheme.primaryWhite,
                fontWeight: FontWeight.w600,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.primaryWhite,
            size: 22,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Consumer<GameProvider>(
        builder: (context, gameProvider, child) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Player Color Selection Section
                Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0, bottom: 12.0),
                        child: Text(
                          'Select Side',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F394B),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // White selection option with modern styling
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5 - 24,
                            decoration: BoxDecoration(
                              color: gameProvider.playerColor == PlayerColor.white ? 
                                const Color(0xFFF0F4FF) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: gameProvider.playerColor == PlayerColor.white ?
                                Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1.5) :
                                Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                            ),
                            child: InkWell(
                              onTap: () {
                                gameProvider.setPlayerColor(player: 0); // Squares.white = 0
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                                child: Row(
                                  children: [
                                    Radio<PlayerColor>(
                                      value: PlayerColor.white,
                                      groupValue: gameProvider.playerColor,
                                      activeColor: AppTheme.primaryBlue,
                                      onChanged: (value) {
                                        gameProvider.setPlayerColor(player: 0);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Play as white',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          // Black selection option with modern styling
                          Container(
                            width: MediaQuery.of(context).size.width * 0.5 - 24,
                            decoration: BoxDecoration(
                              color: gameProvider.playerColor == PlayerColor.black ? 
                                const Color(0xFFF0F4FF) : Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                              border: gameProvider.playerColor == PlayerColor.black ?
                                Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1.5) :
                                Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
                            ),
                            child: InkWell(
                              onTap: () {
                                gameProvider.setPlayerColor(player: 1); // Squares.black = 1
                              },
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 12.0),
                                child: Row(
                                  children: [
                                    Radio<PlayerColor>(
                                      value: PlayerColor.black,
                                      groupValue: gameProvider.playerColor,
                                      activeColor: AppTheme.primaryBlue,
                                      onChanged: (value) {
                                        gameProvider.setPlayerColor(player: 1);
                                      },
                                    ),
                                    const SizedBox(width: 4),
                                    const Text(
                                      'Play as black',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      widget.isCustomTime
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            child: BuildCustomTime(
                              time: whiteTimeInMenutes.toString(),
                              onLeftArrowCricked: () {
                                setState(() {
                                  whiteTimeInMenutes--;
                                });
                              },
                              onRightArrowCricked: () {
                                setState(() {
                                  whiteTimeInMenutes++;
                                });
                              })
                          )
                        : Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.timer_outlined, size: 18, color: AppTheme.primaryBlue),
                                  const SizedBox(width: 8),
                                  Text(
                                    widget.gameTime,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16, 
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(
                  height: 20,
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    widget.isCustomTime
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            child: BuildCustomTime(
                              time: blackTimeInMenutes.toString(),
                              onLeftArrowCricked: () {
                                setState(() {
                                  blackTimeInMenutes--;
                                });
                              },
                              onRightArrowCricked: () {
                                setState(() {
                                  blackTimeInMenutes++;
                                });
                              })
                          )
                        : Container(
                            height: 40,
                            decoration: BoxDecoration(
                                border:
                                    Border.all(width: 0.5, color: Colors.black),
                                borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(6.0),
                              child: Center(
                                child: Text(
                                  widget.gameTime,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 20, color: Colors.black),
                                ),
                              ),
                            ),
                          ),
                    const Spacer(),
                    widget.isCustomTime
                        ? Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
                            child: BuildCustomTime(
                              time: blackTimeInMenutes.toString(),
                              onLeftArrowCricked: () {
                                setState(() {
                                  blackTimeInMenutes--;
                                });
                              },
                              onRightArrowCricked: () {
                                setState(() {
                                  blackTimeInMenutes++;
                                });
                              })
                          )
                        : const SizedBox(width: 0),
                  ],
                ),
                const SizedBox(
                  height: 30,
                ),
                // Game Difficulty Section
                Container(
                  margin: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(left: 6.0, bottom: 12.0),
                        child: Text(
                          'Game Difficulty',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2F394B),
                          ),
                        ),
                      ),
                      gameProvider.vsComputer
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Easy difficulty
                                _buildDifficultyButton(
                                  context: context,
                                  title: 'Easy',
                                  icon: Icons.sentiment_satisfied_outlined,
                                  isSelected: gameProvider.gameDifficulty == GameDifficulty.easy,
                                  onTap: () {
                                    gameProvider.setGameDifficulty(level: 1);
                                  },
                                ),
                                // Medium difficulty
                                _buildDifficultyButton(
                                  context: context,
                                  title: 'Medium',
                                  icon: Icons.sentiment_neutral_outlined,
                                  isSelected: gameProvider.gameDifficulty == GameDifficulty.medium,
                                  onTap: () {
                                    gameProvider.setGameDifficulty(level: 2);
                                  },
                                ),
                                // Hard difficulty
                                _buildDifficultyButton(
                                  context: context,
                                  title: 'Hard',
                                  icon: Icons.sentiment_very_dissatisfied_outlined,
                                  isSelected: gameProvider.gameDifficulty == GameDifficulty.hard,
                                  onTap: () {
                                    gameProvider.setGameDifficulty(level: 3);
                                  },
                                ),
                              ],
                            )
                          : Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.people_outline, color: Colors.grey.shade600),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Online multiplayer mode',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),
                const Spacer(),

                // Modern play button
                gameProvider.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            playGame(gameProvider: gameProvider);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.play_circle_outline, size: 24),
                              SizedBox(width: 8),
                              Text(
                                'Start Game',
                                style: TextStyle(
                                  fontSize: 18, 
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                const SizedBox(
                  height: 20,
                ),

                gameProvider.vsComputer
                    ? const SizedBox.shrink()
                    : Text(gameProvider.waitingText),
              ],
            ),
          );
        },
      ),
    );
  }

  void playGame({
    required GameProvider gameProvider,
  }) async {
    final firebaseUser = FirebaseAuth.instance.currentUser;

    // Check if user is logged in through Firebase Auth
    if (!gameProvider.vsComputer && firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('You need to be logged in to play online matches')),
      );
      return;
    }

    // For online games, get the actual user profile from Firestore
    UserModel? userModel;
    if (!gameProvider.vsComputer && firebaseUser != null) {
      debugPrint('Loading real user profile from AuthenticationProvider...');
      
      // Get the authentication provider to access the current user model
      final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
      
      // Use the existing user model if available
      if (authProvider.userModel != null) {
        userModel = authProvider.userModel;
        debugPrint('Using existing user model - Username: ${userModel?.name}, Avatar: ${userModel?.image}');
      } 
      // If not available, try to load it from Firestore
      else {
        try {
          debugPrint('Fetching user data from Firestore...');
          // Get user document from Firestore
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(firebaseUser.uid)
              .get();
          
          if (userDoc.exists) {
            // Create UserModel from Firestore data
            userModel = UserModel.fromMap(userDoc.data()!);
            debugPrint('Successfully loaded user data - Username: ${userModel.name}, Avatar: ${userModel.image}');
          } else {
            // Fallback to temporary user model if Firestore data not found
            userModel = UserModel(
              uid: firebaseUser.uid,
              name: firebaseUser.displayName ?? 'Player',
              email: firebaseUser.email ?? '',
              image: firebaseUser.photoURL ?? '',
              lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
              playerRating: 1200,
              createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
            );
            debugPrint('WARNING: Created temporary user model as fallback - UID: ${userModel.uid}');
          }
        } catch (e) {
          debugPrint('Error loading user data: $e');
          // Create a temporary model as fallback
          userModel = UserModel(
            uid: firebaseUser.uid,
            name: firebaseUser.displayName ?? 'Player',
            email: firebaseUser.email ?? '',
            image: firebaseUser.photoURL ?? '',
            lastUsernameChange: DateTime.now().millisecondsSinceEpoch,
            playerRating: 1200,
            createdAt: DateTime.now().millisecondsSinceEpoch.toString(),
          );
          debugPrint('Created temporary user model as fallback after error - UID: ${userModel.uid}');
        }
      }
    }

    // Double check that we have a valid user model for online games
    if (!gameProvider.vsComputer && userModel == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Failed to load user data. Please log in again.')),
      );
      return;
    }
    
    // Force token refresh for online games to ensure Firebase authorization is current
    if (!gameProvider.vsComputer) {
      try {
        debugPrint('Refreshing Firebase auth token before starting online game...');
        await firebaseUser!.getIdToken(true); // Force token refresh
        await Future.delayed(const Duration(milliseconds: 800)); // Small delay to allow token propagation
        debugPrint('Token refreshed successfully');
      } catch (tokenError) {
        debugPrint('Token refresh error: $tokenError');
        // Continue anyway
      }
    }

    // check if is custom time
    if (widget.isCustomTime) {
      // check all timer are greater than 0
      if (whiteTimeInMenutes <= 0 || blackTimeInMenutes <= 0) {
        // show snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Time cannot be 0')),
        );
        return;
      }

      // 1. start loading dialog
      gameProvider.setIsLoading(value: true);

      // 2. save time and player color for both players
      await gameProvider
          .setGameTime(
        newSavedWhitesTime: whiteTimeInMenutes.toString(),
        newSavedBlacksTime: blackTimeInMenutes.toString(),
      )
          .whenComplete(() {
        if (gameProvider.vsComputer) {
          gameProvider.setIsLoading(value: false);
          // 3. navigate to game screen
          Navigator.pushNamed(context, Constants.gameScreen);
        } else {
          // For online matches, we've already checked userModel isn't null above
          gameProvider.searchPlayer(
            userModel: userModel!,
            onSuccess: () {
              if (gameProvider.waitingText == Constants.searchingPlayerText) {
                gameProvider.checkIfOpponentJoined(
                  userModel: userModel!,
                  onSuccess: () {
                    gameProvider.setIsLoading(value: false);
                    Navigator.pushNamed(context, Constants.gameScreen);
                  },
                );
              } else {
                gameProvider.setIsLoading(value: false);
                // navigate to gameScreen
                Navigator.pushNamed(context, Constants.gameScreen);
              }
            },
            onFail: (error) {
              gameProvider.setIsLoading(value: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            },
          );
        }
      });
    } else {
      // not custom time
      // check if its incremental time
      // get the value after the + sign
      final String incrementalTime = widget.gameTime.split('+')[1];

      // get the value before the + sign
      final String gameTime = widget.gameTime.split('+')[0];

      // check if incremental is equal to 0
      if (incrementalTime != '0') {
        // save the incremental value
        gameProvider.setIncrementalValue(value: int.parse(incrementalTime));
      }

      gameProvider.setIsLoading(value: true);

      await gameProvider
          .setGameTime(
        newSavedWhitesTime: gameTime,
        newSavedBlacksTime: gameTime,
      )
          .whenComplete(() {
        if (gameProvider.vsComputer) {
          gameProvider.setIsLoading(value: false);
          // 3. navigate to game screen
          Navigator.pushNamed(context, Constants.gameScreen);
        } else {
          // For online matches, we've already checked userModel isn't null above
          gameProvider.searchPlayer(
            userModel: userModel!,
            onSuccess: () {
              if (gameProvider.waitingText == Constants.searchingPlayerText) {
                gameProvider.checkIfOpponentJoined(
                  userModel: userModel!,
                  onSuccess: () {
                    gameProvider.setIsLoading(value: false);
                    Navigator.pushNamed(context, Constants.gameScreen);
                  },
                );
              } else {
                gameProvider.setIsLoading(value: false);
                // navigate to gameScreen
                Navigator.pushNamed(context, Constants.gameScreen);
              }
            },
            onFail: (error) {
              gameProvider.setIsLoading(value: false);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(error)),
              );
            },
          );
        }
      });
    }
  }

  // Helper method to build difficulty selection buttons
  Widget _buildDifficultyButton({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.28,
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 10.0),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE6F0FF) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: isSelected ?
            Border.all(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1.5) :
            Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade600,
              size: 28,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey.shade800,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
