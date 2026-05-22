import 'package:cloud_firestore/cloud_firestore.dart';

class GroupModel {
  final String id;
  final String name;
  final String? avatarUrl;
  final String? description;
  final List<String> memberIds;
  final List<String> adminIds;
  final String createdBy;
  final DateTime createdAt;
  final String lastMessage;
  final DateTime lastMessageTime;

  GroupModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.description,
    required this.memberIds,
    required this.adminIds,
    required this.createdBy,
    required this.createdAt,
    required this.lastMessage,
    required this.lastMessageTime,
  });

  factory GroupModel.fromMap(String id, Map<String, dynamic> map) {
    return GroupModel(
      id: id,
      name: map['name'] as String? ?? 'Group',
      avatarUrl: map['avatarUrl'] as String?,
      description: map['description'] as String?,
      memberIds: List<String>.from(map['memberIds'] as List? ?? []),
      adminIds: List<String>.from(map['adminIds'] as List? ?? []),
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] != null
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      lastMessage: map['lastMessage'] as String? ?? '',
      lastMessageTime: map['lastMessageTime'] != null
          ? (map['lastMessageTime'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatarUrl': avatarUrl,
      'description': description,
      'memberIds': memberIds,
      'adminIds': adminIds,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
    };
  }

  bool isAdmin(String userId) => adminIds.contains(userId);
  bool isMember(String userId) => memberIds.contains(userId);
}

