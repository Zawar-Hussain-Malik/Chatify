import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:get/get.dart'; // Since you're using GetX
import 'package:chatify_final_project/app/routes.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';

import 'encryption_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
  FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    // Initialize local notifications
    const AndroidInitializationSettings androidInit =
    AndroidInitializationSettings('@mipmap/ic_launcher'); // Your app icon
    const DarwinInitializationSettings iosInit =
    DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );
    const InitializationSettings initSettings =
    InitializationSettings(android: androidInit, iOS: iosInit);

    await _notificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (response.payload != null) {
          // Navigate to chat when notification is tapped
          Get.toNamed(
            AppRoutes.chat,
            arguments: {
              'chatId': response.payload!,
            },
          );
        }
      },
    );

    // Create Android notification channel (required for heads-up notifications)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'chat_messages', // ID
      'Chat Messages', // Name
      description: 'Notifications for new chat messages',
      importance: Importance.max,
      playSound: true,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Request permissions (iOS/Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    // Request Android notification permission (Android 13+)
    if (Platform.isAndroid) {
      final androidInfo = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      if (kDebugMode) {
        print('Android notification permission: $androidInfo');
      }
    }

    // Foreground messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.data.isNotEmpty) {
        _showLocalNotification(message);
      }
      // Optionally update UI in foreground (e.g., show in-app banner)
    });

    // When user taps notification (app in background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _navigateToChat(message);
    });

    // Initial message if app opened from terminated state via notification
    RemoteMessage? initialMessage =
    await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _navigateToChat(initialMessage);
    }
  }

  static void _showLocalNotification(RemoteMessage message) {
    final data = message.data;

    String title = 'New Message';
    String body = 'You have a new message';

    try {
      if (data.containsKey('title') &&
          data.containsKey('body') &&
          data.containsKey('key') &&
          data.containsKey('iv')) {

        title = EncryptionService().decrypt(
          cipherText: data['title'],
          base64Key: data['key'],
          base64Iv: data['iv'],
        );

        body = EncryptionService().decrypt(
          cipherText: data['body'],
          base64Key: data['key'],
          base64Iv: data['iv'],
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Notification Decryption Error: $e');
      }
    }

    _notificationsPlugin.show(
      message.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'chat_messages',
          'Chat Messages',
          channelDescription: 'New chat messages',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(sound: 'default'),
      ),
      payload: data['chatId'],
    );
  }

  static void _navigateToChat(RemoteMessage message) {
    // Extract chat/group ID from message.data (you'll set this server-side)
    String? chatId = message.data['chatId'] ?? message.data['chat_id'];
    String? contactName = message.data['contactName'] ?? message.data['contact_name'];
    String? otherUserId = message.data['otherUserId'] ?? message.data['other_user_id'];
    bool? isGroup = message.data['isGroup'] == 'true' || message.data['is_group'] == 'true';
    
    if (chatId != null) {
      // Use GetX navigation to open the chat page
      Get.toNamed(AppRoutes.chat, arguments: {
        'chatId': chatId,
        'contact': contactName ?? 'Chat',
        'otherUserId': otherUserId,
        'isGroup': isGroup ?? false,
      });
    }
  }

  /// Show local notification for new message (called from Firestore listener)
  static Future<void> showMessageNotification({
    required String title,
    required String body,
    required String chatId,
    String? contactName,
    String? otherUserId,
    bool isGroup = false,
  }) async {
    // Check if notifications are enabled
    bool canShowNotification = true;

    // Check Android notification permission (Android 13+)
    if (Platform.isAndroid) {
      final androidInfo = await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.areNotificationsEnabled();
      if (androidInfo == false) {
        if (kDebugMode) print('NotificationService: Android notifications are disabled');
        canShowNotification = false;
      }
    }

    if (!canShowNotification) {
      if (kDebugMode) print('NotificationService: Cannot show notification - permissions not granted');
      return;
    }

    if (kDebugMode) {
      print('NotificationService: Showing notification - $title: $body');
    }

    try {
      await _notificationsPlugin.show(
        chatId.hashCode,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            'chat_messages',
            'Chat Messages',
            channelDescription: 'New chat messages',
            importance: Importance.max,
            priority: Priority.high,
            icon: '@mipmap/ic_launcher',
            showWhen: true,
            enableVibration: true,
            playSound: true,
            autoCancel: false, // Don't auto-dismiss notifications
            ongoing: false, // Not ongoing, but won't auto-dismiss
          ),
          iOS: const DarwinNotificationDetails(
            sound: 'default',
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: chatId,
      );
    } catch (e) {
      if (kDebugMode) print('NotificationService: Error showing notification: $e');
    }
  }
}