import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  final CloudinaryPublic cloudinary;

  CloudinaryService({required String cloudName, required String uploadPreset})
    : cloudinary = CloudinaryPublic(cloudName, uploadPreset, cache: false);

  /// Uploads a file at [filePath] to Cloudinary and returns the secure URL.
  Future<String> uploadFile(String filePath, {String? folder}) async {
    final file = CloudinaryFile.fromFile(filePath, folder: folder);
    try {
      final res = await cloudinary.uploadFile(file);
      return res.secureUrl;
    } on CloudinaryException catch (e) {
      throw Exception('Cloudinary upload failed: ${e.message}');
    }
  }
}
