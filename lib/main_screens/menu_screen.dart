import 'package:flutter/material.dart';
import 'package:uptm_chess/theme/app_theme.dart';

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  // Track the currently expanded section
  String? expandedSection;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppTheme.primaryBlue,
              Color(0xFF1976D2),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with back button
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 0),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Chess Tutorial',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Main Content
              Expanded(
                child: Container(
                  margin: const EdgeInsets.only(top: 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(32),
                      topRight: Radius.circular(32),
                    ),
                  ),
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // App logo
                      Center(
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: AppTheme.lightBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primaryBlue.withOpacity(0.3),
                              width: 2,
                            ),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.sports_esports,
                              size: 50,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      const Center(
                        child: Text(
                          'Learn Chess',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlack,
                          ),
                        ),
                      ),
                      const Center(
                        child: Text(
                          'Master the game of kings',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Chess Basics Section
                      _buildTutorialSection(
                        title: 'Chess Basics',
                        iconData: Icons.grid_on_rounded,
                        isExpanded: expandedSection == 'basics',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'basics' ? null : 'basics';
                          });
                        },
                        content: _buildChessBasics(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Piece Movements Section
                      _buildTutorialSection(
                        title: 'Piece Movements',
                        iconData: Icons.swap_calls_rounded,
                        isExpanded: expandedSection == 'movements',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'movements' ? null : 'movements';
                          });
                        },
                        content: _buildPieceMovements(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Special Moves Section
                      _buildTutorialSection(
                        title: 'Special Moves',
                        iconData: Icons.stars_rounded,
                        isExpanded: expandedSection == 'special',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'special' ? null : 'special';
                          });
                        },
                        content: _buildSpecialMoves(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Basic Strategies Section
                      _buildTutorialSection(
                        title: 'Basic Strategies',
                        iconData: Icons.psychology_rounded,
                        isExpanded: expandedSection == 'strategies',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'strategies' ? null : 'strategies';
                          });
                        },
                        content: _buildBasicStrategies(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Game Phases Section
                      _buildTutorialSection(
                        title: 'Game Phases',
                        iconData: Icons.timeline_rounded,
                        isExpanded: expandedSection == 'phases',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'phases' ? null : 'phases';
                          });
                        },
                        content: _buildGamePhases(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Time Controls Section
                      _buildTutorialSection(
                        title: 'Time Controls',
                        iconData: Icons.timer_outlined,
                        isExpanded: expandedSection == 'time',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'time' ? null : 'time';
                          });
                        },
                        content: _buildTimeControls(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Single Player Guide Section
                      _buildTutorialSection(
                        title: 'Single Player Guide',
                        iconData: Icons.person,
                        isExpanded: expandedSection == 'singleplayer',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'singleplayer' ? null : 'singleplayer';
                          });
                        },
                        content: _buildSinglePlayerGuide(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Multiplayer Guide Section
                      _buildTutorialSection(
                        title: 'Multiplayer Guide',
                        iconData: Icons.people,
                        isExpanded: expandedSection == 'multiplayer',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'multiplayer' ? null : 'multiplayer';
                          });
                        },
                        content: _buildMultiplayerGuide(),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // App Instructions Section
                      _buildTutorialSection(
                        title: 'App Instructions',
                        iconData: Icons.phone_android_rounded,
                        isExpanded: expandedSection == 'app',
                        onTap: () {
                          setState(() {
                            expandedSection = expandedSection == 'app' ? null : 'app';
                          });
                        },
                        content: _buildAppInstructions(),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Credits
                      const Center(
                        child: Text(
                          '© 2025 UPTM Chess. All rights reserved.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Expandable section container
  Widget _buildTutorialSection({
    required String title,
    required IconData iconData,
    required bool isExpanded,
    required VoidCallback onTap,
    required Widget content,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: isExpanded ? AppTheme.primaryBlue.withOpacity(0.3) : Colors.grey[200]!),
      ),
      child: Column(
        children: [
          // Section header - always visible
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.lightBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        iconData,
                        color: AppTheme.primaryBlue,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlack,
                        ),
                      ),
                    ),
                    Icon(
                      isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                      color: Colors.grey[600],
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Expandable content
          AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: content,
            ),
            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ],
      ),
    );
  }

  // Chess Basics Content
  Widget _buildChessBasics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'The Board',
          content: 'The chessboard consists of 64 squares arranged in an 8×8 grid. The squares alternate between light and dark colors, traditionally white and black.',
          icon: Icons.grid_on,
        ),
        _buildContentItem(
          title: 'The Pieces',
          content: 'Each player starts with 16 pieces: 1 king, 1 queen, 2 rooks, 2 knights, 2 bishops, and 8 pawns. White pieces are placed on ranks 1 and 2, while black pieces are placed on ranks 7 and 8.',
          icon: Icons.extension,
        ),
        _buildContentItem(
          title: 'The Objective',
          content: 'The goal of chess is to checkmate your opponent\'s king. Checkmate occurs when the king is under immediate attack (in "check") and has no legal move to escape the threat.',
          icon: Icons.emoji_events,
        ),
        _buildContentItem(
          title: 'Game Setup',
          content: 'The board is set up with the white square in the right corner closest to each player. The queen is placed on a square matching her color (white queen on white, black queen on black).',
          icon: Icons.settings,
        ),
      ],
    );
  }

  // Piece Movements Content
  Widget _buildPieceMovements() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'King',
          content: 'The king can move one square in any direction (horizontally, vertically, or diagonally). The king cannot move to a square that is under attack by an opponent\'s piece.',
          icon: Icons.brightness_auto,
        ),
        _buildContentItem(
          title: 'Queen',
          content: 'The queen is the most powerful piece and can move any number of squares in any direction (horizontally, vertically, or diagonally), as long as no piece blocks its path.',
          icon: Icons.star,
        ),
        _buildContentItem(
          title: 'Rook',
          content: 'The rook can move any number of squares horizontally or vertically, as long as no piece blocks its path. Rooks are powerful pieces for controlling files and ranks.',
          icon: Icons.domain,
        ),
        _buildContentItem(
          title: 'Bishop',
          content: 'The bishop can move any number of squares diagonally, as long as no piece blocks its path. Each player has two bishops, one on white squares and one on black squares.',
          icon: Icons.change_history,
        ),
        _buildContentItem(
          title: 'Knight',
          content: 'The knight moves in an L-shape: two squares horizontally or vertically, then one square perpendicular to that direction. Knights can jump over other pieces, making them unique.',
          icon: Icons.local_taxi,
        ),
        _buildContentItem(
          title: 'Pawn',
          content: 'Pawns move forward one square, but capture diagonally. On their first move, pawns can advance two squares. Pawns can be promoted to any piece (except king) upon reaching the opposite end of the board.',
          icon: Icons.person,
        ),
      ],
    );
  }

  // Special Moves Content
  Widget _buildSpecialMoves() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Castling',
          content: 'Castling is a special move involving the king and a rook. The king moves two squares toward the rook, and the rook moves to the square the king crossed. Conditions: neither piece has moved, no pieces between them, king not in check, and king doesn\'t pass through or land on a threatened square.',
          icon: Icons.swap_horiz,
        ),
        _buildContentItem(
          title: 'En Passant',
          content: 'When a pawn advances two squares on its first move and lands beside an opponent\'s pawn, the opponent\'s pawn can capture it as if it had moved only one square. This capture must be made immediately after the two-square advance.',
          icon: Icons.compare_arrows,
        ),
        _buildContentItem(
          title: 'Pawn Promotion',
          content: 'When a pawn reaches the opposite end of the board (8th rank for White, 1st rank for Black), it can be promoted to a queen, rook, bishop, or knight of the same color. Most players choose to promote to a queen as it\'s the most powerful piece.',
          icon: Icons.upgrade,
        ),
      ],
    );
  }

  // Basic Strategies Content
  Widget _buildBasicStrategies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Control the Center',
          content: 'The four central squares (d4, d5, e4, e5) are the most important areas of the board. Controlling these squares gives your pieces more mobility and options.',
          icon: Icons.center_focus_strong,
        ),
        _buildContentItem(
          title: 'Develop Pieces Early',
          content: 'Move your knights and bishops out early in the game. Aim to castle quickly to protect your king and connect your rooks.',
          icon: Icons.emoji_objects,
        ),
        _buildContentItem(
          title: 'King Safety',
          content: 'Castle early to move your king to safety. Avoid moving the pawns in front of your castled king unless necessary, as they provide a shield.',
          icon: Icons.security,
        ),
        _buildContentItem(
          title: 'Think Ahead',
          content: 'Try to anticipate your opponent\'s moves and think several moves ahead. Consider what your opponent might do in response to your moves.',
          icon: Icons.psychology,
        ),
        _buildContentItem(
          title: 'Piece Coordination',
          content: 'Your pieces are stronger when they work together. Position your pieces where they support each other and control key squares.',
          icon: Icons.handshake,
        ),
      ],
    );
  }

  // Game Phases Content
  Widget _buildGamePhases() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Opening (Beginning)',
          content: 'The first 10-15 moves where both players develop pieces, control the center, and castle. Popular openings include the Ruy Lopez, Sicilian Defense, and Queen\'s Gambit.',
          icon: Icons.play_arrow,
        ),
        _buildContentItem(
          title: 'Middlegame',
          content: 'The phase after pieces are developed. Focus on tactics, positional play, and attacking opportunities. This is often where the strategic battle intensifies.',
          icon: Icons.sync,
        ),
        _buildContentItem(
          title: 'Endgame',
          content: 'The final phase when few pieces remain on the board. Kings become active pieces, and pawn promotion becomes crucial. Understanding basic endgames (like king and pawn vs. king) is essential.',
          icon: Icons.flag,
        ),
      ],
    );
  }

  // Time Controls Content
  Widget _buildTimeControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Bullet Chess',
          content: 'Very fast games where each player has less than 3 minutes (typically 1+0 or 1+1) for all their moves. Requires quick thinking and reflexes.',
          icon: Icons.flash_on,
        ),
        _buildContentItem(
          title: 'Blitz Chess',
          content: 'Fast games where each player has between 3-10 minutes (like 3+2 or 5+0) for all their moves. Popular for online play.',
          icon: Icons.speed,
        ),
        _buildContentItem(
          title: 'Rapid Chess',
          content: 'Each player has 10-60 minutes (like 15+10 or 30+0) for all their moves. A good balance between quick games and thoughtful play.',
          icon: Icons.timelapse,
        ),
        _buildContentItem(
          title: 'Classical Chess',
          content: 'Traditional time control where each player has more than 60 minutes (like 90+30 or 120+15) for their moves. Used in serious tournaments.',
          icon: Icons.hourglass_bottom,
        ),
        _buildContentItem(
          title: 'Increment',
          content: 'Additional time (in seconds) added to a player\'s clock after they make a move. For example, in a 5+3 game, each player starts with 5 minutes and gains 3 seconds after each move.',
          icon: Icons.add_alarm,
        ),
      ],
    );
  }

  // App Instructions Content
  Widget _buildAppInstructions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'App Navigation',
          content: 'Use the bottom navigation bar to switch between Home, Friends, Tournament, Learn, and Profile sections. Each section provides different functionality for your chess experience.',
          icon: Icons.navigation,
        ),
        _buildContentItem(
          title: 'Piece Movement',
          content: 'Tap on a piece to see available moves (highlighted squares), then tap on a destination square to move. The app will only allow legal moves.',
          icon: Icons.touch_app,
        ),
        _buildContentItem(
          title: 'Game Controls',
          content: 'Use the buttons below the board to restart the game, flip the board perspective, or undo a move (in practice games only).',
          icon: Icons.videogame_asset,
        ),
        _buildContentItem(
          title: 'Profile and Stats',
          content: 'View your profile to see your rating, game history, and statistics. You can update your profile picture and username (once every 7 days).',
          icon: Icons.account_circle,
        ),
      ],
    );
  }

  // Helper for content divider
  Widget _buildDivider() {
    return const Divider(
      color: Colors.grey,
      height: 24,
      thickness: 0.5,
    );
  }

  // Helper for content items
  Widget _buildContentItem({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppTheme.primaryBlue,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlack,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Single Player Guide Content
  Widget _buildSinglePlayerGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Starting a Game',
          content: 'From the Home screen, tap "Play Now" and select "Play vs Computer" to start a single player game against the AI.',
          icon: Icons.play_arrow,
        ),
        _buildContentItem(
          title: 'Choosing Difficulty',
          content: 'Select from three AI difficulty levels: Easy (skill level 5, depth 5, 500ms), Medium (skill level 10, depth 10, 1000ms), or Hard (skill level 20, depth 15, 2000ms).',
          icon: Icons.speed,
        ),
        _buildContentItem(
          title: 'Selecting Your Color',
          content: 'Choose whether you want to play as White (moves first) or Black (moves second). Each offers a different strategic experience.',
          icon: Icons.palette,
        ),
        _buildContentItem(
          title: 'Setting Time Control',
          content: 'Select your preferred time control. This determines how much time each player has to make all their moves during the game.',
          icon: Icons.timer,
        ),
        _buildContentItem(
          title: 'Making Moves',
          content: 'Tap a piece to select it (legal moves will be highlighted with green dots), then tap the destination square to move. The AI will respond automatically.',
          icon: Icons.touch_app,
        ),
        _buildContentItem(
          title: 'Game Controls',
          content: 'During gameplay, you can use the buttons at the bottom of the screen to reset the game, flip the board orientation, or undo a move (in practice mode only).',
          icon: Icons.settings,
        ),
        _buildContentItem(
          title: 'Resigning',
          content: 'If you wish to forfeit the game, tap the flag icon in the top bar and confirm your resignation. This will count as a loss in your game history.',
          icon: Icons.flag,
        ),
        _buildContentItem(
          title: 'Game End',
          content: 'The game ends when there is checkmate, stalemate, insufficient material, or when a player resigns. A result screen will display showing the outcome and stats.',
          icon: Icons.emoji_events,
        ),
      ],
    );
  }

  // Multiplayer Guide Content
  Widget _buildMultiplayerGuide() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDivider(),
        _buildContentItem(
          title: 'Starting Online Play',
          content: 'From the Home screen, tap "Play Now" and select "Play Online" to begin the online matchmaking process.',
          icon: Icons.wifi,
        ),
        _buildContentItem(
          title: 'Creating a Game',
          content: 'Tap "Create Game" to set up a new online match. You can select your preferred time control and playing color (White or Black).',
          icon: Icons.add_circle,
        ),
        _buildContentItem(
          title: 'Joining a Game',
          content: 'Tap "Join Game" to see a list of available games created by other players. Select any game to view details and join it.',
          icon: Icons.login,
        ),
        _buildContentItem(
          title: 'Making Moves',
          content: 'Tap a piece and then the destination square to move. Your move will be automatically transmitted to your opponent in real-time.',
          icon: Icons.swap_horiz,
        ),
        _buildContentItem(
          title: 'Time Management',
          content: 'Keep an eye on your clock - when it\'s your turn, your time is counting down. After making a move, your opponent\'s clock will start running.',
          icon: Icons.alarm,
        ),
        _buildContentItem(
          title: 'Game Disconnection',
          content: 'If you lose connection, the app will try to reconnect you automatically. Your game state is preserved on the server.',
          icon: Icons.sync_problem,
        ),
        _buildContentItem(
          title: 'Rating System',
          content: 'After each online game, your rating will be adjusted: +10 points for a win, -8 points for a loss, and +1 point for a draw.',
          icon: Icons.trending_up,
        ),
        _buildContentItem(
          title: 'Game History',
          content: 'All your online games are recorded in your game history. You can view and filter them from the Home screen.',
          icon: Icons.history,
        ),
      ],
    );
  }
}
