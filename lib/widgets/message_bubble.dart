import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/models/user_model.dart';
import 'package:chatify_final_project/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final String text;
  final bool isMe;
  final String? time;
  final String messageId;
  final String chatId;
  final AppUser? sender; // New: sender for group messages (null in 1-on-1 or for own messages)
  final MessageStatus? status; // Message status (sent/delivered/seen)

  const MessageBubble({
    super.key,
    required this.text,
    required this.isMe,
    this.time,
    required this.messageId,
    required this.chatId,
    this.sender,
    this.status,
  });

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: text);
    final chatService = Get.find<ChatService>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Message'),
        content: TextField(
          controller: controller,
          maxLines: null,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'Type your message...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final newText = controller.text.trim();
              if (newText.isEmpty) {
                Get.snackbar('Error', 'Message cannot be empty');
                return;
              }
              if (newText == text) {
                Get.back();
                return;
              }

              try {
                await chatService.editMessage(
                  chatId: chatId,
                  messageId: messageId,
                  newText: newText,
                );
                Get.back();
                Get.snackbar('Edited', 'Message updated', duration: const Duration(seconds: 1));
              } catch (e) {
                Get.snackbar('Error', 'Failed to edit message', backgroundColor: Colors.red);
              }
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final chatService = Get.find<ChatService>();

    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await chatService.deleteMessage(
                  chatId: chatId,
                  messageId: messageId,
                );
                Get.snackbar('Deleted', 'Message removed', duration: const Duration(seconds: 1));
              } catch (e) {
                Get.snackbar('Error', 'Failed to delete message', backgroundColor: Colors.red);
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final showSenderInfo = sender != null; // Only show if sender is provided (group + not me)

    void _showMessageOptions(BuildContext context) {
      if (!isMe) return;
      
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Edit Message'),
                onTap: () {
                  Get.back();
                  _showEditDialog(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Message'),
                onTap: () {
                  Get.back();
                  _confirmDelete(context);
                },
              ),
              const Divider(height: 0),
              ListTile(
                title: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                onTap: () => Get.back(),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onLongPress: isMe ? () => _showMessageOptions(context) : null,
      onSecondaryTap: isMe ? () => _showMessageOptions(context) : null,
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender info (DP + name) for group messages from others
          if (showSenderInfo)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: sender!.avatarUrl != null ? NetworkImage(sender!.avatarUrl!) : null,
                    child: sender!.avatarUrl == null
                        ? Text(
                      sender!.displayName[0].toUpperCase(),
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sender!.displayName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gradientEnd,
                    ),
                  ),
                ],
              ),
            ),
          // Message bubble
          Container(
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              gradient: isMe
                  ? const LinearGradient(
                colors: [AppColors.gradientStart, AppColors.gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : null,
              color: isMe ? null : const Color(0xFFF1F1F1),
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              text,
              style: TextStyle(
                color: isMe ? Colors.white : Colors.black87,
                fontSize: 15.5,
                height: 1.4,
              ),
            ),
          ),
          // Time and status
          Padding(
            padding: EdgeInsets.only(
              left: isMe ? 0 : 16,
              right: isMe ? 16 : 0,
              bottom: 4,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: [
                if (time != null)
                  Text(
                    time!,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  _buildStatusIcon(status ?? MessageStatus.sent),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color;

    switch (status) {
      case MessageStatus.sent:
        icon = Icons.check;
        color = Colors.grey[600]!;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey[600]!;
        break;
      case MessageStatus.seen:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
    }

    return Icon(
      icon,
      size: 14,
      color: color,
    );
  }
}