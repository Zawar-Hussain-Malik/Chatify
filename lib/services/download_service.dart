import 'dart:typed_data';
import 'dart:io';
import 'package:gal/gal.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class MediaDownloadService {
  final Dio _dio = Dio();

  // Get app's storage directory for saving files
  // Creates a "Chatify" directory if it doesn't exist, otherwise uses existing directory
  Future<Directory> _getAppStorageDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final chatifyDir = Directory(path.join(appDir.path, 'Chatify'));

    // Check if Chatify directory exists
    if (await chatifyDir.exists()) {
      // Directory already exists, return it
      return chatifyDir;
    } else {
      // Directory doesn't exist, create it with all parent directories
      await chatifyDir.create(recursive: true);
      return chatifyDir;
    }
  }

  // Save image bytes directly (fastest for images)
  Future<void> saveImageWithGal(Uint8List bytes, {String album = 'Chatify'}) async {
    await Gal.putImageBytes(bytes, album: album);
  }

  // Generic method: download from URL → temp file → save with gal (supports images, videos, voice, docs)
  Future<void> downloadAndSaveWithGal({
    required String url,
    required String filename, // e.g., 'photo.jpg', 'voice_123.m4a', 'doc.pdf'
    void Function(int received, int total)? onProgress,
    String album = 'Chatify', // Used for images/videos; ignored for non-media
  }) async {
    // Download to bytes first
    final response = await _dio.get(
      url,
      options: Options(responseType: ResponseType.bytes),
      onReceiveProgress: onProgress,
    );
    final Uint8List bytes = Uint8List.fromList(response.data);

    // Generate filename if empty or extract from URL
    String finalFilename = filename;
    if (finalFilename.isEmpty) {
      try {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          finalFilename = pathSegments.last;
        }
        // If still empty or no extension, generate a default filename
        if (finalFilename.isEmpty || !finalFilename.contains('.')) {
          // Try to detect content type from response headers
          final contentType = response.headers.value('content-type');
          String extension = 'jpg'; // default
          if (contentType != null) {
            if (contentType.contains('png')) extension = 'png';
            else if (contentType.contains('jpeg') || contentType.contains('jpg')) extension = 'jpg';
            else if (contentType.contains('gif')) extension = 'gif';
            else if (contentType.contains('webp')) extension = 'webp';
          }
          finalFilename = 'image_${DateTime.now().millisecondsSinceEpoch}.$extension';
        }
      } catch (e) {
        // Fallback: generate a default filename
        finalFilename = 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
      }
    }

    // Save to app's storage directory first
    final appStorageDir = await _getAppStorageDirectory();
    final appStorageFile = File(path.join(appStorageDir.path, finalFilename));
    await appStorageFile.writeAsBytes(bytes);

    // Save bytes to temporary file (required for non-image media and gallery)
    final tempDir = await getTemporaryDirectory();
    final tempFile = File(path.join(tempDir.path, finalFilename));
    await tempFile.writeAsBytes(bytes);

    // Determine file type and save to gallery accordingly
    final lower = finalFilename.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      // Prefer bytes method for images (faster, supports album)
      try {
        await Gal.putImageBytes(bytes, album: album, name: finalFilename);
      } catch (e) {
        // If gallery save fails, file is still saved in app storage
      }
    } else if (lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi')) {
      // Videos: only path supported
      try {
        await Gal.putVideo(tempFile.path, album: album);
      } catch (e) {
        // If gallery save fails, file is still saved in app storage
      }
    } else {
      // Non-media files (voice .m4a, PDF, DOC, etc.)
      // gal cannot save them to Gallery, but saving as image/video often places them in Downloads folder
      // This works on most devices (Android treats unknown media as downloadable files)
      try {
        await Gal.putImageBytes(bytes, album: 'Chatify Downloads', name: finalFilename);
      } catch (e) {
        // Fallback: try as video (some devices accept it)
        try {
          await Gal.putVideo(tempFile.path);
        } catch (e2) {
          // If gallery save fails, file is still saved in app storage
        }
      }
    }

    // Clean up temp file
    await tempFile.delete();
  }

  // Optional: direct save from local bytes (used when picking/sending media)
  Future<void> saveLocalFileWithGal(Uint8List bytes, String filename, {String album = 'Chatify'}) async {
    // Save to app's storage directory first
    final appStorageDir = await _getAppStorageDirectory();
    final appStorageFile = File(path.join(appStorageDir.path, filename));
    await appStorageFile.writeAsBytes(bytes);

    final lower = filename.toLowerCase();

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp')) {
      try {
        await Gal.putImageBytes(bytes, album: album, name: filename);
      } catch (e) {
        // If gallery save fails, file is still saved in app storage
      }
    } else {
      // For voice/docs: same fallback trick
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, filename));
      await tempFile.writeAsBytes(bytes);
      try {
        await Gal.putImageBytes(bytes, album: 'Chatify Downloads', name: filename);
      } catch (e) {
        try {
          await Gal.putVideo(tempFile.path);
        } catch (e2) {
          // If gallery save fails, file is still saved in app storage
        }
      }
      await tempFile.delete();
    }
  }

  // Get the path where files are saved in app storage
  Future<String> getAppStoragePath() async {
    final appStorageDir = await _getAppStorageDirectory();
    return appStorageDir.path;
  }

  // List all files saved in app storage
  Future<List<FileSystemEntity>> listSavedFiles() async {
    final appStorageDir = await _getAppStorageDirectory();
    if (await appStorageDir.exists()) {
      return await appStorageDir.list().toList();
    }
    return [];
  }
}