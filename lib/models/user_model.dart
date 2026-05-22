import 'package:cloud_firestore/cloud_firestore.dart';

class AppUser {
  final String id;
  final String displayName;
  final String? avatarUrl;
  final String? bio;
  final String? email;
  final bool isOnline;
  final DateTime? lastSeen;
  final bool notificationsEnabled; // ← Added for Settings page
  final String? fcmToken; // ← Optional: useful for debugging or future features

  AppUser({
    required this.id,
    required this.displayName,
    this.avatarUrl,
    this.bio,
    this.email,
    this.isOnline = false,
    this.lastSeen,
    this.notificationsEnabled = true, // Default: notifications ON
    this.fcmToken,
  });

  factory AppUser.fromMap(Map<String, dynamic> map, {String? id}) {
    return AppUser(
      id: id ?? map['id'] as String,
      displayName: map['displayName'] as String? ?? 'User',
      avatarUrl: map['avatarUrl'] as String?,
      bio: map['bio'] as String?,
      email: map['email'] as String?,
      isOnline: map['isOnline'] as bool? ?? false,
      lastSeen: map['lastSeen'] != null
          ? (map['lastSeen'] as Timestamp).toDate()
          : null,
      notificationsEnabled: map['notificationsEnabled'] as bool? ?? true,
      fcmToken: map['fcmToken'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'displayName': displayName,
      'avatarUrl': avatarUrl,
      'bio': bio,
      'email': email,
      'isOnline': isOnline,
      'lastSeen': lastSeen,
      'notificationsEnabled': notificationsEnabled,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  // Optional: Helpful for copying with modifications
  AppUser copyWith({
    String? id,
    String? displayName,
    String? avatarUrl,
    String? bio,
    String? email,
    bool? isOnline,
    DateTime? lastSeen,
    bool? notificationsEnabled,
    String? fcmToken,
  }) {
    return AppUser(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      email: email ?? this.email,
      isOnline: isOnline ?? this.isOnline,
      lastSeen: lastSeen ?? this.lastSeen,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}