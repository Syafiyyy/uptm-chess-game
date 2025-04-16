import 'package:flutter/material.dart';
import 'package:uptm_chess/main_screens/menu_screen.dart';
import 'package:uptm_chess/main_screens/game_time_screen.dart';
import 'package:uptm_chess/main_screens/tournament_screen.dart';
import 'package:uptm_chess/main_screens/friends_screen.dart';
import 'package:uptm_chess/main_screens/profile_screen.dart';
import 'package:uptm_chess/providers/game_provider.dart';
import 'package:provider/provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/models/game_history.dart';
import 'package:uptm_chess/providers/game_history_provider.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;

  final List<Widget> _pages = [
    const HomeContent(),
    const FriendsScreen(),
    const TournamentScreen(),
    const MenuScreen(),
    const ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // Check if user is logged in
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAuthentication();
    });
  }

  // Check if user is authenticated and redirect to login if not
  void _checkAuthentication() {
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);

    // Add debug print to track authentication state
    debugPrint(
        'Checking authentication state: ${authProvider.userModel != null ? 'User logged in' : 'User not logged in'}');

    if (authProvider.userModel == null) {
      // Try to load user data from shared preferences first
      authProvider.getUserDataToSharedPref().then((_) {
        // Check again after loading from shared preferences
        if (authProvider.userModel == null) {
          debugPrint(
              'User not logged in after checking shared preferences. Redirecting to login screen...');
          Navigator.of(context).pushReplacementNamed(Constants.loginScreen);
        } else {
          debugPrint('User loaded from shared preferences successfully');
        }
      }).catchError((error) {
        debugPrint('Error loading user data from shared preferences: $error');
        Navigator.of(context).pushReplacementNamed(Constants.loginScreen);
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _pages[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
              spreadRadius: 0,
            ),
          ],
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Home'),
                _buildNavItem(1, Icons.people_rounded, 'Friends'),
                _buildNavItem(2, Icons.emoji_events_rounded, 'Tournament'),
                _buildNavItem(3, Icons.menu_book_rounded, 'Learn'),
                _buildNavItem(4, Icons.person_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryBlue.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryBlue : Colors.grey,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HomeContent extends StatefulWidget {
  const HomeContent({super.key});

  @override
  State<HomeContent> createState() => _HomeContentState();
}

class _HomeContentState extends State<HomeContent> {
  late GameHistoryProvider _gameHistoryProvider;

  @override
  void initState() {
    super.initState();
    _gameHistoryProvider =
        Provider.of<GameHistoryProvider>(context, listen: false);

    // Load game history after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadGameHistory();
    });
  }

  void _loadGameHistory() {
    final authProvider =
        Provider.of<AuthenticationProvider>(context, listen: false);
    if (authProvider.userModel != null) {
      // Use listenToGameHistory for real-time updates with increased limit
      debugPrint(
          'Loading game history for user: ${authProvider.userModel!.uid}');
      _gameHistoryProvider.listenToGameHistory(authProvider.userModel!.uid,
          limit: 10);
    } else {
      debugPrint('Cannot load game history: User is not logged in');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthenticationProvider>();
    final gameProvider = context.watch<GameProvider>();
    final gameHistoryProvider = context.watch<GameHistoryProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background with gradient
          Container(
            height: MediaQuery.of(context).size.height * 0.35,
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
          ),

          // Chess pattern background (subtle)
          Positioned(
            top: 0,
            right: 0,
            child: Opacity(
              opacity: 0.1,
              child: SizedBox(
                width: MediaQuery.of(context).size.width * 0.6,
                height: MediaQuery.of(context).size.height * 0.3,
                child: CustomPaint(
                  painter: ChessPatternPainter(),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // App Bar with welcome message
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Welcome message and trophy icon
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.emoji_events_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Welcome, ${authProvider.userModel?.name ?? 'Player'}',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Ready for your next chess match?',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.white.withOpacity(0.9),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),

                      // User profile button with avatar
                      GestureDetector(
                        onTap: () {
                          // Navigate to profile page when clicked
                          Navigator.of(context).pushReplacement(
                            MaterialPageRoute(builder: (context) => const ProfileScreen()),
                          );
                        },
                        child: Container(
                          height: 48,
                          width: 48,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                          // SVG avatar or fallback icon
                          child: authProvider.userModel?.image != null
                            ? Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: SvgPicture.asset(
                                  'assets/avatars/${authProvider.userModel!.image}.svg',
                                  fit: BoxFit.contain,
                                ),
                              )
                            : const Icon(
                                Icons.person, 
                                color: Colors.white, 
                                size: 24,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main content area
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(top: 24),
                    children: [
                      // Main play now card
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                              spreadRadius: 0,
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(24),
                            onTap: () {
                              gameProvider.setVsComputer(value: false);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const GameTimeScreen(),
                                ),
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      color:
                                          AppTheme.lightBlue.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: const Icon(
                                      Icons.play_arrow_rounded,
                                      color: AppTheme.primaryBlue,
                                      size: 36,
                                    ),
                                  ),
                                  const SizedBox(width: 20),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      Text(
                                        'Play Now',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryBlack,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Quick match online',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Spacer(),
                                  const Icon(
                                    Icons.arrow_forward_ios,
                                    color: Colors.grey,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Play options section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildPlayOption(
                                context: context,
                                title: 'Play',
                                subtitle: 'Computer',
                                icon: Icons.computer_rounded,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF2196F3),
                                    Color(0xFF0D47A1)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  gameProvider.setVsComputer(value: true);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const GameTimeScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _buildPlayOption(
                                context: context,
                                title: 'Play',
                                subtitle: 'Online',
                                icon: Icons.public_rounded,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFF4CAF50),
                                    Color(0xFF2E7D32)
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                onTap: () {
                                  gameProvider.setVsComputer(value: false);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const GameTimeScreen(),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Recent Games Section with improved design
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: AppTheme.lightBlue.withOpacity(0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.history_rounded,
                                    color: AppTheme.darkBlue,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Text(
                                  'Recent Games',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            TextButton(
                              onPressed: () {
                                _showFilterOptions(context);
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.primaryBlue,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Row(
                                children: const [
                                  Icon(Icons.filter_list, size: 16),
                                  SizedBox(width: 4),
                                  Text(
                                    'Filter',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      
                      // Filter chips for quick filtering
                      Consumer<GameHistoryProvider>(
                        builder: (context, gameHistoryProvider, child) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                _buildFilterChip(
                                  label: 'All',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.all,
                                  onTap: () => _applyFilter(context, HistoryFilter.all),
                                  color: Colors.grey.shade700,
                                ),
                                _buildFilterChip(
                                  label: 'Wins',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.wins,
                                  onTap: () => _applyFilter(context, HistoryFilter.wins),
                                  color: const Color(0xFF4CAF50),
                                ),
                                _buildFilterChip(
                                  label: 'Losses',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.losses,
                                  onTap: () => _applyFilter(context, HistoryFilter.losses),
                                  color: AppTheme.primaryRed,
                                ),
                                _buildFilterChip(
                                  label: 'Draws',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.draws,
                                  onTap: () => _applyFilter(context, HistoryFilter.draws),
                                  color: AppTheme.primaryBlue,
                                ),
                                _buildFilterChip(
                                  label: 'AI Games',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.aiGames,
                                  onTap: () => _applyFilter(context, HistoryFilter.aiGames),
                                  color: const Color(0xFF9C27B0),
                                ),
                                _buildFilterChip(
                                  label: 'Online Games',
                                  isSelected: gameHistoryProvider.currentFilter == HistoryFilter.onlineGames,
                                  onTap: () => _applyFilter(context, HistoryFilter.onlineGames),
                                  color: const Color(0xFF2196F3),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 16),

                      // Recent games list
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: authProvider.userModel != null
                            ? _buildRecentGames(gameHistoryProvider)
                            : _buildSignInPrompt(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Gradient gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: gradient.colors.first.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 5),
              spreadRadius: 1,
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              bottom: -20,
              child: Opacity(
                opacity: 0.1,
                child: Icon(
                  icon,
                  size: 100,
                  color: Colors.white,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.9),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentGames(GameHistoryProvider gameHistoryProvider) {
    if (gameHistoryProvider.isLoading) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
        ),
      );
    }

    if (gameHistoryProvider.gameHistory.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              spreadRadius: 1,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.lightBlue.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.history_rounded,
                color: AppTheme.primaryBlue,
                size: 36,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No games played yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryBlack,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your game history will appear here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: gameHistoryProvider.gameHistory.length,
      itemBuilder: (context, index) {
        return _buildGameHistoryItem(gameHistoryProvider.gameHistory[index]);
      },
    );
  }

  Widget _buildGameHistoryItem(GameHistory game) {
    // Determine game result and appropriate styling
    late final String resultText;
    late final Color resultColor;

    // Now we can properly handle all three possible game results
    switch (game.result) {
      case GameResult.win:
        resultText = 'Win';
        resultColor = const Color(0xFF4CAF50); // Green
        break;
      case GameResult.loss:
        resultText = 'Loss';
        resultColor = AppTheme.primaryRed;
        break;
      case GameResult.draw:
        resultText = 'Draw';
        resultColor = AppTheme.primaryBlue;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            // Result indicator
            Container(
              width: 4,
              height: 60,
              decoration: BoxDecoration(
                color: resultColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 16),
            // Game details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        game.opponent,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: resultColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          resultText,
                          style: TextStyle(
                            color: resultColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatTimestamp(game.timestamp),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Text(
                        'Duration: ${_formatDuration(game.durationSeconds)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Moves: ${game.moveCount}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      // Add rating change indicator if it's an online game with rating change
                      if (game.wasOnline && game.ratingChange != null)
                        Row(
                          children: [
                            Icon(
                              game.ratingChange! > 0 ? Icons.arrow_upward : Icons.arrow_downward,
                              color: game.ratingChange! > 0 ? Colors.green : Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${game.ratingChange! > 0 ? '+' : ''}${game.ratingChange}',
                              style: TextStyle(
                                color: game.ratingChange! > 0 ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int seconds) {
    final duration = Duration(seconds: seconds);
    final minutes = duration.inMinutes;
    final remainingSeconds = duration.inSeconds % 60;

    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      return '${difference.inDays} ${difference.inDays == 1 ? 'day' : 'days'} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ${difference.inHours == 1 ? 'hour' : 'hours'} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} ${difference.inMinutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return 'Just now';
    }
  }

  // Display filter options dialog
  void _showFilterOptions(BuildContext context) {
    final gameHistoryProvider = Provider.of<GameHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filter Game History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'By Result',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFilterOption(
                    label: 'All Games',
                    icon: Icons.grid_view_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.all);
                      Navigator.pop(context);
                    },
                    color: Colors.grey.shade700,
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.all,
                  ),
                  const SizedBox(width: 10),
                  _buildFilterOption(
                    label: 'Wins',
                    icon: Icons.emoji_events_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.wins);
                      Navigator.pop(context);
                    },
                    color: const Color(0xFF4CAF50),
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.wins,
                  ),
                  const SizedBox(width: 10),
                  _buildFilterOption(
                    label: 'Losses',
                    icon: Icons.close_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.losses);
                      Navigator.pop(context);
                    },
                    color: AppTheme.primaryRed,
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.losses,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFilterOption(
                    label: 'Draws',
                    icon: Icons.handshake_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.draws);
                      Navigator.pop(context);
                    },
                    color: AppTheme.primaryBlue,
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.draws,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'By Game Type',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildFilterOption(
                    label: 'AI Games',
                    icon: Icons.smart_toy_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.aiGames);
                      Navigator.pop(context);
                    },
                    color: const Color(0xFF9C27B0),
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.aiGames,
                  ),
                  const SizedBox(width: 10),
                  _buildFilterOption(
                    label: 'Online Games',
                    icon: Icons.public_rounded,
                    onTap: () {
                      gameHistoryProvider.setFilter(HistoryFilter.onlineGames);
                      Navigator.pop(context);
                    },
                    color: const Color(0xFF2196F3),
                    isSelected: gameHistoryProvider.currentFilter == HistoryFilter.onlineGames,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    if (authProvider.userModel != null) {
                      gameHistoryProvider.resetFilters(authProvider.userModel!.uid);
                    }
                    Navigator.pop(context);
                  },
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                  ),
                  child: const Text('Reset Filters'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Build a filter option button for the dialog
  Widget _buildFilterOption({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required Color color,
    required bool isSelected,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? color : Colors.grey.shade600),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build a filter chip for quick filtering
  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: 1.5,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? color : Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  // Apply filter when chip is tapped
  void _applyFilter(BuildContext context, HistoryFilter filter) {
    final gameHistoryProvider = Provider.of<GameHistoryProvider>(context, listen: false);
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    
    if (authProvider.userModel != null) {
      if (filter != gameHistoryProvider.currentFilter) {
        switch (filter) {
          case HistoryFilter.all:
            gameHistoryProvider.resetFilters(authProvider.userModel!.uid);
            break;
          case HistoryFilter.wins:
            gameHistoryProvider.fetchGamesByResult(authProvider.userModel!.uid, GameResult.win);
            break;
          case HistoryFilter.losses:
            gameHistoryProvider.fetchGamesByResult(authProvider.userModel!.uid, GameResult.loss);
            break;
          case HistoryFilter.draws:
            gameHistoryProvider.fetchGamesByResult(authProvider.userModel!.uid, GameResult.draw);
            break;
          case HistoryFilter.aiGames:
            gameHistoryProvider.fetchGamesByType(authProvider.userModel!.uid, false);
            break;
          case HistoryFilter.onlineGames:
            gameHistoryProvider.fetchGamesByType(authProvider.userModel!.uid, true);
            break;
        }
      }
    }
  }

  Widget _buildSignInPrompt(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.lightBlue.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history_rounded,
              color: AppTheme.primaryBlue,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No games played yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your game history will appear here',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const GameTimeScreen(),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Play your first game',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ChessPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    final squareSize = 20.0;

    for (double i = 0; i < size.width; i += squareSize) {
      for (double j = 0; j < size.height; j += squareSize) {
        if ((i / squareSize + j / squareSize) % 2 == 0) {
          canvas.drawRect(Rect.fromLTWH(i, j, squareSize, squareSize), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return false;
  }
}
