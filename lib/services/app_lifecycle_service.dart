import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'presence_service.dart';

class AppLifecycleService extends GetxService
    with WidgetsBindingObserver {

  final PresenceService _presenceService = Get.find();

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    // Set user as online when service initializes (app is starting/active)
    _presenceService.setOnline().catchError((error) {
      // Silently handle errors
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle state changes
    if (state == AppLifecycleState.resumed) {
      // App is active/foreground - set user as online
      _presenceService.setOnline().catchError((error) {
        // Silently handle errors
      });
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // App is in background or inactive - set user as offline
      _presenceService.setOffline().catchError((error) {
        // Silently handle errors
      });
    } else if (state == AppLifecycleState.detached) {
      // App is being terminated - disconnect completely
      _presenceService.disconnect().catchError((error) {
        // Silently handle errors
      });
    }
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }
}
