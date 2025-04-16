import 'package:flutter/material.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/helper/helper_methods.dart';
import 'package:uptm_chess/main_screens/game_start_up_screen.dart';
import 'package:uptm_chess/theme/app_theme.dart';

class GameTimeScreen extends StatefulWidget {
  const GameTimeScreen({super.key});

  @override
  State<GameTimeScreen> createState() => _GameTimeScreenState();
}

class _GameTimeScreenState extends State<GameTimeScreen> {
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
            Icon(Icons.timer_outlined, color: Colors.white, size: 22),
            SizedBox(width: 8),
            Text(
              'Game Time',
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
          onPressed: () {
            Navigator.pop(context);
          },
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: AppTheme.primaryWhite,
            size: 22,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 6.0, bottom: 16.0),
                child: Text(
                  'Select Time Control',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2F394B),
                  ),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.0,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                  ),
                  itemCount: gameTimes.length,
                  itemBuilder: (context, index) {
                    // get the first word of the game time
                    final String label = gameTimes[index].split(' ')[0];
                    // get the second word from game time
                    final String gameTime = gameTimes[index].split(' ')[1];
                    
                    // Determine colors based on game type
                    Color cardColor;
                    Color textColor;
                    IconData timeIcon;
                    
                    if (label == 'Bullet') {
                      cardColor = const Color(0xFF4A7BF7);
                      textColor = Colors.white;
                      timeIcon = Icons.flash_on;
                    } else if (label == 'Rapid') {
                      cardColor = const Color(0xFF2E86DE);
                      textColor = Colors.white;
                      timeIcon = Icons.timelapse;
                    } else if (label == 'Classical') {
                      cardColor = const Color(0xFF1B5299);
                      textColor = Colors.white;
                      timeIcon = Icons.hourglass_bottom;
                    } else {
                      // Custom time
                      cardColor = const Color(0xFF6C63FF);
                      textColor = Colors.white;
                      timeIcon = Icons.settings;
                    }
                    
                    return _buildTimeCard(
                      label: label,
                      gameTime: gameTime,
                      cardColor: cardColor,
                      textColor: textColor,
                      timeIcon: timeIcon,
                      onTap: () {
                        if (label == Constants.custom) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameStartUpScreen(
                                isCustomTime: true,
                                gameTime: gameTime,
                              ),
                            ),
                          );
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => GameStartUpScreen(
                                isCustomTime: false,
                                gameTime: gameTime,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Modern styled time selection card
  Widget _buildTimeCard({
    required String label,
    required String gameTime,
    required Color cardColor,
    required Color textColor,
    required IconData timeIcon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: cardColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              // Background pattern for added style
              Positioned(
                right: -15,
                bottom: -15,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Main content
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      timeIcon,
                      color: textColor,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        gameTime,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
