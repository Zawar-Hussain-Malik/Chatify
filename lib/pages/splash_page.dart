import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:chatify_final_project/app/routes.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/services/presence_service.dart';
import 'package:chatify_final_project/services/message_listener_service.dart';
import 'package:chatify_final_project/services/app_lifecycle_service.dart';

import '../services/onboarding_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late AnimationController _fadeController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _checkAuthStatus();
  }

  void _initAnimations() {
    // Scale animation for logo
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _scaleAnimation = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Fade animation for text
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeIn,
    );

    // Start animations
    _scaleController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      _fadeController.forward();
    });
  }
  Future<void> _checkAuthStatus() async {
    // Keep your splash animation delay
    await Future.delayed(const Duration(milliseconds: 2000));

    final onboardingService = OnboardingService();

    // 1️⃣ Check onboarding first
    if (!onboardingService.isCompleted()) {
      Get.offAllNamed(AppRoutes.onboarding);
      return;
    }

    // 2️⃣ Properly wait for Firebase to resolve the real auth state
    FirebaseAuth.instance.authStateChanges().listen((User? user) async {
      // This listener will fire immediately with the correct resolved state
      if (user != null) {
        // User is actually signed in
        try {
          // Re-initialize services only if needed
          if (Get.isRegistered<PresenceService>()) {
            await Get.find<PresenceService>().initialize();
          } else {
            final presenceService = Get.put(PresenceService());
            await presenceService.initialize();
          }

          Get.put(AppLifecycleService(), permanent: true);

          if (!Get.isRegistered<MessageListenerService>()) {
            Get.put(MessageListenerService(), permanent: true);
          }

          Get.offAllNamed(AppRoutes.chats);
        } catch (e) {
          if (kDebugMode) print('Error during post-login init: $e');
          Get.offAllNamed(AppRoutes.login);
        }
      } else {
        // Definitely no user
        Get.offAllNamed(AppRoutes.login);
      }
    }).onDone(() {
      // Fallback in case stream closes unexpectedly
      Get.offAllNamed(AppRoutes.login);
    });
  }

  @override
  void dispose() {
    _scaleController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF667eea),
              Color(0xFF764ba2),
            ],
          ),
        ),
        child: Stack(
          children: [
            // Animated background particles
            _buildFloatingParticle(
              top: MediaQuery.of(context).size.height * 0.2,
              left: MediaQuery.of(context).size.width * 0.2,
              size: 80,
              delay: 0,
            ),
            _buildFloatingParticle(
              top: MediaQuery.of(context).size.height * 0.6,
              right: MediaQuery.of(context).size.width * 0.2,
              size: 60,
              delay: 2,
            ),
            _buildFloatingParticle(
              bottom: MediaQuery.of(context).size.height * 0.2,
              left: MediaQuery.of(context).size.width * 0.3,
              size: 100,
              delay: 4,
            ),

            // Main content
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Animated chat icon
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.chat_bubble_rounded,
                        size: 60,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),

                  // App name with fade animation
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: const Text(
                      'Chatify',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tagline
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Text(
                      'Connect. Chat. Share.',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.white.withOpacity(0.9),
                        fontWeight: FontWeight.w300,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loading indicator at bottom
            Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: Center(
                  child: _buildDotsLoader(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingParticle({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required int delay,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(seconds: 8),
        builder: (context, value, child) {
          return Transform.translate(
            offset: Offset(0, -30 * (value < 0.5 ? value * 2 : (1 - value) * 2)),
            child: Opacity(
              opacity: 0.3 + (0.3 * (value < 0.5 ? value * 2 : (1 - value) * 2)),
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        },
        onEnd: () {
          // Restart animation
          setState(() {});
        },
      ),
    );
  }

  Widget _buildDotsLoader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1400),
          builder: (context, value, child) {
            final delay = index * 0.16;
            final adjustedValue = (value - delay).clamp(0.0, 1.0);
            final scale = adjustedValue < 0.4
                ? adjustedValue / 0.4
                : adjustedValue < 0.8
                ? 1.0
                : 1.0 - ((adjustedValue - 0.8) / 0.2);

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              transform: Matrix4.identity()..scale(scale),
            );
          },
          onEnd: () {
            setState(() {});
          },
        );
      }),
    );
  }
}