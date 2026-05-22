import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/models/user_model.dart';


/// Small dialog shown when tapping a user's name in chat list
class UserDetailsDialog extends StatelessWidget {
  final String userId;
  final String? userName;

  const UserDetailsDialog({
    required this.userId,
    this.userName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chatService = Get.find<ChatService>();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: FutureBuilder<AppUser?>(
        future: chatService.getUserById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final user = snapshot.data;
          if (user == null) {
            return SizedBox(
              height: 250,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('User not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Get.back(),
                    child: const Text('Close'),
                  ),
                ],
              ),
            );
          }

          return Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Close button
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.close),
                    padding: EdgeInsets.zero,
                  ),
                ),

                // Avatar
                CircleAvatar(
                  radius: 60,
                  backgroundColor: AppColors.gradientEnd.withOpacity(0.15),
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 70, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 20),

                // Name
                Text(
                  user.displayName,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Bio
                if (user.bio != null && user.bio!.trim().isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Bio', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                        const SizedBox(height: 6),
                        Text(user.bio!.trim(), style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          Get.back();
                          try {
                            final chatId = await chatService.getOrCreateChat(userId);
                            Get.toNamed('/chat', arguments: {
                              'chatId': chatId,
                              'contact': user.displayName,
                              'otherUserId': userId,
                              'isGroup': false,
                            });
                          } catch (e) {
                            Get.snackbar('Error', 'Could not start chat');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.gradientEnd,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Send Message', style: TextStyle(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          Get.back();
                          Get.snackbar('Coming Soon', 'Block user feature in development');
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Block', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Full-screen user details page (used from other places)
class UserDetailsPage extends StatelessWidget {
  final String userId;

  const UserDetailsPage({
    required this.userId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final chatService = Get.find<ChatService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Details'),
        centerTitle: true,
      ),
      body: FutureBuilder<AppUser?>(
        future: chatService.getUserById(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final user = snapshot.data;
          if (user == null) {
            return const Center(child: Text('User not found'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 80,
                  backgroundColor: AppColors.gradientEnd.withOpacity(0.15),
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null
                      ? const Icon(Icons.person, size: 100, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 32),

                // Name
                Text(
                  user.displayName,
                  style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Info Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _infoRow(Icons.person_outline, 'Display Name', user.displayName),
                      if (user.email != null) ...[
                        const SizedBox(height: 16),
                        _infoRow(Icons.email_outlined, 'Email', user.email!),
                      ],
                      if (user.bio != null && user.bio!.trim().isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _infoRow(Icons.info_outline, 'Bio', user.bio!.trim(), isMultiline: true),
                      ],
                      const SizedBox(height: 16),
                      _infoRow(Icons.fingerprint, 'User ID', userId, isMonospace: true),
                    ],
                  ),
                ),
                const SizedBox(height: 40),

                // Actions
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        final chatId = await chatService.getOrCreateChat(userId);
                        Get.offNamed('/chat', arguments: {
                          'chatId': chatId,
                          'contact': user.displayName,
                          'otherUserId': userId,
                          'isGroup': false,
                        });
                      } catch (e) {
                        Get.snackbar('Error', 'Could not start chat');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gradientEnd,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Send Message', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Get.snackbar('Coming Soon', 'Block user feature in development'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      side: const BorderSide(color: Colors.red),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Block User', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value, {bool isMultiline = false, bool isMonospace = false}) {
    return Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey[600], size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  fontFamily: isMonospace ? 'monospace' : null,
                ),
                maxLines: isMultiline ? 5 : 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}