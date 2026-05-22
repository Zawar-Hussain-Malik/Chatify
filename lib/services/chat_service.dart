import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/chat_model.dart';
import '../models/group_model.dart';
import '../models/message_model.dart';
import '../models/user_model.dart';
import 'encryption_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final EncryptionService _encryption = EncryptionService();

  String? get currentUserId => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get chats =>
      _firestore.collection('chats');

  CollectionReference<Map<String, dynamic>> get groups =>
      _firestore.collection('groups');

  CollectionReference<Map<String, dynamic>> get users =>
      _firestore.collection('users');

  /* -------------------------------------------------------------------------- */
  /*                               CORE METHODS                                 */
  /* -------------------------------------------------------------------------- */

  Future<String> getOrCreateChat(String otherUserId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final ids = [userId, otherUserId]..sort();
    final chatId = ids.join('_');

    final ref = chats.doc(chatId);
    final snap = await ref.get();

    if (!snap.exists) {
      final enc = EncryptionService.generateChatKey();

      await ref.set({
        'participantIds': ids,
        'createdAt': FieldValue.serverTimestamp(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'unreadCounts': {userId: 0, otherUserId: 0},
        'isGroup': false,
        'encrypted': true,
        'encKey': enc['key'],
        'encIv': enc['iv'],
      });
    }

    return chatId;
  }

  Future<void> sendMessage(String chatId, {
    String? text,
    String? imageUrl,
    String? documentUrl,
    String? documentName,
    String? voiceUrl,
    int? voiceDuration,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    // -----------------------------------------------------------------------
    // 🔧 FIX #1: SAFE GROUP / CHAT DETECTION (NO LOGIC REMOVED)
    // -----------------------------------------------------------------------
    DocumentSnapshot<Map<String, dynamic>> parentSnapshot;
    CollectionReference<Map<String, dynamic>> parentCollection;
    bool isGroup = false;

    try {
      parentSnapshot = await groups.doc(chatId).get();
      if (parentSnapshot.exists) {
        isGroup = true;
        parentCollection = groups;
      } else {
        throw Exception();
      }
    } catch (_) {
      parentSnapshot = await chats.doc(chatId).get();
      if (!parentSnapshot.exists) throw Exception('Chat not found');
      parentCollection = chats;
    }
    // -----------------------------------------------------------------------

    final parentData = parentSnapshot.data()!;
    final String encKey = parentData['encKey'] as String;
    final String encIv = parentData['encIv'] as String;

    String encryptedText = '';
    String preview = '';

    if (text != null && text
        .trim()
        .isNotEmpty) {
      encryptedText = _encryption.encrypt(
        plainText: text.trim(),
        base64Key: encKey,
        base64Iv: encIv,
      );
      preview = encryptedText;
    } else if (imageUrl != null) {
      preview = '📷 Image';
    } else if (documentUrl != null) {
      preview = '📄 Document';
    } else if (voiceUrl != null) {
      preview = '🎤 Voice message';
    }

    // Get other participants
    List<String> otherParticipants = [];
    if (isGroup) {
      final memberIds = List<String>.from(parentData['memberIds'] ?? []);
      otherParticipants = memberIds.where((id) => id != userId).toList();
    } else {
      final participantIds = List<String>.from(
          parentData['participantIds'] ?? []);
      otherParticipants = participantIds.where((id) => id != userId).toList();
    }

    // Create message with sent status
    final messageRef = await parentCollection
        .doc(chatId)
        .collection('messages')
        .add({
      'senderId': userId,
      'text': encryptedText,
      'imageUrl': imageUrl,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'voiceUrl': voiceUrl,
      'voiceDuration': voiceDuration,
      'sentAt': FieldValue.serverTimestamp(),
      'encrypted': encryptedText.isNotEmpty,
      'status': 'sent',
    });

    // Update unread counts for other participants using FieldValue.increment
    // This is atomic and prevents race conditions
    final updates = <String, dynamic>{
      'lastMessage': preview,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastMessageSenderId': userId, // Track who sent the last message
    };

    // Use FieldValue.increment for atomic updates
    for (final participantId in otherParticipants) {
      updates['unreadCounts.$participantId'] = FieldValue.increment(1);
    }

    await parentCollection.doc(chatId).update(updates);

    // Mark message as delivered immediately (no delay needed)
    // The recipient's app will mark it as seen when they open the chat
    try {
      await messageRef.update({'status': 'delivered'});
    } catch (e) {
      if (kDebugMode) print('Error updating message status: $e');
    }
  }

  Stream<List<MessageModel>> decryptedMessagesStream(String chatId) async* {
    final groupSnap = await groups.doc(chatId).get();
    final isGroup = groupSnap.exists;

    Query<Map<String, dynamic>> messagesQuery;

    if (isGroup) {
      messagesQuery = groups.doc(chatId).collection('messages');
    } else {
      messagesQuery = chats.doc(chatId).collection('messages');
    }

    final parentSnap = isGroup ? groupSnap : await chats.doc(chatId).get();
    final parentData = parentSnap.data();

    if (parentData == null ||
        parentData['encKey'] == null ||
        parentData['encIv'] == null) {
      yield* messagesQuery
          .orderBy('sentAt', descending: true)
          .snapshots()
          .map((snapshot) =>
          snapshot.docs
              .map((doc) => MessageModel.fromMap(doc.id, doc.data()))
              .toList());
      return;
    }

    final encKey = parentData['encKey'] as String;
    final encIv = parentData['encIv'] as String;

    yield* messagesQuery
        .orderBy('sentAt', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final messages = <MessageModel>[];

      for (var doc in snapshot.docs) {
        final data = doc.data();
        final message = MessageModel.fromMap(doc.id, data);

        if (message.text.isNotEmpty && data['encrypted'] == true) {
          try {
            final decrypted = _encryption.decrypt(
              cipherText: message.text,
              base64Key: encKey,
              base64Iv: encIv,
            );
            messages.add(message.copyWith(text: decrypted));
          } catch (_) {
            messages.add(message.copyWith(text: '[Failed to decrypt]'));
          }
        } else {
          messages.add(message);
        }
      }
      return messages;
    });
  }

  Stream<List<AppUser>> allUsersStream() {
    return users.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AppUser.fromMap({...doc.data()!, 'id': doc.id}))
          .where((user) => user.id != currentUserId)
          .toList();
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final groupRef = groups.doc(groupId);

    await groupRef.update({
      'memberIds': FieldValue.arrayRemove([userId]),
      'adminIds': FieldValue.arrayRemove([userId]),
    });
  }

  Future<List<AppUser>> getAllUsers() async {
    final snapshot = await users.get();
    return snapshot.docs
        .map((doc) => AppUser.fromMap({...doc.data()!, 'id': doc.id}))
        .where((user) => user.id != currentUserId)
        .toList();
  }

  Stream<AppUser?> userStream(String userId) {
    return users.doc(userId).snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return AppUser.fromMap({...doc.data()!, 'id': userId});
      }
      return null;
    });
  }

  Future<void> deleteGroup(String groupId) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final groupDoc = await groups.doc(groupId).get();
    if (!groupDoc.exists) throw Exception('Group not found');

    final data = groupDoc.data()!;
    final adminIds = List<String>.from(data['adminIds'] ?? []);

    if (!adminIds.contains(userId)) {
      throw Exception('Only admins can delete the group');
    }

    final batch = _firestore.batch();

    final messagesSnapshot =
    await groups.doc(groupId).collection('messages').get();
    for (var doc in messagesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(groups.doc(groupId));
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // 🔧 FIX #2: DELETE MESSAGE WORKS FOR CHAT & GROUP
  // ---------------------------------------------------------------------------
  Future<void> deleteMessage({
    required String chatId,
    required String messageId,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final isGroup = await _isGroupChat(chatId);
    final parent = isGroup ? groups : chats;

    // Verify the user owns the message
    final messageDoc = await parent.doc(chatId).collection('messages').doc(
        messageId).get();
    if (!messageDoc.exists) throw Exception('Message not found');

    final messageData = messageDoc.data()!;
    final messageSenderId = messageData['senderId'] as String?;
    if (messageSenderId != userId) {
      throw Exception('You can only delete your own messages');
    }

    await parent.doc(chatId).collection('messages').doc(messageId).delete();
  }

  /* -------------------------------------------------------------------------- */
  /*                          DEPRECATION LAYER                                 */
  /* -------------------------------------------------------------------------- */

  @Deprecated('Use decryptedMessagesStream(chatId)')
  Stream<List<MessageModel>> messagesStream(String chatId) {
    return decryptedMessagesStream(chatId);
  }

  @Deprecated('Use sendMessage(groupId, ...)')
  Future<void> sendGroupMessage(String groupId, {
    String? text,
    String? imageUrl,
    String? documentUrl,
    String? documentName,
    String? voiceUrl,
    int? voiceDuration,
  }) {
    return sendMessage(
      groupId,
      text: text,
      imageUrl: imageUrl,
      documentUrl: documentUrl,
      documentName: documentName,
      voiceUrl: voiceUrl,
      voiceDuration: voiceDuration,
    );
  }

  @Deprecated('Use decryptedMessagesStream(groupId)')
  Stream<List<MessageModel>> groupMessagesStream(String groupId) {
    return decryptedMessagesStream(groupId);
  }

  /// Helper method to decrypt a message text if it's encrypted
  String? _decryptMessageText(String? text, String? encKey, String? encIv) {
    if (text == null || text.isEmpty) {
      return text;
    }

    // If no encryption keys, return original text
    if (encKey == null || encIv == null) {
      return text;
    }

    // Check if it's an emoji/icon message (non-text message types)
    // These are stored as plain emoji strings and don't need decryption
    if (text == '📷 Image' || text == '📄 Document' ||
        text == '🎤 Voice message') {
      return text;
    }

    // Try to decrypt - if it fails, return original
    // This handles encrypted text messages
    try {
      return _encryption.decrypt(
        cipherText: text,
        base64Key: encKey,
        base64Iv: encIv,
      );
    } catch (_) {
      // If decryption fails, return original (might be plain text or corrupted)
      return text;
    }
  }

  Stream<List<ChatModel>> userChatsStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return chats
        .where('participantIds', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .asyncMap((snapshot) async {
      final list = <ChatModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final encKey = data['encKey'] as String?;
          final encIv = data['encIv'] as String?;
          final lastMessage = data['lastMessage'] as String? ?? '';

          // Decrypt lastMessage if it's encrypted text
          final decryptedLastMessage = _decryptMessageText(
              lastMessage, encKey, encIv) ?? '';

          // Create modified data with decrypted lastMessage
          final modifiedData = Map<String, dynamic>.from(data);
          modifiedData['lastMessage'] = decryptedLastMessage;

          final chat = ChatModel.fromMap(doc.id, modifiedData);
          if (chat.lastMessage.isNotEmpty) {
            list.add(chat);
          }
        } catch (e) {
          if (kDebugMode) print('Error parsing chat ${doc.id}: $e');
        }
      }

      // Sort by last message time (most recent first)
      list.sort((a, b) => b.lastMessageTime.compareTo(a.lastMessageTime));
      return list;
    }).handleError((error) {
      if (kDebugMode) print('Error in userChatsStream: $error');
      return <ChatModel>[];
    });
  }

  Future<void> editMessage({
    required String chatId,
    required String messageId,
    required String newText,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('User not authenticated');

    final isGroupChat = await _isGroupChat(chatId);
    final parentCollection = isGroupChat ? groups : chats;
    final parentDoc = parentCollection.doc(chatId);

    final parentSnap = await parentDoc.get();
    if (!parentSnap.exists) throw Exception('Chat/Group not found');

    // Verify the user owns the message
    final messageDoc = await parentDoc
        .collection('messages')
        .doc(messageId)
        .get();
    if (!messageDoc.exists) throw Exception('Message not found');

    final messageData = messageDoc.data()!;
    final messageSenderId = messageData['senderId'] as String?;
    if (messageSenderId != userId) {
      throw Exception('You can only edit your own messages');
    }

    final data = parentSnap.data()!;
    final encKey = data['encKey'] as String?;
    final encIv = data['encIv'] as String?;
    if (encKey == null || encIv == null) {
      throw Exception('Encryption key missing');
    }

    final encryptedText = _encryption.encrypt(
      plainText: newText.trim(),
      base64Key: encKey,
      base64Iv: encIv,
    );

    await parentDoc.collection('messages').doc(messageId).update({
      'text': encryptedText,
      'encrypted': true,
    });

    await parentDoc.update({
      'lastMessage': encryptedText,
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
  }

  Future<bool> _isGroupChat(String chatId) async {
    final groupSnap = await groups.doc(chatId).get();
    if (groupSnap.exists) return true;

    // If not a group, verify it's a valid chat and return false
    final chatSnap = await chats.doc(chatId).get();
    if (!chatSnap.exists) {
      throw Exception('Chat or group not found');
    }

    return false;  // ✅ It's a one-to-one chat, not a group
  }

// Alternative optimized version that checks both simultaneously:

  // Future<bool> _isGroupChat(String chatId) async {
  //   // Check both collections in parallel
  //   final results = await Future.wait([
  //     groups.doc(chatId).get(),
  //     chats.doc(chatId).get(),
  //   ]);
  //
  //   final groupSnap = results[0];
  //   final chatSnap = results[1];
  //
  //   if (groupSnap.exists) return true;
  //   if (chatSnap.exists) return false;
  //
  //   throw Exception('Chat or group not found');
  // }

  Future<void> createOrUpdateUser(String userId,
      String displayName, {
        String? avatarUrl,
        String? bio,
        String? email,
        bool? notificationsEnabled,
        String? fcmToken,
      }) async {
    final data = <String, dynamic>{
      'displayName': displayName,
      'lastSeen': FieldValue.serverTimestamp(),
    };

    if (avatarUrl != null) data['avatarUrl'] = avatarUrl;
    if (bio != null) data['bio'] = bio;
    if (email != null) data['email'] = email;
    if (notificationsEnabled != null) {
      data['notificationsEnabled'] = notificationsEnabled;
    }
    if (fcmToken != null) {
      data['fcmToken'] = fcmToken;
      data['tokenUpdatedAt'] = FieldValue.serverTimestamp();
    }

    await users.doc(userId).set(data, SetOptions(merge: true));
  }

  Future<String> createGroup({
    required String name,
    required List<String> memberIds,
    String? avatarUrl,
    String? description,
  }) async {
    final userId = currentUserId;
    if (userId == null) throw Exception('Not authenticated');

    final enc = EncryptionService.generateChatKey();

    final ref = await groups.add({
      'name': name,
      'avatarUrl': avatarUrl,
      'description': description,
      'memberIds': {...memberIds, userId}.toList(),
      'adminIds': [userId],
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'lastMessageTime': FieldValue.serverTimestamp(),
      'encrypted': true,
      'encKey': enc['key'],
      'encIv': enc['iv'],
    });

    return ref.id;
  }

  Stream<List<GroupModel>> userGroupsStream() {
    final userId = currentUserId;
    if (userId == null) return const Stream.empty();

    return groups
        .where('memberIds', arrayContains: userId)
        .snapshots()
        .asyncMap((snapshot) async {
      final list = <GroupModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          final encKey = data['encKey'] as String?;
          final encIv = data['encIv'] as String?;
          final lastMessage = data['lastMessage'] as String? ?? '';

          // Decrypt lastMessage if it's encrypted text
          final decryptedLastMessage = _decryptMessageText(
              lastMessage, encKey, encIv) ?? '';

          // Create modified data with decrypted lastMessage
          final modifiedData = Map<String, dynamic>.from(data);
          modifiedData['lastMessage'] = decryptedLastMessage;

          list.add(GroupModel.fromMap(doc.id, modifiedData));
        } catch (e) {
          if (kDebugMode) print('Error parsing group ${doc.id}: $e');
        }
      }

      return list;
    });
  }

  Future<AppUser?> getUserById(String userId) async {
    final snap = await users.doc(userId).get();
    if (!snap.exists) return null;
    return AppUser.fromMap({...snap.data()!, 'id': userId});
  }

  /// Mark messages as seen when user opens the chat
  Future<void> markMessagesAsSeen(String chatId) async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final isGroup = await _isGroupChat(chatId);
      final parentCollection = isGroup ? groups : chats;

      // Get group/chat data to access memberIds for groups
      final parentDoc = await parentCollection.doc(chatId).get();
      if (!parentDoc.exists) return;
      
      final parentData = parentDoc.data()!;
      List<String>? memberIds;
      if (isGroup) {
        memberIds = List<String>.from(parentData['memberIds'] ?? []);
      }

      // Get all recent messages (we'll filter client-side to avoid Firestore query limitations)
      final messagesSnapshot = await parentCollection
          .doc(chatId)
          .collection('messages')
          .orderBy('sentAt', descending: true)
          .limit(100) // Get last 100 messages
          .get();

      // Filter messages that need to be marked as seen (client-side filtering)
      final messagesToUpdate = messagesSnapshot.docs.where((doc) {
        final data = doc.data();
        final senderId = data['senderId'] as String?;
        final status = data['status'] as String?;

        // Skip messages sent by current user
        if (senderId == userId) return false;

        // Skip messages already marked as seen
        if (status == 'seen') return false;

        // For groups, check if this user has already seen it
        if (isGroup) {
          final seenBy = data['seenBy'] as Map<String, dynamic>?;
          if (seenBy?.containsKey(userId) == true) return false;
        }

        return true; // Message needs to be marked as seen
      }).toList();

      // Always reset unread count, even if no messages to update
      final batch = _firestore.batch();

      if (messagesToUpdate.isNotEmpty) {
        final now = FieldValue.serverTimestamp();

        for (var doc in messagesToUpdate) {
          final data = doc.data();
          final senderId = data['senderId'] as String?;

          if (isGroup && memberIds != null) {
            // For groups: add user to seenBy map
            final seenBy = Map<String, dynamic>.from(data['seenBy'] as Map? ?? {});
            seenBy[userId] = now;
            
            // Check if all members (except sender) have seen the message
            final otherMembers = memberIds.where((id) => id != senderId).toList();
            final allSeen = otherMembers.every((memberId) => seenBy.containsKey(memberId));
            
            // Update seenBy and status (only set to 'seen' if all members have seen it)
            final updateData = <String, dynamic>{
              'seenBy.$userId': now,
            };
            
            if (allSeen) {
              updateData['status'] = 'seen';
            }
            
            batch.update(doc.reference, updateData);
          } else {
            // For 1-on-1 chats: mark as seen immediately (recipient has read it)
            batch.update(doc.reference, {
              'status': 'seen',
            });
          }
        }
      }

      // Reset unread count atomically (most important part!)
      batch.update(parentCollection.doc(chatId), {
        'unreadCounts.$userId': 0,
      });

      await batch.commit();

      if (kDebugMode) {
        print('✅ Marked ${messagesToUpdate.length} messages as seen for chat: $chatId');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error marking messages as seen: $e');

      // Fallback: just reset unread count (this is critical!)
      try {
        final isGroup = await _isGroupChat(chatId);
        final parentCollection = isGroup ? groups : chats;
        await parentCollection.doc(chatId).update({
          'unreadCounts.$userId': 0,
        });
        if (kDebugMode) print('✅ Fallback: Reset unread count to 0');
      } catch (fallbackError) {
        if (kDebugMode) print('❌ Fallback also failed: $fallbackError');
      }
    }
  }

  /// Mark a specific message as delivered (called when message is received)
  Future<void> markMessageAsDelivered(String chatId, String messageId) async {
    try {
      final isGroup = await _isGroupChat(chatId);
      final parentCollection = isGroup ? groups : chats;

      await parentCollection
          .doc(chatId)
          .collection('messages')
          .doc(messageId)
          .update({'status': 'delivered'});
    } catch (e) {
      if (kDebugMode) print('Error marking message as delivered: $e');
    }
  }
}