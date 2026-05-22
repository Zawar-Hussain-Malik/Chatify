import 'package:get/get.dart';
import 'package:chatify_final_project/pages/splash_page.dart';
import 'package:chatify_final_project/pages/auth/login_page.dart';
import 'package:chatify_final_project/pages/auth/signup_page.dart';
import 'package:chatify_final_project/pages/home/chats_page.dart';
import 'package:chatify_final_project/pages/home/new_chat_page.dart';
import 'package:chatify_final_project/pages/home/profile_page.dart';
import 'package:chatify_final_project/pages/home/settings_page.dart';
import 'package:chatify_final_project/pages/home/user_details_page.dart';
import 'package:chatify_final_project/pages/chat/chat_page.dart';

import '../pages/home/onboarding.dart';
import 'bindings/initial_binding.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const chats = '/chats';
  static const newChat = '/newchat';
  static const profile = '/profile';
  static const settings = '/settings';
  static const userDetails = '/userdetails';
  static const chat = '/chat';
  static const signup = '/signup';
  static const onboarding = '/onboarding';

  static List<GetPage> pages = [
    GetPage(name: splash, page: () => const SplashPage()),
    GetPage(name: login,
      page: () => const LoginPage(),
      binding: InitialBinding(),
      ),
    GetPage(name: signup,
      page: () => const SignupPage(),
      binding: InitialBinding(),
      ),
    GetPage(name: chats, page: () => const ChatsPage()),
    GetPage(name: newChat, page: () => const NewChatPage()),
    GetPage(name: profile, page: () => const ProfilePage()),
    GetPage(name: settings, page: () => const SettingsPage()),
    GetPage(name: userDetails, page: () => UserDetailsPage(userId: Get.arguments ?? '')),
    GetPage(name: chat, page: () => const ChatPage()),
    GetPage(name: onboarding, page: () => const OnboardingPage()),
  ];
}
