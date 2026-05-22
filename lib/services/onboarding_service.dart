import 'package:get_storage/get_storage.dart';

class OnboardingService {
  final _box = GetStorage();
  static const _key = 'onboarding_completed';

  bool isCompleted() {
    return _box.read(_key) ?? false;
  }

  Future<void> completeOnboarding() async {
    await _box.write(_key, true);
  }
}