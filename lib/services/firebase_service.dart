import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:chatify_final_project/firebase_options.dart';

class FirebaseService {
  bool _initialized = false;

  bool get isInitialized => _initialized;

  Future<void> init() async {
    if (_initialized) {
      if (kDebugMode) {
        print('Firebase already initialized');
      }
      return;
    }

    try {
      if (kDebugMode) {
        print('Starting Firebase initialization...');
        print('Current platform: ${defaultTargetPlatform.toString()}');
      }

      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      _initialized = true;

      if (kDebugMode) {
        print('✓ Firebase initialized successfully');
        print('  - Project ID: chat-app-a9877');
        print('  - Auth enabled: true');
      }
    } on FirebaseException catch (e) {
      if (kDebugMode) {
        print('✗ Firebase initialization error: ${e.code}');
        print('  Message: ${e.message}');
      }
      rethrow;
    } catch (e) {
      if (kDebugMode) {
        print('✗ Unexpected error initializing Firebase: $e');
      }
      rethrow;
    }
  }
}
