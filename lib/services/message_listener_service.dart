import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/services/notification_service.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/encryption_service.dart';

/// Service to listen for new messages and trigger notifications
class MessageListenerService extends GetxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _chatsListener;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsListener;
  final Set<String> _activeChatIds = {}; // Track which chats user is currently viewing

  String? get currentUserId => _auth.currentUser?.uid;

  @override
  void onInit() {
    super.onInit();
    _startListening();
  }

  @override
  void onClose() {
    _stopListening();
    super.onClose();
  }

  void _startListening() {
    final userId = currentUserId;
    if (userId == null) {
      if (kDebugMode) print('MessageListenerService: No user ID, cannot start listening');
      return;
    }

    // Cancel existing listeners first to prevent duplicates
    _stopListening();

    if (kDebugMode) print('MessageListenerService: Starting listeners for user: $userId');

    // Listen to all chats where user is a participant
    _chatsListener = _firestore
        .collection('chats')
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (kDebugMode) print('MessageListenerService: Chats snapshot received with ${snapshot.docChanges.length} changes');
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final chatId = change.doc.id;
            final data = change.doc.data();
            
            // Check if this is a new message (lastMessageTime changed)
            if (data!.containsKey('lastMessage') &&
                data['lastMessage'] != null && 
                (data['lastMessage'] as String).isNotEmpty) {
              if (kDebugMode) print('MessageListenerService: New message detected in chat: $chatId');
              _handleNewMessage(chatId, data, false);
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print('MessageListenerService: Error in chats listener: $error');
      },
    );

    // Listen to all groups where user is a member
    _groupsListener = _firestore
        .collection('groups')
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .listen(
      (snapshot) {
        if (kDebugMode) print('MessageListenerService: Groups snapshot received with ${snapshot.docChanges.length} changes');
        for (var change in snapshot.docChanges) {
          if (change.type == DocumentChangeType.modified) {
            final groupId = change.doc.id;
            final data = change.doc.data();
            
            // Check if this is a new message
            if (data!.containsKey('lastMessage') &&
                data['lastMessage'] != null && 
                (data['lastMessage'] as String).isNotEmpty) {
              if (kDebugMode) print('MessageListenerService: New message detected in group: $groupId');
              _handleNewMessage(groupId, data, true);
            }
          }
        }
      },
      onError: (error) {
        if (kDebugMode) print('MessageListenerService: Error in groups listener: $error');
      },
    );
  }

  void _handleNewMessage(String chatId, Map<String, dynamic> data, bool isGroup) async {
    final userId = currentUserId;
    if (userId == null) {
      if (kDebugMode) print('MessageListenerService: No user ID in _handleNewMessage');
      return;
    }

    // Don't notify if user is currently viewing this chat
    if (_activeChatIds.contains(chatId)) {
      if (kDebugMode) print('MessageListenerService: Chat $chatId is active, skipping notification');
      return;
    }

    // Check if message is from another user
    final lastMessageSender = data['lastMessageSenderId'] as String?;
    if (lastMessageSender == userId) {
      if (kDebugMode) print('MessageListenerService: Message is from current user, skipping notification');
      return; // Don't notify for own messages
    }

    // Check unread count
    final unreadCounts = data['unreadCounts'] as Map<String, dynamic>? ?? {};
    final unreadCount = (unreadCounts[userId] as int?) ?? 0;

    if (unreadCount > 0) {
      String lastMessage = data['lastMessage'] as String? ?? 'New message';
      
      // Decrypt the message if it's encrypted
      final encKey = data['encKey'] as String?;
      final encIv = data['encIv'] as String?;
      if (encKey != null && encIv != null && lastMessage.isNotEmpty) {
        // Check if it's an emoji/icon message (non-text message types)
        // These are stored as plain emoji strings and don't need decryption
        if (lastMessage != '📷 Image' && lastMessage != '📄 Document' && 
            lastMessage != '🎤 Voice message') {
          try {
            final encryptionService = EncryptionService();
            lastMessage = encryptionService.decrypt(
              cipherText: lastMessage,
              base64Key: encKey,
              base64Iv: encIv,
            );
          } catch (e) {
            if (kDebugMode) print('MessageListenerService: Error decrypting message: $e');
            // Keep the encrypted message as fallback
          }
        }
      }
      
      String title;
      String? contactName;
      String? otherUserId;

      if (isGroup) {
        title = data['name'] as String? ?? 'Group';
      } else {
        // Get other participant's name
        final participantIds = List<String>.from(data['participantIds'] ?? []);
        otherUserId = participantIds.firstWhere(
          (id) => id != userId,
          orElse: () => '',
        );
        
        if (otherUserId.isNotEmpty) {
          try {
            final chatService = Get.find<ChatService>();
            final otherUser = await chatService.getUserById(otherUserId);
            contactName = otherUser?.displayName ?? 'User';
            title = contactName;
          } catch (e) {
            if (kDebugMode) print('MessageListenerService: Error getting user name: $e');
            title = 'New message';
          }
        } else {
          title = 'New message';
        }
      }

      if (kDebugMode) print('MessageListenerService: Showing notification for $chatId - $title: $lastMessage');

      // Show notification
      await NotificationService.showMessageNotification(
        title: title,
        body: lastMessage,
        chatId: chatId,
        contactName: contactName,
        otherUserId: isGroup ? null : otherUserId,
        isGroup: isGroup,
      );
    } else {
      if (kDebugMode) print('MessageListenerService: Unread count is 0, skipping notification');
    }
  }

  void _stopListening() {
    _chatsListener?.cancel();
    _chatsListener = null;
    _groupsListener?.cancel();
    _groupsListener = null;
    _activeChatIds.clear();
  }

  /// Mark a chat as active (user is viewing it)
  void markChatAsActive(String chatId) {
    _activeChatIds.add(chatId);
  }

  /// Mark a chat as inactive (user left it)
  void markChatAsInactive(String chatId) {
    _activeChatIds.remove(chatId);
  }

  void reset() {
    if (kDebugMode) print('MessageListenerService: Resetting listeners');
    _stopListening();
    _startListening();
  }

  /// Restart listening (useful when user logs in)
  void restart() {
    if (kDebugMode) print('MessageListenerService: Restarting service');
    _stopListening();
    _startListening();
  }
}

