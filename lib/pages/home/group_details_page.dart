import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/models/group_model.dart';
import 'package:chatify_final_project/models/user_model.dart';

class GroupDetailsPage extends StatefulWidget {
  final String groupId;

  const GroupDetailsPage({
    required this.groupId,
    super.key,
  });

  @override
  State<GroupDetailsPage> createState() => _GroupDetailsPageState();
}

class _GroupDetailsPageState extends State<GroupDetailsPage> {
  final ChatService chatService = Get.find<ChatService>();
  late Stream<GroupModel?> groupStream;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    currentUserId = chatService.currentUserId;
    groupStream = _getGroupStream();
  }

  Stream<GroupModel?> _getGroupStream() {
    return chatService.groups.doc(widget.groupId).snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return GroupModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  Future<void> _leaveGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Leave', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await chatService.leaveGroup(widget.groupId);
        Get.offAllNamed(AppRoutes.chats);
        Get.snackbar('Left Group', 'You have left the group', backgroundColor: Colors.green, colorText: Colors.white);
      } catch (e) {
        Get.snackbar('Error', 'Failed to leave group', backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('This will permanently delete the group and all messages. This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await chatService.deleteGroup(widget.groupId);
        Get.offAllNamed(AppRoutes.chats);
        Get.snackbar('Deleted', 'Group has been deleted', backgroundColor: Colors.green, colorText: Colors.white);
      } catch (e) {
        Get.snackbar('Error', 'Failed to delete group', backgroundColor: Colors.red, colorText: Colors.white);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Info'),
        centerTitle: true,
      ),
      body: StreamBuilder<GroupModel?>(
        stream: groupStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text('Group not found'));
          }

          final group = snapshot.data!;
          final isAdmin = group.isAdmin(currentUserId ?? '');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Group Avatar
                CircleAvatar(
                  radius: 64,
                  backgroundColor: AppColors.gradientEnd.withOpacity(0.2),
                  backgroundImage: group.avatarUrl != null ? NetworkImage(group.avatarUrl!) : null,
                  child: group.avatarUrl == null
                      ? Icon(Icons.group, size: 70, color: AppColors.gradientEnd)
                      : null,
                ),
                const SizedBox(height: 24),

                // Group Name
                Text(
                  group.name,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Member Count Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.gradientEnd.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${group.memberIds.length} members',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.gradientEnd,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Description
                if (group.description != null && group.description!.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Description', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Text(group.description!, style: const TextStyle(fontSize: 15)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Members List
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Members', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                          Text('${group.memberIds.length}', style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ...group.memberIds.map((memberId) {
                        return StreamBuilder<AppUser?>(
                          stream: chatService.getUserById(memberId).asStream(),
                          builder: (context, userSnapshot) {
                            final user = userSnapshot.data;
                            if (user == null) {
                              return const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: Text('Loading...'),
                              );
                            }

                            final isThisAdmin = group.adminIds.contains(memberId);

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                                    child: user.avatarUrl == null ? const Icon(Icons.person, size: 22) : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  ),
                                  if (isThisAdmin)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: AppColors.gradientEnd.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        'Admin',
                                        style: TextStyle(fontSize: 11, color: AppColors.gradientEnd, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Leave Group Button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _leaveGroup,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Leave Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),

                // Delete Group Button (Admin only)
                if (isAdmin) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _deleteGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Delete Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}