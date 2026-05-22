// initial_binding.dart - CORRECTED
import 'package:get/get.dart';
import 'package:chatify_final_project/services/firebase_service.dart';
import 'package:chatify_final_project/services/auth_service.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/services/download_service.dart';
import 'package:chatify_final_project/services/presence_service.dart';
import 'package:chatify_final_project/services/message_listener_service.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    // Put FirebaseService immediately and permanently since it's needed from the start
    Get.put<FirebaseService>(FirebaseService(), permanent: true);

    // Put AuthService immediately and permanently - needed for authentication checks
    Get.put<AuthService>(AuthService(), permanent: true);

    // PresenceService - needed for online status
    Get.put<PresenceService>(PresenceService(), permanent: true);

    // Put CloudinaryService immediately with your credentials
    Get.put<CloudinaryService>(
      CloudinaryService(
        cloudName: 'df9zrqsau',
        uploadPreset: 'chatify',
      ),
      permanent: true,
    );

    // ChatService can be lazy but with fenix to recreate if deleted
    Get.lazyPut<ChatService>(() => ChatService(), fenix: true);

    // DownloadService can be lazy
    Get.lazyPut<MediaDownloadService>(() => MediaDownloadService(), fenix: true);

    // MessageListenerService as lazy (not permanent)
    Get.lazyPut<MessageListenerService>(() => MessageListenerService(), fenix: true);
  }
}