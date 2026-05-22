import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageStatus { sent, delivered, seen }

class MessageModel {
  final String id;
  final String senderId;
  final String text;
  final String? imageUrl;
  final String? documentUrl;
  final String? documentName;
  final String? voiceUrl;
  final int? voiceDuration;
  final DateTime sentAt;
  final MessageStatus status;
  final Map<String, DateTime>? seenBy; // userId -> timestamp (for group chats)

  MessageModel({
    required this.id,
    required this.senderId,
    required this.text,
    this.imageUrl,
    this.documentUrl,
    this.documentName,
    this.voiceUrl,
    this.voiceDuration,
    required this.sentAt,
    this.status = MessageStatus.sent,
    this.seenBy,
  });

  MessageModel copyWith({
    String? id,
    String? senderId,
    String? text,
    String? imageUrl,
    String? documentUrl,
    String? documentName,
    String? voiceUrl,
    int? voiceDuration,
    DateTime? sentAt,
    MessageStatus? status,
    Map<String, DateTime>? seenBy,
  }) {
    return MessageModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      documentUrl: documentUrl ?? this.documentUrl,
      documentName: documentName ?? this.documentName,
      voiceUrl: voiceUrl ?? this.voiceUrl,
      voiceDuration: voiceDuration ?? this.voiceDuration,
      sentAt: sentAt ?? this.sentAt,
      status: status ?? this.status,
      seenBy: seenBy ?? this.seenBy,
    );
  }

  factory MessageModel.fromMap(String id, Map<String, dynamic> map) {
    MessageStatus status = MessageStatus.sent;
    final statusStr = map['status'] as String?;
    if (statusStr == 'delivered') {
      status = MessageStatus.delivered;
    } else if (statusStr == 'seen') {
      status = MessageStatus.seen;
    }

    Map<String, DateTime>? seenBy;
    if (map['seenBy'] != null && map['seenBy'] is Map) {
      seenBy = {};
      final seenByMap = map['seenBy'] as Map;
      seenByMap.forEach((key, value) {
        if (value is Timestamp) {
          seenBy![key.toString()] = value.toDate();
        }
      });
    }

    return MessageModel(
      id: id,
      senderId: map['senderId'] as String? ?? '',
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String?,
      documentUrl: map['documentUrl'] as String?,
      documentName: map['documentName'] as String?,
      voiceUrl: map['voiceUrl'] as String?,
      voiceDuration: map['voiceDuration'] as int?,
      sentAt: map['sentAt'] != null
          ? (map['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      status: status,
      seenBy: seenBy,
    );
  }

  Map<String, dynamic> toMap() {
    String statusStr = 'sent';
    if (status == MessageStatus.delivered) {
      statusStr = 'delivered';
    } else if (status == MessageStatus.seen) {
      statusStr = 'seen';
    }

    final map = {
      'senderId': senderId,
      'text': text,
      'imageUrl': imageUrl,
      'documentUrl': documentUrl,
      'documentName': documentName,
      'voiceUrl': voiceUrl,
      'voiceDuration': voiceDuration,
      'sentAt': sentAt,
      'status': statusStr,
    };

    if (seenBy != null) {
      final seenByMap = <String, Timestamp>{};
      seenBy!.forEach((key, value) {
        seenByMap[key] = Timestamp.fromDate(value);
      });
      map['seenBy'] = seenByMap;
    }

    return map;
  }

  bool get hasImage => imageUrl != null && imageUrl!.isNotEmpty;
  bool get hasDocument => documentUrl != null && documentUrl!.isNotEmpty;
  bool get hasVoice => voiceUrl != null && voiceUrl!.isNotEmpty;
  bool get isTextOnly => !hasImage && !hasDocument && !hasVoice && text.isNotEmpty;
}
