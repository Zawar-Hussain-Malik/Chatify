import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool isUploadingPhoto = false;
  bool isLoadingNotifications = true;
  bool notificationsEnabled = true;

  String? profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadNotificationStatus();
  }

  Future<void> _loadUserData() async {
    final authService = Get.find<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    try {
      final chatService = Get.find<ChatService>();
      final user = await chatService.getUserById(currentUser.uid);

      if (mounted && user != null) {
        setState(() {
          profilePhotoUrl = user.avatarUrl;
        });
      }
    } catch (e) {
      print('Error loading profile photo: $e');
    }
  }

  Future<void> _loadNotificationStatus() async {
    final authService = Get.find<AuthService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) {
      setState(() => isLoadingNotifications = false);
      return;
    }

    try {
      final chatService = Get.find<ChatService>();
      final user = await chatService.getUserById(userId);

      if (mounted) {
        setState(() {
          notificationsEnabled = user?.notificationsEnabled ?? true;
          isLoadingNotifications = false;
        });
      }
    } catch (e) {
      print('Error loading notifications setting: $e');
      if (mounted) {
        setState(() => isLoadingNotifications = false);
      }
    }
  }

  Future<void> _toggleNotifications(bool enabled) async {
    final authService = Get.find<AuthService>();
    final userId = authService.currentUser?.uid;
    if (userId == null) return;

    setState(() {
      notificationsEnabled = enabled;
    });

    try {
      final chatService = Get.find<ChatService>();

      if (enabled) {
        final token = await FirebaseMessaging.instance.getToken();
        await chatService.createOrUpdateUser(
          userId,
          authService.currentUser?.displayName ?? 'User',
          notificationsEnabled: true,
          fcmToken: token,
        );
      } else {
        await chatService.createOrUpdateUser(
          userId,
          authService.currentUser?.displayName ?? 'User',
          notificationsEnabled: false,
          fcmToken: null,
        );
      }

      Get.snackbar(
        'Success',
        enabled ? 'Notifications enabled' : 'Notifications disabled',
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      // Revert on failure
      if (mounted) {
        setState(() => notificationsEnabled = !enabled);
      }
      Get.snackbar('Error', 'Failed to update notifications');
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (pickedFile == null) return;

      setState(() => isUploadingPhoto = true);

      try {
        final cloudinary = Get.find<CloudinaryService>();
        final url = await cloudinary.uploadFile(
          pickedFile.path,
          folder: 'profile_photos',
        );

        final authService = Get.find<AuthService>();
        final chatService = Get.find<ChatService>();
        final userId = authService.currentUser?.uid;

        if (userId != null) {
          await chatService.createOrUpdateUser(
            userId,
            authService.currentUser?.displayName ?? 'User',
            avatarUrl: url,
          );

          if (mounted) {
            setState(() {
              profilePhotoUrl = url;
            });
            Get.snackbar('Success', 'Profile photo updated!');
          }
        }
      } catch (e) {
        Get.snackbar('Error', 'Failed to upload photo');
      } finally {
        if (mounted) {
          setState(() => isUploadingPhoto = false);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick image');
    }
  }

  Future<void> _deleteProfilePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Photo?'),
        content: const Text('This will remove your profile picture from all chats.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final authService = Get.find<AuthService>();
      final chatService = Get.find<ChatService>();
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        await chatService.createOrUpdateUser(
          userId,
          authService.currentUser?.displayName ?? 'User',
          avatarUrl: null,
        );

        if (mounted) {
          setState(() {
            profilePhotoUrl = null;
          });
          Get.snackbar('Success', 'Profile photo removed');
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to remove photo');
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settings'), centerTitle: true),
        body: const Center(child: Text('Please log in to access settings')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Profile Photo Section
            const Text('Profile Photo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 70,
                    backgroundColor: AppColors.gradientEnd.withOpacity(0.15),
                    backgroundImage: profilePhotoUrl != null ? NetworkImage(profilePhotoUrl!) : null,
                    child: profilePhotoUrl == null
                        ? const Icon(Icons.person, size: 80, color: Colors.grey)
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: isUploadingPhoto ? null : _pickAndUploadPhoto,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.gradientEnd,
                        ),
                        child: isUploadingPhoto
                            ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                            : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (profilePhotoUrl != null)
              Center(
                child: OutlinedButton.icon(
                  onPressed: _deleteProfilePhoto,
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  label: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                ),
              ),
            const SizedBox(height: 40),

            // App Settings
            const Text('App Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // Push Notifications
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Push Notifications', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Get notified when you receive new messages', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  if (isLoadingNotifications)
                    const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    Switch(
                      value: notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: AppColors.gradientEnd,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Privacy (Placeholder)
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Privacy & Security', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Manage who can message you', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Get.snackbar('Coming Soon', 'Privacy settings are under development'),
                    icon: const Icon(Icons.arrow_forward_ios, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // About
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('About Chatify', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        SizedBox(height: 4),
                        Text('Version 1.0.0 • End-to-end encrypted', style: TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Get.dialog(
                        AlertDialog(
                          title: const Text('Chatify'),
                          content: const Text('Version 1.0.0\n\nA secure, real-time messaging app with end-to-end encryption.'),
                          actions: [TextButton(onPressed: Get.back, child: const Text('OK'))],
                        ),
                      );
                    },
                    icon: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}