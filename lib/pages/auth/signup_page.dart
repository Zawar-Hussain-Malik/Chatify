import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';
import 'package:chatify_final_project/app/theme.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  late TextEditingController nameCtrl;
  late TextEditingController emailCtrl;
  late TextEditingController passCtrl;
  late TextEditingController bioCtrl;
  bool isLoading = false;
  File? _selectedImage;
  String? _uploadedImageUrl;

  @override
  void initState() {
    super.initState();
    nameCtrl = TextEditingController();
    emailCtrl = TextEditingController();
    passCtrl = TextEditingController();
    bioCtrl = TextEditingController();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    emailCtrl.dispose();
    passCtrl.dispose();
    bioCtrl.dispose();
    super.dispose();
  }

  bool _isValidEmail(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  Future<void> _pickProfileImage() async {
    try {
      final imagePicker = ImagePicker();
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
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

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthService>();
    final cloudinary = Get.find<CloudinaryService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Sign Up')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            children: [
              // Profile Picture
              GestureDetector(
                onTap: isLoading ? null : _pickProfileImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: AppColors.gradientEnd.withOpacity(0.2),
                  backgroundImage: _selectedImage != null
                      ? FileImage(_selectedImage!)
                      : null,
                  child: _selectedImage == null
                      ? Icon(
                    Icons.add_a_photo,
                    size: 30,
                    color: AppColors.gradientEnd,
                  )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _selectedImage != null
                    ? 'Tap to change photo'
                    : 'Tap to add profile photo',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  border: OutlineInputBorder(),
                ),
                enabled: !isLoading,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                enabled: !isLoading,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: passCtrl,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  helperText: 'At least 6 characters',
                ),
                obscureText: true,
                enabled: !isLoading,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: bioCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bio (optional)',
                  border: OutlineInputBorder(),
                  hintText: 'Tell us about yourself',
                ),
                maxLines: 3,
                enabled: !isLoading,
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: isLoading
                    ? null
                    : () async {
                  final name = nameCtrl.text.trim();
                  final email = emailCtrl.text.trim();
                  final password = passCtrl.text;
                  final bio = bioCtrl.text.trim();

                  // Validation
                  if (name.isEmpty) {
                    Get.snackbar(
                      'Validation Error',
                      'Please enter a display name',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  if (email.isEmpty || !_isValidEmail(email)) {
                    Get.snackbar(
                      'Validation Error',
                      'Please enter a valid email address',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  if (password.length < 6) {
                    Get.snackbar(
                      'Validation Error',
                      'Password must be at least 6 characters',
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                    return;
                  }

                  setState(() => isLoading = true);
                  try {
                    // Upload profile picture if selected
                    String? avatarUrl;
                    if (_selectedImage != null) {
                      try {
                        avatarUrl = await cloudinary.uploadFile(
                          _selectedImage!.path,
                          folder: 'profile_pictures',
                        );
                      } catch (e) {
                        Get.snackbar(
                          'Image Upload Failed',
                          'Failed to upload profile picture: $e',
                          snackPosition: SnackPosition.BOTTOM,
                          backgroundColor: Colors.orange,
                          colorText: Colors.white,
                        );
                        // Continue with signup without image
                      }
                    }

                    await auth.signUpWithEmail(
                      email,
                      password,
                      name,
                      bio: bio.isNotEmpty ? bio : null,
                      avatarUrl: avatarUrl,
                    );
                    Get.offNamed(AppRoutes.chats);
                  } catch (e) {
                    Get.snackbar(
                      'Sign up failed',
                      e.toString(),
                      snackPosition: SnackPosition.BOTTOM,
                      backgroundColor: Colors.red,
                      colorText: Colors.white,
                    );
                  } finally {
                    setState(() => isLoading = false);
                  }
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(Radius.circular(14)),
                    gradient: isLoading
                        ? LinearGradient(
                      colors: [
                        AppColors.gradientStart.withOpacity(0.5),
                        AppColors.gradientEnd.withOpacity(0.5),
                      ],
                    )
                        : const LinearGradient(
                      colors: [
                        AppColors.gradientStart,
                        AppColors.gradientEnd,
                      ],
                    ),
                  ),
                  child: Center(
                    child: isLoading
                        ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Create account',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: isLoading ? null : () => Get.back(),
                child: const Text('Already have an account? Sign in'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
