import 'package:flutter/material.dart';
import 'package:gal/gal.dart' show GalExceptionType, GalException, Gal;
import 'package:photo_view/photo_view.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:chatify_final_project/services/download_service.dart';

class ImageViewerPage extends StatefulWidget {
  final String imageUrl;
  const ImageViewerPage({super.key, required this.imageUrl});

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  bool _isDownloading = false;
  bool _hasDownloaded = false;

  Future<void> _downloadImage() async {
    // Prevent multiple downloads
    if (_isDownloading || _hasDownloaded) return;

    // Show confirmation dialog
    final bool? confirm = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: const Text('Download Image'),
        content: const Text('Save this image to your device?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Download'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDownloading = true);

    try {
      final downloader = Get.find<MediaDownloadService>();

      // Check for gallery access
      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        await Gal.requestAccess();
      }

      // Extract filename from URL or use default
      String filename = '';
      try {
        final uri = Uri.parse(widget.imageUrl);
        final pathSegments = uri.pathSegments;
        if (pathSegments.isNotEmpty) {
          filename = pathSegments.last;
        }
      } catch (e) {
        debugPrint('Error parsing filename from URL: $e');
      }

      await downloader.downloadAndSaveWithGal(
        url: widget.imageUrl,
        onProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toInt();
            debugPrint('Download progress: $progress%');
          }
        },
        filename: filename,
      );

      setState(() => _hasDownloaded = true);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image saved successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Also show Get snackbar if you prefer
      Get.snackbar(
        'Success',
        'Image saved to device storage and Gallery',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 3),
      );

    } catch (e) {
      if (e is GalException && e.type == GalExceptionType.accessDenied) {
        Get.snackbar(
          'Permission Denied',
          'Please grant Photos access in Settings',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      } else {
        debugPrint('Download error: $e');
        Get.snackbar(
          'Error',
          'Failed to save image: ${e.toString()}',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 3),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDownloading = false);
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      await launchUrl(
        Uri.parse(widget.imageUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Error opening in browser: $e');
      Get.snackbar(
        'Error',
        'Could not open image in browser',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 2),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          // Open in browser button
          IconButton(
            icon: const Icon(Icons.open_in_new),
            tooltip: 'Open in browser',
            onPressed: _openInBrowser,
          ),

          // Download button with state
          IconButton(
            icon: _isDownloading
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : _hasDownloaded
                ? const Icon(Icons.check, color: Colors.green)
                : const Icon(Icons.download),
            tooltip: _hasDownloaded ? 'Already downloaded' : 'Download image',
            onPressed: _hasDownloaded ? null : _downloadImage,
          ),
        ],
      ),
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Center(
          child: PhotoView(
            imageProvider: NetworkImage(widget.imageUrl),
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder: (context, event) {
              if (event == null || event.expectedTotalBytes == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }
              return Center(
                child: CircularProgressIndicator(
                  value: event.cumulativeBytesLoaded / event.expectedTotalBytes!,
                  color: Colors.white,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load image',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            },
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2.0,
            initialScale: PhotoViewComputedScale.contained,
            basePosition: Alignment.center,
            filterQuality: FilterQuality.high,
            enableRotation: true,
          ),
        ),
      ),
    );
  }
}