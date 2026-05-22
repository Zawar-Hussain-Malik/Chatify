import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late TextEditingController nameCtrl;
  late TextEditingController bioCtrl;

  bool isEditing = false;
  bool isLoading = false;
  bool isUploadingImage = false;

  String? currentPhotoUrl;
  File? selectedImage;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    bioCtrl = TextEditingController();
    _loadUserProfile();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    final authService = Get.find<AuthService>();
    final currentUser = authService.currentUser;
    if (currentUser == null) return;

    try {
      final chatService = Get.find<ChatService>();
      final user = await chatService.getUserById(currentUser.uid);

      if (mounted && user != null) {
        setState(() {
          nameCtrl.text = user.displayName;
          bioCtrl.text = user.bio ?? '';
          currentPhotoUrl = user.avatarUrl;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );

      if (picked != null && mounted) {
        setState(() {
          selectedImage = File(picked.path);
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image',
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _deleteProfilePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo?'),
        content: const Text('This will remove your profile picture.'),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Get.back(result: true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => isUploadingImage = true);
    try {
      final authService = Get.find<AuthService>();
      final chatService = Get.find<ChatService>();
      final userId = authService.currentUser?.uid;

      if (userId != null) {
        await chatService.createOrUpdateUser(
          userId,
          nameCtrl.text.trim(),
          avatarUrl: null,
          bio: bioCtrl.text.trim(),
        );

        if (mounted) {
          setState(() {
            currentPhotoUrl = null;
            selectedImage = null;
          });
          Get.snackbar('Success', 'Profile photo removed');
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to delete photo');
    } finally {
      if (mounted) setState(() => isUploadingImage = false);
    }
  }

  Future<void> _saveProfile() async {
    if (nameCtrl.text.trim().isEmpty) {
      Get.snackbar('Error', 'Display name cannot be empty');
      return;
    }

    setState(() => isLoading = true);

    try {
      final authService = Get.find<AuthService>();
      final chatService = Get.find<ChatService>();
      final cloudinary = Get.find<CloudinaryService>();
      final userId = authService.currentUser?.uid;

      if (userId == null) {
        Get.snackbar('Error', 'Not authenticated');
        return;
      }

      String? newAvatarUrl = currentPhotoUrl;

      if (selectedImage != null) {
        setState(() => isUploadingImage = true);
        try {
          newAvatarUrl = await cloudinary.uploadFile(
            selectedImage!.path,
            folder: 'profile_pictures',
          );
        } catch (e) {
          Get.snackbar('Upload Failed', 'Could not upload new photo. Saving without it.');
          newAvatarUrl = currentPhotoUrl; // fallback
        }
      }

      await chatService.createOrUpdateUser(
        userId,
        nameCtrl.text.trim(),
        avatarUrl: newAvatarUrl,
        bio: bioCtrl.text.trim().isNotEmpty ? bioCtrl.text.trim() : null,
      );

      if (mounted) {
        setState(() {
          currentPhotoUrl = newAvatarUrl;
          selectedImage = null;
          isEditing = false;
        });
        Get.snackbar('Success', 'Profile updated!', backgroundColor: Colors.green, colorText: Colors.white);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to update profile');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
          isUploadingImage = false;
        });
      }
    }
  }

  void _cancelEditing() {
    setState(() {
      isEditing = false;
      selectedImage = null;
    });
    _loadUserProfile(); // reload original data
  }

  @override
  Widget build(BuildContext context) {
    final authService = Get.find<AuthService>();
    final currentUser = authService.currentUser;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Profile')),
        body: const Center(child: Text('Please log in to view your profile')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        centerTitle: true,
        actions: [
          if (!isEditing)
            IconButton(
              onPressed: () => setState(() => isEditing = true),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Profile Photo
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: AppColors.gradientEnd.withOpacity(0.15),
                  backgroundImage: selectedImage != null
                      ? FileImage(selectedImage!)
                      : (currentPhotoUrl != null ? NetworkImage(currentPhotoUrl!) : null),
                  child: selectedImage == null && currentPhotoUrl == null
                      ? const Icon(Icons.person, size: 80, color: Colors.grey)
                      : null,
                ),
                if (isEditing)
                  GestureDetector(
                    onTap: isUploadingImage ? null : _pickProfileImage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.gradientEnd,
                      ),
                      child: isUploadingImage
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                          : const Icon(Icons.camera_alt, color: Colors.white, size: 24),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 32),

            // Email (non-editable)
            _buildInfoCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: currentUser.email ?? 'Not set',
              editable: false,
            ),
            const SizedBox(height: 16),

            // Display Name
            _buildInfoCard(
              icon: Icons.person_outline,
              label: 'Display Name',
              value: isEditing ? null : nameCtrl.text,
              controller: isEditing ? nameCtrl : null,
              hint: 'Enter your name',
            ),
            const SizedBox(height: 16),

            // Bio
            _buildInfoCard(
              icon: Icons.info_outline,
              label: 'Bio',
              value: isEditing ? null : (bioCtrl.text.isEmpty ? 'No bio added' : bioCtrl.text),
              controller: isEditing ? bioCtrl : null,
              hint: 'Tell us about yourself',
              maxLines: 4,
            ),

            if (isEditing && currentPhotoUrl != null) ...[
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: isUploadingImage ? null : _deleteProfilePhoto,
                icon: isUploadingImage
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Remove Profile Photo', style: TextStyle(color: Colors.red)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.red),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],

            const SizedBox(height: 32),

            // Action Buttons
            if (isEditing) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _cancelEditing,
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: isLoading || isUploadingImage ? null : _saveProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gradientEnd,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isLoading || isUploadingImage
                          ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 40),
            ],

            // Logout Button
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to log out?'),
                    actions: [
                      TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
                      TextButton(
                        onPressed: () => Get.back(result: true),
                        child: const Text('Logout', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await authService.signOut();
                  Get.offAllNamed('/login'); // Adjust route as needed
                }
              },
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text('Logout', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    String? value,
    TextEditingController? controller,
    String? hint,
    int maxLines = 1,
    bool editable = true,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.grey[600], size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                const SizedBox(height: 8),
                if (!isEditing || controller == null)
                  Text(
                    value ?? 'Not set',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  )
                else
                  TextField(
                    controller: controller,
                    maxLines: maxLines,
                    decoration: InputDecoration(
                      hintText: hint,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}