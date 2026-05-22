import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/pages/home/create_group_page.dart';
import 'package:chatify_final_project/models/user_model.dart';
import 'package:chatify_final_project/models/chat_model.dart';
import 'package:chatify_final_project/models/group_model.dart';

import '../../services/presence_service.dart'; // ← Added this

class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage> {
  late TextEditingController searchCtrl;
  int _selectedTab = 0; // 0 = Chats, 1 = Groups

  @override
  void initState() {
    super.initState();
    searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Get.find<ChatService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chatify'),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(AppRoutes.newChat),
            icon: const Icon(Icons.search),
          ),
          PopupMenuButton(
            itemBuilder: (context) => [
              PopupMenuItem(
                child: const Text('New Group'),
                onTap: () => Get.to(() => const CreateGroupPage()),
              ),
              PopupMenuItem(
                child: const Text('Profile'),
                onTap: () => Get.toNamed(AppRoutes.profile),
              ),
              PopupMenuItem(
                child: const Text('Settings'),
                onTap: () => Get.toNamed(AppRoutes.settings),
              ),
               PopupMenuItem(
            child: const Text('Logout'),
    onTap: () async {
    final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
    title: const Text('Logout'),
    content: const Text('Are you sure you want to logout?'),
    actions: [
    TextButton(
    onPressed: () => Navigator.pop(context, false),
    child: const Text('Cancel'),
    ),
    TextButton(
    onPressed: () => Navigator.pop(context, true),
    child: const Text('Logout', style: TextStyle(color: Colors.red)),
    ),
    ],
    ),
    );

    if (confirmed == true) {
    final presenceService = Get.find<PresenceService>();
    await presenceService.disconnect();

    final authService = Get.find<AuthService>();
    await authService.signOut();
    Get.offAllNamed(AppRoutes.login);
    }
    },
    ),
            ],
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedTab == 0 ? AppColors.gradientEnd : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      'Chats',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: _selectedTab == 0 ? FontWeight.w700 : FontWeight.normal,
                        color: _selectedTab == 0 ? AppColors.gradientEnd : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _selectedTab = 1),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: _selectedTab == 1 ? AppColors.gradientEnd : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Text(
                      'Groups',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: _selectedTab == 1 ? FontWeight.w700 : FontWeight.normal,
                        color: _selectedTab == 1 ? AppColors.gradientEnd : Colors.grey,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: _selectedTab == 0 ? _buildChatsTab(chatService) : _buildGroupsTab(chatService),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          if (_selectedTab == 0) {
            Get.toNamed(AppRoutes.newChat);
          } else {
            Get.to(() => const CreateGroupPage());
          }
        },
        child: Icon(_selectedTab == 0 ? Icons.chat : Icons.group_add),
      ),
    );
  }

  Widget _buildChatsTab(ChatService chatService) {
    return StreamBuilder<List<ChatModel>>(
      stream: chatService.userChatsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No chats yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Start a conversation!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          );
        }

        final chats = snapshot.data!;

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final chat = chats[index];
            final currentUserId = chatService.currentUserId;
            final otherUserId = chat.participantIds.firstWhere(
                  (id) => id != currentUserId,
              orElse: () => '',
            );

            if (otherUserId.isEmpty) return const SizedBox.shrink();

            return StreamBuilder<AppUser?>(
              stream: chatService.userStream(otherUserId),
              builder: (context, userSnapshot) {
                final otherUser = userSnapshot.data;
                final displayName = otherUser?.displayName ?? 'User';
                final avatarUrl = otherUser?.avatarUrl;

                final unreadCount = chat.unreadCounts[currentUserId] ?? 0;
                final hasUnread = unreadCount > 0;

                return ListTile(
                  tileColor: hasUnread ? AppColors.gradientEnd.withOpacity(0.05) : null,
                  leading: CircleAvatar(
                    radius: 24,
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null ? const Icon(Icons.person) : null,
                  ),
                  title: Text(
                    displayName,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.w900 : FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    chat.lastMessage,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _formatTime(chat.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: hasUnread ? FontWeight.w700 : FontWeight.normal,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (hasUnread)
                        CircleAvatar(
                          radius: 10,
                          backgroundColor: AppColors.unreadBadge,
                          child: Text(
                            unreadCount > 99 ? '99+' : '$unreadCount',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  onTap: () => Get.toNamed(
                    AppRoutes.chat,
                    arguments: {
                      'chatId': chat.id,
                      'contact': displayName,
                      'otherUserId': otherUserId,
                      'isGroup': false,
                    },
                  ),
                  onLongPress: () {
                    // Optional: Add long-press actions (e.g. archive, mute)
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildGroupsTab(ChatService chatService) {
    return StreamBuilder<List<GroupModel>>(
      stream: chatService.userGroupsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.group_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text('No groups yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                const SizedBox(height: 8),
                Text('Create a group to chat with multiple people!', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
              ],
            ),
          );
        }

        final groups = snapshot.data!;

        return ListView.separated(
          itemCount: groups.length,
          separatorBuilder: (_, __) => const Divider(height: 0),
          itemBuilder: (context, index) {
            final group = groups[index];
            final memberCount = group.memberIds.length;

            return ListTile(
              leading: CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.gradientEnd.withOpacity(0.2),
                backgroundImage: group.avatarUrl != null ? NetworkImage(group.avatarUrl!) : null,
                child: group.avatarUrl == null
                    ? const Icon(Icons.group, color: AppColors.gradientEnd)
                    : null,
              ),
              title: Text(
                group.name,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              subtitle: Text(
                group.lastMessage.isEmpty
                    ? '$memberCount members'
                    : group.lastMessage,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                _formatTime(group.lastMessageTime),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () => Get.toNamed(
                AppRoutes.chat,
                arguments: {
                  'chatId': group.id,
                  'contact': group.name,
                  'isGroup': true,
                },
              ),
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) return 'now';
    if (difference.inHours < 1) return '${difference.inMinutes}m';
    if (difference.inDays < 1) return '${difference.inHours}h';
    if (difference.inDays == 1) return 'yesterday';
    if (difference.inDays < 7) return '${difference.inDays}d';
    return '${dateTime.month}/${dateTime.day}';
  }
}