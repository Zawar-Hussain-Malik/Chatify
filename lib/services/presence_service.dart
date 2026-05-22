// lib/services/presence_service.dart
import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

class PresenceService extends GetxService {
  final DatabaseReference _database = FirebaseDatabase.instance.ref();
  final _auth = FirebaseAuth.instance;

  bool _isInitialized = false;
  bool _isInitializing = false;
  StreamSubscription<DatabaseEvent>? _connectionSub;
  Completer<void>? _initCompleter;

  @override
  void onInit() {
    super.onInit();
    if (kDebugMode) print('PresenceService: onInit called');
  }

  @override
  void onClose() {
    if (kDebugMode) print('PresenceService: onClose called');

    // Cancel any active subscriptions
    _connectionSub?.cancel();
    _connectionSub = null;

    // Reset all state
    _isInitialized = false;
    _isInitializing = false;
    _initCompleter = null;

    super.onClose();
  }

  Future<void> initialize() async {
    // If already initialized, return immediately
    if (_isInitialized) {
      if (kDebugMode) print('PresenceService: Already initialized');
      return;
    }

    // If currently initializing, wait for that to complete
    if (_isInitializing && _initCompleter != null) {
      if (kDebugMode) print('PresenceService: Waiting for ongoing initialization');
      return _initCompleter!.future;
    }

    final user = _auth.currentUser;
    if (user == null) {
      if (kDebugMode) print('PresenceService: No user logged in');
      return;
    }

    _isInitializing = true;
    _initCompleter = Completer<void>();

    try {
      // Cancel any existing connection subscription first
      await _connectionSub?.cancel();
      _connectionSub = null;

      await _setupPresenceForUser(user.uid);
      _isInitialized = true;
      _isInitializing = false;
      _initCompleter!.complete();
      _initCompleter = null;

      if (kDebugMode) print('✓ PresenceService initialized for user: ${user.uid}');
    } catch (e) {
      _isInitializing = false;
      _initCompleter!.completeError(e);
      _initCompleter = null;
      if (kDebugMode) print('✗ Error initializing PresenceService: $e');
      rethrow;
    }
  }

  Future<void> _setupPresenceForUser(String userId) async {
    try {
      final userStatusRef = _database.child('status/$userId');
      final connectedRef = _database.child('.info/connected');

      // Cancel existing subscription if any
      await _connectionSub?.cancel();

      _connectionSub = connectedRef.onValue.listen((event) async {
        try {
          final isConnected = event.snapshot.value as bool?;

          if (isConnected != true) {
            if (kDebugMode) print('PresenceService: Not connected');
            return;
          }

          if (kDebugMode) print('PresenceService: Connected');

          // Register onDisconnect handler (this is idempotent - Firebase handles duplicates)
          // This ensures offline status is set when connection is lost
          await userStatusRef.onDisconnect().set({
            'state': 'offline',
            'last_changed': ServerValue.timestamp,
          });

          // Note: We don't automatically set online here
          // Online status is set explicitly via setOnline() when app is active
        } catch (e) {
          if (kDebugMode) print('✗ Error in connection listener: $e');
        }
      }, onError: (error) {
        if (kDebugMode) print('✗ Connection listener error: $error');
      });
    } catch (e) {
      if (kDebugMode) print('✗ Error setting up presence: $e');
      rethrow;
    }
  }

  /// Set user as online (call when app is active/foreground)
  Future<void> setOnline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userStatusRef = _database.child('status/${user.uid}');
      await userStatusRef.set({
        'state': 'online',
        'last_changed': ServerValue.timestamp,
      });

      if (kDebugMode) print('✓ User ${user.uid} set as online');
    } catch (e) {
      if (kDebugMode) print('✗ Error setting online: $e');
    }
  }

  /// Set user as offline (call when app goes to background or closes)
  Future<void> setOffline() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final userStatusRef = _database.child('status/${user.uid}');
      await userStatusRef.set({
        'state': 'offline',
        'last_changed': ServerValue.timestamp,
      });

      if (kDebugMode) print('✓ User ${user.uid} set as offline');
    } catch (e) {
      if (kDebugMode) print('✗ Error setting offline: $e');
    }
  }

  Stream<Map<String, dynamic>?> getUserStatus(String userId) {
    return _database.child('status/$userId').onValue.map((event) {
      if (event.snapshot.value == null) {
        // Return offline status if no data
        return {
          'state': 'offline',
          'last_changed': DateTime.now().millisecondsSinceEpoch,
        };
      }

      final value = event.snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      // Return offline status if value is not a map
      return {
        'state': 'offline',
        'last_changed': DateTime.now().millisecondsSinceEpoch,
      };
    }).handleError((error) {
      if (kDebugMode) print('Error in getUserStatus stream: $error');
      // Return offline status on error
      return {
        'state': 'offline',
        'last_changed': DateTime.now().millisecondsSinceEpoch,
      };
    });
  }

  Future<bool> isUserOnline(String userId) async {
    try {
      final snapshot = await _database.child('status/$userId/state').get();
      return snapshot.value == 'online';
    } catch (e) {
      if (kDebugMode) print('Error checking online status: $e');
      return false;
    }
  }

  Future<DateTime?> getLastSeen(String userId) async {
    try {
      final snapshot =
      await _database.child('status/$userId/last_changed').get();
      if (snapshot.value == null) return null;

      final timestamp = snapshot.value;
      if (timestamp is int) {
        return DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
      return null;
    } catch (e) {
      if (kDebugMode) print('Error getting last seen: $e');
      return null;
    }
  }

  String getLastSeenText(DateTime? lastSeen, bool isOnline) {
    if (isOnline) return 'Online';
    if (lastSeen == null) return 'Offline';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes}m ago';
    if (difference.inHours < 24) return '${difference.inHours}h ago';
    if (difference.inDays == 1) return 'Yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d ago';

    return '${lastSeen.day}/${lastSeen.month}/${lastSeen.year}';
  }

  Future<void> disconnect() async {
    try {
      if (kDebugMode) print('PresenceService: disconnect() called');

      // Cancel subscription first
      await _connectionSub?.cancel();
      _connectionSub = null;

      // Set offline
      await setOffline();

      // Reset state
      _isInitialized = false;
      _isInitializing = false;
      _initCompleter = null;

      if (kDebugMode) print('✓ PresenceService disconnected');
    } catch (e) {
      if (kDebugMode) print('✗ Error disconnecting: $e');
    }
  }

  void reset() {
    if (kDebugMode) print('PresenceService: reset() called');

    _isInitialized = false;
    _isInitializing = false;
    _connectionSub?.cancel();
    _connectionSub = null;
    _initCompleter = null;
  }

  /// Check if service is initialized
  bool get isInitialized => _isInitialized;

  /// Check if service is currently initializing
  bool get isInitializing => _isInitializing;

  /// Clean up and prepare for logout
  Future<void> prepareForLogout() async {
    if (kDebugMode) print('PresenceService: prepareForLogout() called');

    // Cancel subscription first
    await _connectionSub?.cancel();
    _connectionSub = null;

    // Set user as offline in Firebase Realtime Database
    final user = _auth.currentUser;
    if (user != null) {
      try {
        await _database.child('status/${user.uid}').set({
          'state': 'offline',
          'last_changed': ServerValue.timestamp,
        });
        if (kDebugMode) print('✓ User marked as offline in Realtime Database');
      } catch (e) {
        if (kDebugMode) print('Note: Could not update Realtime Database: $e');
      }
    }

    // Reset state
    _isInitialized = false;
    _isInitializing = false;
    _initCompleter = null;
  }
}