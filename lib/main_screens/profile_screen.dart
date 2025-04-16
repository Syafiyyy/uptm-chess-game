import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:uptm_chess/constants.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/main_screens/edit_profile_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Widget _buildAvatar(String? avatarId) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey.shade200,
      ),
      clipBehavior: Clip.antiAlias,
      child: avatarId != null
          ? SvgPicture.asset(
              'assets/avatars/$avatarId.svg',
              fit: BoxFit.cover,
            )
          : const Icon(Icons.person, size: 40, color: Colors.black87),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.primaryBlue.withOpacity(0.1),
              AppTheme.primaryWhite,
              AppTheme.primaryWhite,
            ],
            stops: const [0.0, 0.3, 1.0],
          ),
        ),
        child: Consumer<AuthenticationProvider>(
          builder: (context, authProvider, _) {
            // Handle loading state
            if (authProvider.isLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                ),
              );
            }
            
            // If no user model is available yet, try to load it
            if (authProvider.userModel == null) {
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                try {
                  // Set loading state first
                  authProvider.setIsLoading(value: true);
                  
                  // Try to get user data from Firestore first
                  bool success = await authProvider.getUserDataFromFireStore();
                  
                  // If Firestore fetch fails, try SharedPreferences as fallback
                  if (!success) {
                    debugPrint('Firestore fetch failed, trying SharedPreferences');
                    success = await authProvider.getUserDataToSharedPref();
                    
                    // If both failed and we have no user, redirect to login
                    if (!success && authProvider.userModel == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Session expired. Please login again.'))
                      );
                      // Wait a moment before navigating
                      await Future.delayed(const Duration(seconds: 1));
                      if (context.mounted) {
                        authProvider.signOutUser();
                        Navigator.of(context).pushNamedAndRemoveUntil(
                          Constants.loginScreen,
                          (route) => false,
                        );
                      }
                    }
                  }
                } finally {
                  if (authProvider.isLoading) {
                    authProvider.setIsLoading(value: false);
                  }
                }
              });
              
              return const Center(
                child: CircularProgressIndicator(
                  color: AppTheme.primaryBlue,
                ),
              );
            }
            
            final username = authProvider.userModel?.name ?? 'User';
            final avatarId = authProvider.userModel?.image;

            return SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildAvatar(avatarId),
                        const SizedBox(width: 24),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                username,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      color: AppTheme.primaryBlack,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authProvider.userModel?.email ?? '',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge
                                    ?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                              ),
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // Convert userModel to Map for edit profile screen
                                  final userMap = {
                                    'uid': authProvider.userModel?.uid ?? '',
                                    'name': authProvider.userModel?.name ?? '',
                                    'email': authProvider.userModel?.email ?? '',
                                    'image': authProvider.userModel?.image ?? 'avatar1',
                                    'playerRating': authProvider.userModel?.playerRating ?? 1200,
                                  };
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => EditProfileScreen(
                                        userData: userMap as Map<String, dynamic>,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, size: 16),
                                label: const Text('Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.primaryBlue,
                                  foregroundColor: Colors.white,
                                  textStyle: const TextStyle(fontSize: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 8),
                                  minimumSize: const Size(100, 32),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    // Create a map with necessary stats for game profile
                    _buildGameProfile(
                      context,
                      {
                        'playerRating': authProvider.userModel?.playerRating ?? 1200,
                        'gamesPlayed': 0, // Default as these aren't in UserModel yet
                        'wins': 0,
                        'losses': 0,
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildPlayingPreferences(context),
                    const SizedBox(height: 24),
                    _buildAccountSettings(context),
                    const SizedBox(height: 24),

                    // Logout button
                    _buildLogoutButton(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildGameProfile(
      BuildContext context, Map<String, dynamic> userData) {
    // Get the user's ranking and ELO from userData or provide defaults
    final int rating = userData['playerRating'] as int? ?? 1200;
    final int gamesPlayed = userData['gamesPlayed'] as int? ?? 0;
    final int wins = userData['wins'] as int? ?? 0;
    final int losses = userData['losses'] as int? ?? 0;
    final int draws = userData['draws'] as int? ?? 0;
    final String playerLevel = _getPlayerLevel(rating);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chess Profile',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 16),

          // Rating display
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getRatingColor(rating).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emoji_events,
                  color: _getRatingColor(rating),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rating: $rating',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      playerLevel,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getRatingColor(rating),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Game record summary
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRecordItem('Games', gamesPlayed.toString(), Icons.casino),
              _buildRecordItem(
                  'Wins', wins.toString(), Icons.check_circle, Colors.green),
              _buildRecordItem(
                  'Losses', losses.toString(), Icons.cancel, Colors.red),
              _buildRecordItem('Draws', draws.toString(),
                  Icons.remove_circle_outline, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  // Helper method to determine player level based on rating
  String _getPlayerLevel(int rating) {
    if (rating < 1200) return 'Beginner';
    if (rating < 1400) return 'Novice';
    if (rating < 1600) return 'Intermediate';
    if (rating < 1800) return 'Advanced';
    if (rating < 2000) return 'Expert';
    if (rating < 2200) return 'Master';
    if (rating < 2400) return 'Grand Master';
    return 'Chess Legend';
  }

  // Helper method to get color based on rating
  Color _getRatingColor(int rating) {
    if (rating < 1200) return Colors.grey;
    if (rating < 1400) return Colors.green;
    if (rating < 1600) return Colors.blue;
    if (rating < 1800) return const Color(0xFF8E24AA); // Purple
    if (rating < 2000) return const Color(0xFFFB8C00); // Orange
    if (rating < 2200) return Colors.red;
    return const Color(0xFFFFD700); // Gold
  }

  Widget _buildRecordItem(String label, String value, IconData icon,
      [Color? color]) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppTheme.primaryBlue, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? AppTheme.primaryBlack,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildPlayingPreferences(BuildContext context) {
    // Get user preferences from AuthenticationProvider and Firebase
    final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
    final uid = authProvider.uid;
    
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots(),
      builder: (context, snapshot) {
        // Handle loading and error states
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        // Get user data from snapshot
        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        
        // Extract preferences with defaults
        final timeControl = userData['preferredTimeControl'] as String? ?? '10 Minutes';
        final preferredColor = userData['preferredColor'] as String? ?? 'White';
        final aiDifficulty = userData['aiDifficulty'] as String? ?? 'Intermediate';
        
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 5,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Game Preferences',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryBlack,
                ),
              ),
              const SizedBox(height: 16),
              _buildPreferenceItem(
                'Preferred Time Control',
                timeControl,
                Icons.timer,
                AppTheme.primaryBlue,
              ),
              const SizedBox(height: 12),
              _buildPreferenceItem(
                'Preferred Color',
                preferredColor,
                Icons.circle,
                preferredColor.toLowerCase() == 'white' ? Colors.grey[800]! : Colors.black87,
              ),
              const SizedBox(height: 12),
              _buildPreferenceItem(
                'AI Difficulty',
                aiDifficulty,
                Icons.smart_toy,
                _getDifficultyColor(aiDifficulty),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Helper to get color based on AI difficulty
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'beginner':
        return Colors.green;
      case 'intermediate':
        return AppTheme.primaryBlue;
      case 'advanced':
        return Colors.orange;
      case 'expert':
        return AppTheme.primaryRed;
      default:
        return AppTheme.primaryBlue;
    }
  }

  Widget _buildPreferenceItem(
      String title, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const Icon(
          Icons.edit,
          color: Colors.grey,
          size: 16,
        ),
      ],
    );
  }

  Widget _buildAccountSettings(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 5,
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Settings',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryBlack,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            'Notification Settings',
            'Configure how you receive notifications',
            Icons.notifications,
            AppTheme.primaryBlue,
            () {}, // Navigation to notification settings
          ),
          const Divider(),
          _buildSettingItem(
            'Privacy Settings',
            'Control who can see your profile and activity',
            Icons.lock_outline,
            Colors.green,
            () {}, // Navigation to privacy settings
          ),
          const Divider(),
          _buildSettingItem(
            'Change Password',
            'Update your account password',
            Icons.password,
            AppTheme.primaryRed,
            () {}, // Navigation to password change screen
          ),
          const Divider(),
          _buildSettingItem(
            'Delete Account',
            'Permanently delete your account and data',
            Icons.delete_outline,
            Colors.red,
            () {}, // Delete account confirmation
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, String subtitle, IconData icon,
      Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          final authProvider = Provider.of<AuthenticationProvider>(context, listen: false);
          await authProvider.signOutUser();
          Navigator.of(context).pushNamedAndRemoveUntil(
            Constants.loginScreen,
            (route) => false,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.primaryRed,
          foregroundColor: AppTheme.primaryWhite,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: const Text(
          'Logout',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
