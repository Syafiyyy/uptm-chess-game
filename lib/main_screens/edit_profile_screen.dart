import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:uptm_chess/providers/authentication_provider.dart';
import 'package:uptm_chess/helper/username_helper.dart';

class EditProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const EditProfileScreen({super.key, required this.userData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  String _currentUsername = '';
  String _selectedAvatar = 'avatar1';
  bool _isLoading = false;
  bool _canChangeUsername = true;
  int _daysUntilNextChange = 0;

  // Game preference controllers
  String _selectedTimeControl = '10 Minutes';
  String _selectedColor = 'White';
  String _selectedDifficulty = 'Intermediate';

  // Available options
  final List<String> _timeControlOptions = [
    '5 Minutes',
    '10 Minutes',
    '15 Minutes',
    '30 Minutes',
    '1 Hour'
  ];

  final List<String> _colorOptions = ['White', 'Black', 'Random'];

  final List<String> _difficultyOptions = [
    'Beginner',
    'Intermediate',
    'Advanced',
    'Expert'
  ];

  final List<Map<String, dynamic>> _avatars = [
    {
      'id': 'avatar1',
      'name': 'Pawn',
      'path': 'assets/avatars/avatar1.svg',
      'color': AppTheme.primaryBlue,
    },
    {
      'id': 'avatar2',
      'name': 'Knight',
      'path': 'assets/avatars/avatar2.svg',
      'color': AppTheme.primaryRed,
    },
    {
      'id': 'avatar3',
      'name': 'Bishop',
      'path': 'assets/avatars/avatar3.svg',
      'color': const Color(0xFF43A047),
    },
    {
      'id': 'avatar4',
      'name': 'Rook',
      'path': 'assets/avatars/avatar4.svg',
      'color': const Color(0xFFFB8C00),
    },
    {
      'id': 'avatar5',
      'name': 'Queen',
      'path': 'assets/avatars/avatar5.svg',
      'color': const Color(0xFF8E24AA),
    },
    {
      'id': 'avatar6',
      'name': 'King',
      'path': 'assets/avatars/avatar6.svg',
      'color': const Color(0xFF00897B),
    },
  ];

  @override
  void initState() {
    super.initState();
    // Load user data when the screen initializes
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Use userData from widget if provided
    if (widget.userData.isNotEmpty) {
      setState(() {
        // Basic profile data
        _currentUsername = widget.userData['name'] ?? '';
        _usernameController.text = _currentUsername;
        _selectedAvatar = widget.userData['image'] ?? 'avatar1';

        // Game preferences
        _selectedTimeControl =
            widget.userData['preferredTimeControl'] ?? '10 Minutes';
        _selectedColor = widget.userData['preferredColor'] ?? 'White';
        _selectedDifficulty = widget.userData['aiDifficulty'] ?? 'Intermediate';
      });
    } else {
      // Fallback to fetch from Firestore if widget data is empty
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        final data = userData.data() ?? {};
        setState(() {
          // Basic profile data
          _currentUsername = data['name'] ?? '';
          _usernameController.text = _currentUsername;
          _selectedAvatar = data['image'] ?? 'avatar1';

          // Game preferences
          _selectedTimeControl = data['preferredTimeControl'] ?? '10 Minutes';
          _selectedColor = data['preferredColor'] ?? 'White';
          _selectedDifficulty = data['aiDifficulty'] ?? 'Intermediate';
        });
      }
    }

    // Check username change restrictions
    final canChange = await UsernameHelper.canChangeUsername(user.uid);
    final daysLeft = await UsernameHelper.getDaysUntilNextChange(user.uid);

    setState(() {
      _canChangeUsername = canChange;
      _daysUntilNextChange = daysLeft;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final newUsername = _usernameController.text.trim();
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      // Make sure we have a fresh ID token before proceeding
      // This refreshes the auth state and helps with permission issues
      await user.getIdToken(true);

      // IMPORTANT: Check if ONLY the avatar is being changed
      // This is critical for matching the security rule: affectedKeys.hasOnly(['image'])
      bool isAvatarOnlyChange = false;

      // Get current user data to compare
      DocumentSnapshot userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userData.exists) {
        final data = userData.data() as Map<String, dynamic>;
        
        // Simple check: avatar is changing but username is not
        isAvatarOnlyChange = 
            newUsername == data['name'] && // Username unchanged
            _selectedAvatar != data['image']; // Avatar is changing
      }

      // Special path for avatar-only updates to match security rule
      if (isAvatarOnlyChange) {
        // Update ONLY the avatar field using set() with merge option
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({'image': _selectedAvatar}, SetOptions(merge: true));

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Avatar updated successfully'),
            backgroundColor: Colors.green,
          ),
        );

        // Refresh user data in AuthenticationProvider to update the avatar everywhere
        final authProvider =
            Provider.of<AuthenticationProvider>(context, listen: false);
        await authProvider.getUserDataFromFireStore();

        // Navigate back to previous screen
        Navigator.pop(context);
        return;
      }

      // For non-avatar-only changes, continue with the normal flow
      // Check if username is being changed
      if (newUsername != _currentUsername) {
        // Check if user can change username
        if (!_canChangeUsername) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'You can change your username again in $_daysUntilNextChange days'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }

        // Check if username is already taken
        final isUnique = await UsernameHelper.isUsernameUnique(newUsername);
        if (!isUnique) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Username is already taken'),
            ),
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      if (!mounted) return;

      // All checks passed, update the profile
      // Prepare data to update
      final updateData = <String, dynamic>{
        // Basic profile data
        'name': newUsername,
        'image': _selectedAvatar,

        // Game preferences
        'preferredTimeControl': _selectedTimeControl,
        'preferredColor': _selectedColor,
        'aiDifficulty': _selectedDifficulty,
      };

      // Add timestamp for username change if needed
      if (newUsername != _currentUsername) {
        updateData['lastUsernameChange'] =
            DateTime.now().millisecondsSinceEpoch;

        // Update username in dedicated collection to maintain uniqueness
        final batch = FirebaseFirestore.instance.batch();

        // Remove old username reservation
        if (_currentUsername.isNotEmpty) {
          final oldUsernameDoc = FirebaseFirestore.instance
              .collection('usernames')
              .doc(_currentUsername.toLowerCase());
          batch.delete(oldUsernameDoc);
        }

        // Add new username reservation
        final newUsernameDoc = FirebaseFirestore.instance
            .collection('usernames')
            .doc(newUsername.toLowerCase());
        batch.set(newUsernameDoc, {
          'uid': user.uid,
          'createdAt': DateTime.now().millisecondsSinceEpoch,
        });

        // Execute the batch update for username changes
        await batch.commit();
      }

      // Update user profile in Firestore using set() with merge option
      // This is more compatible with our security rules
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(updateData, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh user data in AuthenticationProvider to update the avatar everywhere
      final authProvider =
          Provider.of<AuthenticationProvider>(context, listen: false);
      await authProvider.getUserDataFromFireStore();

      // Navigate back to previous screen
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      // Provide more user-friendly error messages
      String errorMessage = 'Error updating profile';

      if (e.toString().contains('permission-denied')) {
        errorMessage =
            'Permission denied: Please sign out and sign in again to refresh your credentials';
      } else {
        errorMessage = 'Error updating profile: ${e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
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
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back),
                        color: AppTheme.primaryBlack,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Edit Profile',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(
                              color: AppTheme.primaryBlack,
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Username change restriction notification
                  if (!_canChangeUsername) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: AppTheme.primaryRed.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.timer,
                            color: AppTheme.primaryRed,
                            size: 24,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Username Change Restricted',
                                        style: TextStyle(
                                          color: AppTheme.primaryRed,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    Tooltip(
                                      message:
                                          'To prevent abuse, username changes are limited to once every 7 days',
                                      child: Icon(
                                        Icons.info_outline,
                                        color: AppTheme.primaryRed,
                                        size: 18,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'You can change your username again in $_daysUntilNextChange days',
                                  style: TextStyle(
                                    color: AppTheme.primaryRed.withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                  TextFormField(
                    controller: _usernameController,
                    enabled: _canChangeUsername,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: const Icon(Icons.person),
                      enabled: _canChangeUsername,
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Username is required';
                      }
                      if (value.length < 3) {
                        return 'Username must be at least 3 characters';
                      }
                      if (value.length > 20) {
                        return 'Username must be less than 20 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Choose Avatar',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: AppTheme.primaryBlack,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: _avatars.length,
                      itemBuilder: (context, index) {
                        final avatar = _avatars[index];
                        final isSelected = avatar['id'] == _selectedAvatar;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _selectedAvatar = avatar['id']),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? avatar['color'].withOpacity(0.1)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(16),
                              border: isSelected
                                  ? Border.all(color: avatar['color'], width: 2)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SvgPicture.asset(
                                  avatar['path'],
                                  height: 48,
                                  colorFilter: ColorFilter.mode(
                                    avatar['color'],
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  avatar['name'],
                                  style: TextStyle(
                                    color: isSelected
                                        ? avatar['color']
                                        : Colors.grey[600],
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Game Preferences Section
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryWhite,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withOpacity(0.1),
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Game Preferences',
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: AppTheme.primaryBlack,
                                    fontWeight: FontWeight.bold,
                                  ),
                        ),
                        const SizedBox(height: 24),

                        // Time Control Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Preferred Time Control',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.timer),
                          ),
                          value: _selectedTimeControl,
                          items: _timeControlOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedTimeControl = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // Color Preference Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Preferred Color',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.circle),
                          ),
                          value: _selectedColor,
                          items: _colorOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedColor = newValue!;
                            });
                          },
                        ),
                        const SizedBox(height: 16),

                        // AI Difficulty Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'AI Difficulty',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.smart_toy),
                          ),
                          value: _selectedDifficulty,
                          items: _difficultyOptions.map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                          onChanged: (newValue) {
                            setState(() {
                              _selectedDifficulty = newValue!;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                  // Single button for all profile changes

                  // Standard profile update button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Save Changes',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
