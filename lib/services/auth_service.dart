import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatify_final_project/services/presence_service.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/services/app_lifecycle_service.dart';
import 'package:chatify_final_project/services/message_listener_service.dart';

import '../app/routes.dart';
import 'call_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> _saveFcmToken(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✓ FCM token saved for user: $userId');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('✗ Failed to save FCM token: $e');
      }
    }
  }

  void _setupTokenRefreshListener(String userId) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': newToken,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (kDebugMode) {
          print('✓ FCM token refreshed for user: $userId');
        }
      } catch (e) {
        if (kDebugMode) {
          print('✗ Failed to update refreshed FCM token: $e');
        }
      }
    });
  }

  // Temporary method - you can delete it after Cloud Function is deployed
  Future<void> _updateOnlineStatus(String userId, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).timeout(const Duration(seconds: 5));
    } catch (e) {
      if (kDebugMode) {
        print('Warning: Failed to update online status: $e');
      }
    }
  }

  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password should be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'No internet connection.';
      default:
        return e.message ?? 'An authentication error occurred.';
    }
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final userId = credential.user?.uid;
      if (userId != null) {
        await _saveFcmToken(userId);
        _setupTokenRefreshListener(userId);

        final presenceService = Get.put(PresenceService());
        await presenceService.initialize();

        Get.put(AppLifecycleService());

        // Initialize message listener service for notifications
        try {
          if (Get.isRegistered<MessageListenerService>()) {
            // Service already exists, restart it
            final messageListener = Get.find<MessageListenerService>();
            messageListener.restart();
          } else {
            // Create new service
            Get.put(MessageListenerService(), permanent: true);
          }
        } catch (e) {
          if (kDebugMode) print('Error initializing MessageListenerService: $e');
          // Try to create it anyway
          Get.put(MessageListenerService(), permanent: true);
        }
      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Failed to sign in. Please try again.');
    }
  }

  Future<UserCredential> signUpWithEmail(
      String email,
      String password,
      String displayName, {
        String? bio,
        String? avatarUrl,
      }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        await user.updateDisplayName(displayName);

        await _firestore.collection('users').doc(user.uid).set({
          'displayName': displayName,
          'email': email.trim().toLowerCase(),
          'avatarUrl': avatarUrl ?? '',
          'bio': bio ?? '',
          'isOnline': true, // Will be synced correctly by Cloud Function
          'lastSeen': FieldValue.serverTimestamp(),
          'createdAt': FieldValue.serverTimestamp(),
          'notificationsEnabled': true,
        });

        await _saveFcmToken(user.uid);
        _setupTokenRefreshListener(user.uid);

        // Initialize realtime presence
        final presenceService = Get.put(PresenceService());
        await presenceService.initialize();

        Get.put(AppLifecycleService());

        // Initialize message listener service for notifications
        try {
          if (Get.isRegistered<MessageListenerService>()) {
            final messageListener = Get.find<MessageListenerService>();
            messageListener.restart();
          } else {
            // Do NOT use permanent: true - this is the issue!
            Get.put(MessageListenerService()); // Remove permanent: true
          }
        } catch (e) {
          if (kDebugMode) print('Error initializing MessageListenerService: $e');
          // Try to create it anyway
          Get.put(MessageListenerService(), permanent: true);
        }

      }

      return credential;
    } on FirebaseAuthException catch (e) {
      throw Exception(_handleAuthException(e));
    } catch (e) {
      throw Exception('Failed to create account. Please try again.');
    }
  }

  Future<void> signOut() async {
    try {
      print('🚪 Starting sign out...');

      final userId = _auth.currentUser?.uid;

      // 1️⃣ Update online status in Firestore
      if (userId != null) {
        await _firestore.collection('users').doc(userId).update({
          'isOnline': false,
          'lastSeen': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 8));
        print('✅ User marked as offline');
      }

      // 2️⃣ Clean up GetX services
      if (Get.isRegistered<PresenceService>()) {
        await Get.find<PresenceService>().prepareForLogout();
        Get.delete<PresenceService>();
      }
      if (Get.isRegistered<AppLifecycleService>()) {
        Get.delete<AppLifecycleService>();
      }
      if (Get.isRegistered<MessageListenerService>()) {
        Get.delete<MessageListenerService>();
      }
      if (Get.isRegistered<WebRTCCallService>()) {
        Get.delete<WebRTCCallService>();
      }

      // 3️⃣ Delete FCM token
      await _clearLocalStorage();

      // 4️⃣ Sign out from Firebase Auth
      await _auth.signOut();
      print('✅ Firebase Auth signed out');

      // 5️⃣ MANUALLY navigate to login — this forces immediate redirect
      Get.offAllNamed(AppRoutes.login);

      print('✅ Navigated to login screen');

    } catch (e) {
      print('❌ Sign out error: $e');
      // Even on error, force sign out and go to login
      try {
        await _auth.signOut();
      } catch (_) {}
      Get.offAllNamed(AppRoutes.login);
    }
  }

  Future<void> _clearLocalStorage() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      if (kDebugMode) print('🗑️ FCM token deleted from device');
    } catch (e) {
      if (kDebugMode) print('❌ Error deleting FCM token: $e');
    }
  }

  Future<void> updatePassword(String newPassword) async {
      try {
        await _auth.currentUser?.updatePassword(newPassword);
      } on FirebaseAuthException catch (e) {
        throw Exception(_handleAuthException(e));
      }
    }

    Future<void> updateEmail(String newEmail) async {
      try {
        await _auth.currentUser?.verifyBeforeUpdateEmail(
            newEmail.trim().toLowerCase());
      } on FirebaseAuthException catch (e) {
        throw Exception(_handleAuthException(e));
      }
    }

    Future<void> refreshFcmToken() async {
      final userId = _auth.currentUser?.uid;
      if (userId != null) {
        await _saveFcmToken(userId);
      }
    }
}