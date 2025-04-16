import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uptm_chess/theme/app_theme.dart';
import 'package:uptm_chess/widgets/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _isLoading = false;
  String _searchQuery = '';
  final currentUser = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  int _friendCount = 0;
  int _requestCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
    _loadCounts();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCounts() async {
    try {
      // Use cached false to guarantee we get the latest data
      final friendsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friends')
          .get(GetOptions(source: Source.serverAndCache));

      final requestsSnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friendRequests')
          .get(GetOptions(source: Source.serverAndCache));
      
      debugPrint('Friend count: ${friendsSnapshot.size}');
      debugPrint('Request count: ${requestsSnapshot.size}');

      if (mounted) {
        setState(() {
          _friendCount = friendsSnapshot.size;
          _requestCount = requestsSnapshot.size;
        });
      }
    } catch (e) {
      debugPrint('Error loading counts: $e');
    }
  }

  Future<void> _sendFriendRequest(String username) async {
    if (username.isEmpty) {
      showSnackBar(
        context: context,
        content: 'Please enter a username',
        backgroundColor: Colors.red,
      );
      return;
    }

    setState(() => _isLoading = true);

    // Refresh authentication token before proceeding
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken(true);
    } catch (tokenError) {
      debugPrint('Error refreshing token: $tokenError');
    }

    try {
      // Step 1: Check if user exists
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: username)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        showSnackBar(
          context: context,
          content: 'User not found',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
        return;
      }

      final friendDoc = userQuery.docs.first;
      final friendId = friendDoc.id;

      // Step 2: Don't allow adding yourself
      if (friendId == currentUser?.uid) {
        showSnackBar(
          context: context,
          content: 'You cannot add yourself as a friend',
          backgroundColor: Colors.red,
        );
        setState(() => _isLoading = false);
        return;
      }

      // Step 3: Check if already friends
      // This is allowed because we're checking our OWN friends collection
      final friendshipCheck = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friends')
          .doc(friendId)
          .get();

      if (friendshipCheck.exists) {
        showSnackBar(
          context: context,
          content: 'Already friends with this user',
          backgroundColor: Colors.orange,
        );
        setState(() => _isLoading = false);
        return;
      }

      // IMPORTANT: We're skipping the check for existing friend requests
      // because security rules prevent us from reading another user's requests

      // Step 4: Get current user's data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();

      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;

      // Step 5: Create friend request with auto-ID (compatible with security rules)
      debugPrint('Creating friend request using add() with auto-ID...');

      // Prepare request data with field names matching the display code
      final data = {
        'username': currentUserData['name'],  // Changed from 'name' to 'username'
        'image': currentUserData['image'],
        'sentAt': FieldValue.serverTimestamp(), // Changed from 'timestamp' to 'sentAt'
        'uid': currentUser?.uid,
      };

      // Use add() instead of set() - this only requires 'create' permission
      // and doesn't need to check if the document exists first
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendId)
          .collection('friendRequests')
          .add(data);

      showSnackBar(
        context: context,
        content: 'Friend request sent!',
        backgroundColor: Colors.green,
      );
      _usernameController.clear();
    } catch (e) {
      // Handle specific error types
      if (e.toString().contains('permission-denied')) {
        showSnackBar(
          context: context,
          content: 'Permission denied. You may have already sent a request.',
          backgroundColor: Colors.orange,
        );
      } else {
        debugPrint('Error sending friend request: $e');
        showSnackBar(
          context: context,
          content: 'Error sending friend request. Please try again.',
          backgroundColor: Colors.red,
        );
      }
    }

    setState(() => _isLoading = false);
  }

  Future<void> _acceptFriendRequest(String requestDocId, String username) async {
    try {
      debugPrint('Accepting friend request with document ID: $requestDocId');
      
      // Get the friend request details first to extract requester's UID
      final requestDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friendRequests')
          .doc(requestDocId)
          .get();
          
      if (!requestDoc.exists) {
        showSnackBar(
          context: context,
          content: 'Friend request no longer exists',
          backgroundColor: Colors.orange,
        );
        return;
      }
      
      final requestData = requestDoc.data() as Map<String, dynamic>;
      final userId = requestData['uid'] as String?; // Get the sender's user ID
      
      if (userId == null) {
        showSnackBar(
          context: context,
          content: 'Invalid friend request data',
          backgroundColor: Colors.red,
        );
        return;
      }
      
      debugPrint('Adding user $userId to friends list');
      
      // Use batch writes to ensure atomicity of friend operations
      final batch = FirebaseFirestore.instance.batch();
      final timestamp = FieldValue.serverTimestamp();
      
      // Reference to my friend document
      final myFriendRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friends')
          .doc(userId);
      
      // Get current user data
      final currentUserDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .get();
      final currentUserData = currentUserDoc.data() as Map<String, dynamic>;
      
      // Reference to their friend document
      final theirFriendRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('friends')
          .doc(currentUser?.uid);
      
      // Reference to the friend request document to delete
      final requestRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friendRequests')
          .doc(requestDocId);
      
      // Add friend document to my collection
      batch.set(myFriendRef, {
        'username': username,
        'image': requestData['image'],
        'addedAt': timestamp,
        'userId': userId // Store the actual user ID for easier reference
      });
      
      // Add friend document to their collection
      batch.set(theirFriendRef, {
        'username': currentUserData['name'],
        'image': currentUserData['image'],
        'addedAt': timestamp,
        'userId': currentUser?.uid // Store the actual user ID for easier reference
      });
      
      // Delete the friend request
      batch.delete(requestRef);
      
      // Commit all operations as a single transaction
      await batch.commit();
      debugPrint('Successfully committed friend operations');

      // Force refresh the screen counts
      await _loadCounts();
      setState(() {}); // Trigger UI refresh

      showSnackBar(
        context: context,
        content: 'Friend request accepted!',
        backgroundColor: Colors.green,
      );
      
      // Switch to Friends tab to show the new friend
      _tabController.animateTo(0);
    } catch (e) {
      debugPrint('Error accepting friend request: $e');
      showSnackBar(
        context: context,
        content: 'Error accepting friend request. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  Future<void> _declineFriendRequest(String requestDocId) async {
    try {
      debugPrint('Declining friend request with document ID: $requestDocId');
      
      // Delete the friend request using the document ID directly
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friendRequests')
          .doc(requestDocId)
          .delete();

      // Force refresh the screen counts and UI
      await _loadCounts();
      setState(() {}); // Trigger UI refresh
      
      showSnackBar(
        context: context,
        content: 'Friend request declined',
        backgroundColor: Colors.blue,
      );
    } catch (e) {
      debugPrint('Error declining friend request: $e');
      showSnackBar(
        context: context,
        content: 'Error declining friend request. Please try again.',
        backgroundColor: Colors.red,
      );
    }
  }

  Widget _buildFriendAvatar(String username, String? avatarId) {
    return Container(
      width: 50,
      height: 50,
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
          : Center(
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : '?',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
    );
  }

  Widget _buildFriendsList() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search friends...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              filled: true,
              fillColor: Colors.white,
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser?.uid)
                .collection('friends')
                .orderBy('addedAt', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(child: Text('Something went wrong'));
              }

              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final friends = snapshot.data?.docs ?? [];
              final filteredFriends = friends.where((doc) {
                final friend = doc.data() as Map<String, dynamic>;
                final username = friend['username'] as String;
                return username.toLowerCase().contains(_searchQuery);
              }).toList();

              if (friends.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.people_outline_rounded,
                            size: 64,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'Your Friends List is Empty',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start connecting with other players by adding them as friends!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              _tabController
                                  .animateTo(2); // Switch to Add Friend tab
                            },
                            icon: const Icon(Icons.person_add_rounded),
                            label: const Text(
                              'Add Friends',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (filteredFriends.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off_rounded,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No friends found matching "$_searchQuery"',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear),
                        label: const Text('Clear Search'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: filteredFriends.length,
                itemBuilder: (context, index) {
                  final friend =
                      filteredFriends[index].data() as Map<String, dynamic>;
                  final username = friend['username'] as String;
                  final avatarId = friend['image'] as String?;
                  final timestamp = friend['addedAt'] as Timestamp?;
                  final addedDate = timestamp?.toDate() ?? DateTime.now();

                  return Dismissible(
                    key: Key(filteredFriends[index].id),
                    background: Container(
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      child: const Icon(
                        Icons.delete_outline,
                        color: Colors.red,
                      ),
                    ),
                    direction: DismissDirection.endToStart,
                    confirmDismiss: (direction) async {
                      return await showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Remove Friend'),
                            content: Text(
                                'Are you sure you want to remove $username from your friends list?'),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: const Text('CANCEL'),
                              ),
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: const Text('REMOVE'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    onDismissed: (direction) async {
                      try {
                        // Remove from current user's friends
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(currentUser?.uid)
                            .collection('friends')
                            .doc(filteredFriends[index].id)
                            .delete();

                        // Remove from other user's friends
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(filteredFriends[index].id)
                            .collection('friends')
                            .doc(currentUser?.uid)
                            .delete();

                        // Update friend count
                        setState(() {
                          _friendCount--;
                        });

                        showSnackBar(
                          context: context,
                          content: 'Friend removed successfully',
                          backgroundColor: Colors.green,
                        );
                      } catch (e) {
                        showSnackBar(
                          context: context,
                          content: 'Error removing friend. Please try again.',
                          backgroundColor: Colors.red,
                        );
                      }
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: _buildFriendAvatar(username, avatarId),
                        title: Text(
                          username,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          'Added ${_formatDate(addedDate)}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.swipe_left_alt_rounded,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Swipe to remove',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFriendRequests() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser?.uid)
          .collection('friendRequests')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final requests = snapshot.data?.docs ?? [];
        if (requests.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.mail_outline_rounded,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No friend requests',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final requestData = requests[index].data() as Map<String, dynamic>;
            final username = requestData['username'] as String? ?? 'Unknown';
            final avatarId = requestData['image'] as String?;
            final timestamp = requestData['sentAt'] as Timestamp?;

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    _buildFriendAvatar(username, avatarId),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          if (timestamp != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTimestamp(timestamp),
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline),
                          color: Colors.green,
                          onPressed: () => _acceptFriendRequest(
                              requests[index].id, username),
                        ),
                        IconButton(
                          icon: const Icon(Icons.cancel_outlined),
                          color: Colors.red,
                          onPressed: () =>
                              _declineFriendRequest(requests[index].id),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAddFriend() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    hintText: 'Enter username',
                    prefixIcon: const Icon(Icons.person_add_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _isLoading
                      ? null
                      : () =>
                          _sendFriendRequest(_usernameController.text.trim()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Friend Request'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today';
    } else if (difference.inDays == 1) {
      return 'yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(text: 'Friends ($_friendCount)'),
            Tab(
                text: _requestCount > 0
                    ? 'Requests ($_requestCount)'
                    : 'Requests'),
            const Tab(text: 'Add'),
          ],
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: AppTheme.primaryBlue,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFriendsList(),
          _buildFriendRequests(),
          _buildAddFriend(),
        ],
      ),
    );
  }
}
