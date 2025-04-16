import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uptm_chess/models/game_history.dart';
import 'dart:async';

enum HistoryFilter {
  all,
  wins,
  losses,
  draws,
  aiGames,
  onlineGames,
}

class GameHistoryProvider extends ChangeNotifier {
  final List<GameHistory> _gameHistory = [];
  final List<GameHistory> _filteredGameHistory = [];
  bool _isLoading = false;
  HistoryFilter _currentFilter = HistoryFilter.all;
  StreamSubscription<QuerySnapshot>? _gameHistorySubscription;

  List<GameHistory> get gameHistory => _filteredGameHistory.isNotEmpty ? _filteredGameHistory : _gameHistory;
  List<GameHistory> get allGameHistory => _gameHistory;
  bool get isLoading => _isLoading;
  HistoryFilter get currentFilter => _currentFilter;

  // Initialize Firestore
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get a reference to the game_history collection
  CollectionReference get _gameHistoryCollection => 
      _firestore.collection('game_history');

  // Add a new game to history
  Future<void> addGameToHistory(GameHistory game) async {
    try {
      await _gameHistoryCollection.add(game.toFirestore());
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding game to history: $e');
    }
  }

  // Listen to game history updates in real-time
  void listenToGameHistory(String userId, {int limit = 5}) {
    _isLoading = true;
    notifyListeners();

    // Clear any existing subscription
    _gameHistorySubscription?.cancel();

    _gameHistorySubscription = _gameHistoryCollection
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .listen((snapshot) {
          _gameHistory.clear();
          for (var doc in snapshot.docs) {
            _gameHistory.add(GameHistory.fromFirestore(doc));
          }
          _applyCurrentFilter();
          _isLoading = false;
          notifyListeners();
        }, onError: (error) {
          debugPrint('Error listening to game history: $error');
          _isLoading = false;
          notifyListeners();
        });
  }

  // Fetch game history once
  Future<void> fetchGameHistory(String userId, {int limit = 5}) async {
    _isLoading = true;
    notifyListeners();

    try {
      final snapshot = await _gameHistoryCollection
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      _gameHistory.clear();
      for (var doc in snapshot.docs) {
        _gameHistory.add(GameHistory.fromFirestore(doc));
      }
    } catch (e) {
      debugPrint('Error fetching game history: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Apply the current filter to the game history
  void _applyCurrentFilter() {
    _filteredGameHistory.clear();
    
    if (_currentFilter == HistoryFilter.all) {
      // No filtering needed
      return;
    }
    
    switch (_currentFilter) {
      case HistoryFilter.wins:
        _filteredGameHistory.addAll(
          _gameHistory.where((game) => game.result == GameResult.win)
        );
        break;
      case HistoryFilter.losses:
        _filteredGameHistory.addAll(
          _gameHistory.where((game) => game.result == GameResult.loss)
        );
        break;
      case HistoryFilter.draws:
        _filteredGameHistory.addAll(
          _gameHistory.where((game) => game.result == GameResult.draw)
        );
        break;
      case HistoryFilter.aiGames:
        _filteredGameHistory.addAll(
          _gameHistory.where((game) => !game.wasOnline)
        );
        break;
      case HistoryFilter.onlineGames:
        _filteredGameHistory.addAll(
          _gameHistory.where((game) => game.wasOnline)
        );
        break;
      default:
        // No filtering for HistoryFilter.all
        break;
    }
  }
  
  // Set the current filter and apply it
  void setFilter(HistoryFilter filter) {
    if (_currentFilter != filter) {
      _currentFilter = filter;
      _applyCurrentFilter();
      notifyListeners();
    }
  }
  
  // Fetch games by result (using the specialized index)
  Future<void> fetchGamesByResult(String userId, GameResult result, {int limit = 10}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final snapshot = await _gameHistoryCollection
          .where('userId', isEqualTo: userId)
          .where('result', isEqualTo: result.index)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      _gameHistory.clear();
      _filteredGameHistory.clear();
      
      for (var doc in snapshot.docs) {
        _gameHistory.add(GameHistory.fromFirestore(doc));
      }
      
      // Since we've already filtered by result in the query,
      // the filtered list is the same as the main list
      _filteredGameHistory.addAll(_gameHistory);
      
      switch (result) {
        case GameResult.win:
          _currentFilter = HistoryFilter.wins;
          break;
        case GameResult.loss:
          _currentFilter = HistoryFilter.losses;
          break;
        case GameResult.draw:
          _currentFilter = HistoryFilter.draws;
          break;
      }
    } catch (e) {
      debugPrint('Error fetching games by result: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Fetch games by type (AI or online, using the specialized index)
  Future<void> fetchGamesByType(String userId, bool isOnline, {int limit = 10}) async {
    _isLoading = true;
    notifyListeners();
    
    try {
      final snapshot = await _gameHistoryCollection
          .where('userId', isEqualTo: userId)
          .where('wasOnline', isEqualTo: isOnline)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      _gameHistory.clear();
      _filteredGameHistory.clear();
      
      for (var doc in snapshot.docs) {
        _gameHistory.add(GameHistory.fromFirestore(doc));
      }
      
      // Since we've already filtered by game type in the query,
      // the filtered list is the same as the main list
      _filteredGameHistory.addAll(_gameHistory);
      
      _currentFilter = isOnline ? HistoryFilter.onlineGames : HistoryFilter.aiGames;
    } catch (e) {
      debugPrint('Error fetching games by type: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Reset filters and show all games
  void resetFilters(String userId, {int limit = 10}) async {
    _currentFilter = HistoryFilter.all;
    _filteredGameHistory.clear();
    await fetchGameHistory(userId, limit: limit);
  }
  
  // Clean up on dispose
  @override
  void dispose() {
    _gameHistorySubscription?.cancel();
    super.dispose();
  }
}
