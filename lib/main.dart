import 'package:chatify_final_project/services/call_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/app/bindings/initial_binding.dart';
import 'package:chatify_final_project/services/firebase_service.dart';
import 'package:chatify_final_project/services/notification_service.dart';
import 'package:get_storage/get_storage.dart';

// This MUST be a top-level function (outside any class)
// Required for background/terminated notifications
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Initialize Firebase in background isolate
  await FirebaseService().init(); // Re-use your existing init logic
  if (kDebugMode) {
    print("Background message received: ${message.messageId}");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();
  await GetStorage.init();

  try {
    final firebaseService = FirebaseService();
    await firebaseService.init();
    if (kDebugMode) {
      print('✓ Firebase initialized successfully');
    }

    // Set the background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Initialize notifications (permissions, channels, listeners)
    await NotificationService.initialize();

    // ← ADD THIS: Initialize WebRTC Call Service
    Get.put(WebRTCCallService(), permanent: true);
    if (kDebugMode) {
      print('✓ WebRTC Call Service initialized');
    }

  } catch (e) {
    if (kDebugMode) {
      print('✗ Initialization failed: $e');
    }
    // Continue anyway
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'Chatify',
      initialBinding: InitialBinding(),
      getPages: AppRoutes.pages,
      initialRoute: AppRoutes.splash,
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
    );
  }
}