import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:chatify_final_project/app/theme.dart';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';
import 'package:chatify_final_project/models/user_model.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  late TextEditingController nameCtrl;
  late TextEditingController descriptionCtrl;
  final Set<String> selectedMembers = {};
  File? _selectedImage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    descriptionCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to pick image: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> _createGroup() async {
    final groupName = nameCtrl.text.trim();
    if (groupName.isEmpty) {
      Get.snackbar(
        'Error',
        'Please enter a group name',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    if (selectedMembers.isEmpty) {
      Get.snackbar(
        'Error',
        'Please select at least one member',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final chatService = Get.find<ChatService>();
      final cloudinary = Get.find<CloudinaryService>();

      String? avatarUrl;

      if (_selectedImage != null) {
        try {
          avatarUrl = await cloudinary.uploadFile(
            _selectedImage!.path,
            folder: 'group_avatars',
          );
        } catch (uploadError) {
          print('Image upload failed: $uploadError');
          // Continue without avatar if upload fails
        }
      }

      final groupId = await chatService.createGroup(
        name: groupName,
        memberIds: selectedMembers.toList(),
        avatarUrl: avatarUrl,
        description: descriptionCtrl.text.trim().isEmpty
            ? null
            : descriptionCtrl.text.trim(),
      );

      Get.back(); // Close create group page

      Get.snackbar(
        'Success',
        'Group "$groupName" created successfully!',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );

      // Navigate directly to the new group chat
      Get.toNamed(
        AppRoutes.chat,
        arguments: {
          'chatId': groupId,
          'contact': groupName,
          'isGroup': true,
        },
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to create group: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatService = Get.find<ChatService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Group'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Group Info Section
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: isLoading ? null : _pickImage,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: AppColors.gradientEnd.withOpacity(0.2),
                    backgroundImage:
                    _selectedImage != null ? FileImage(_selectedImage!) : null,
                    child: _selectedImage == null
                        ? Icon(
                      Icons.camera_alt,
                      size: 30,
                      color: AppColors.gradientEnd,
                    )
                        : null,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Group name (required)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !isLoading,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: descriptionCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Description (optional)',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 12,
                          ),
                        ),
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        enabled: !isLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Members Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'Add Members',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${selectedMembers.length} selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: selectedMembers.isEmpty ? Colors.grey : AppColors.gradientEnd,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Users List
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: chatService.allUsersStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Text('No users found'),
                  );
                }

                final users = snapshot.data!;

                return ListView.builder(
                  itemCount: users.length,
                  itemBuilder: (context, index) {
                    final user = users[index];
                    final isSelected = selectedMembers.contains(user.id);

                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: isLoading
                          ? null
                          : (bool? value) {
                        setState(() {
                          if (value == true) {
                            selectedMembers.add(user.id);
                          } else {
                            selectedMembers.remove(user.id);
                          }
                        });
                      },
                      secondary: CircleAvatar(
                        radius: 24,
                        backgroundImage: user.avatarUrl != null
                            ? NetworkImage(user.avatarUrl!)
                            : null,
                        child: user.avatarUrl == null
                            ? const Icon(Icons.person, size: 24)
                            : null,
                      ),
                      title: Text(
                        user.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      activeColor: AppColors.gradientEnd,
                      controlAffinity: ListTileControlAffinity.trailing,
                    );
                  },
                );
              },
            ),
          ),

          // Create Button
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _createGroup,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    backgroundColor: AppColors.gradientEnd,
                    foregroundColor: Colors.white,
                    elevation: 4,
                  ),
                  child: isLoading
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    ),
                  )
                      : const Text(
                    'Create Group',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}