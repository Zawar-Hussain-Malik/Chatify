import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chatify_final_project/widgets/message_bubble.dart';
import 'package:chatify_final_project/app/theme.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:chatify_final_project/services/cloudinary_service.dart';
import 'package:chatify_final_project/services/chat_service.dart';
import 'package:chatify_final_project/pages/chat/image_viewer.dart';
import 'package:chatify_final_project/pages/home/user_details_page.dart';
import 'package:chatify_final_project/pages/home/group_details_page.dart';
import 'package:chatify_final_project/models/user_model.dart';
import 'package:chatify_final_project/models/message_model.dart';
import 'package:chatify_final_project/services/download_service.dart';
import 'package:gal/gal.dart'; // ← Add this import
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';

import '../../services/call_service.dart';
import '../../services/message_listener_service.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  late TextEditingController textCtrl;
  bool isUploadingImage = false;
  bool isUploadingDocument = false;
  bool isRecording = false;
  bool isUploadingVoice = false;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _recordingPath;
  int _recordingDuration = 0;

  String? _currentlyPlayingMessageId;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  bool _isPlaying = false;

  String? _currentChatId;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    textCtrl = TextEditingController();

    // Audio player listeners (unchanged)
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _totalDuration = duration);
    });
    _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) setState(() => _currentPosition = position);
    });
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
          _currentlyPlayingMessageId = null;
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments as Map<String, dynamic>?;
      final chatId = args?['chatId'] as String?;
      _currentChatId = chatId;

      if (chatId != null) {
        final chatService = Get.find<ChatService>();
        _currentUserId = chatService.currentUserId;
        try {
          final messageListener = Get.find<MessageListenerService>();
          messageListener.markChatAsActive(chatId);
        } catch (_) {}
        chatService.markMessagesAsSeen(chatId);
      }
    });
  }

  @override
  void dispose() {
    textCtrl.dispose();
    _audioRecorder.dispose();
    _audioPlayer.stop();
    _audioPlayer.dispose();

    if (_currentChatId != null) {
      try {
        final messageListener = Get.find<MessageListenerService>();
        messageListener.markChatAsInactive(_currentChatId!);
      } catch (_) {}
      if (_currentUserId != null) {
        final chatService = Get.find<ChatService>();
        chatService.markMessagesAsSeen(_currentChatId!);
      }
    }
    super.dispose();
  }

  // Check and request gal access (once per session)
  Future<bool> _ensureGalAccess() async {
    if (await Gal.hasAccess()) return true;
    final granted = await Gal.requestAccess();
    if (!granted) {
      Get.dialog(
        AlertDialog(
          title: const Text('Permission Required'),
          content: const Text(
              'Chatify needs access to your Photos & Gallery to save media.\n\nPlease enable it in Settings.'),
          actions: [
            TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Get.back();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<void> _startRecording() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      Get.snackbar('Permission Required', 'Microphone access is needed for voice messages');
      return;
    }

    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (await _audioRecorder.hasPermission()) {
        await _audioRecorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
        setState(() {
          isRecording = true;
          _recordingPath = path;
          _recordingDuration = 0;
        });
        _startDurationCounter();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to start recording: $e');
    }
  }

  void _startDurationCounter() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (isRecording && mounted) {
        setState(() => _recordingDuration++);
        return true;
      }
      return false;
    });
  }

  Future<void> _stopRecording(String chatId) async {
    try {
      final path = await _audioRecorder.stop();
      setState(() => isRecording = false);

      if (path != null && path.isNotEmpty) {
        setState(() => isUploadingVoice = true);
        try {
          final cloudinary = Get.find<CloudinaryService>();
          final chatService = Get.find<ChatService>();
          final url = await cloudinary.uploadFile(path, folder: 'voice_messages');

          await chatService.sendMessage(
            chatId,
            voiceUrl: url,
            voiceDuration: _recordingDuration,
          );

          // Save voice message locally using gal
          final bytes = await File(path).readAsBytes();
          final downloadService = Get.find<MediaDownloadService>();
          await downloadService.saveLocalFileWithGal(bytes, 'voice_${DateTime.now().millisecondsSinceEpoch}.m4a');

          await File(path).delete();
        } finally {
          if (mounted) {
            setState(() {
              isUploadingVoice = false;
              _recordingDuration = 0;
            });
          }
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to send voice message: $e');
    }
  }

  Future<void> _cancelRecording() async {
    await _audioRecorder.stop();
    setState(() {
      isRecording = false;
      _recordingDuration = 0;
    });
    if (_recordingPath != null) await File(_recordingPath!).delete();
  }

  Future<void> _pickAndSendDocument(String chatId) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx', 'ppt', 'pptx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() => isUploadingDocument = true);
        try {
          final cloudinary = Get.find<CloudinaryService>();
          final chatService = Get.find<ChatService>();
          final url = await cloudinary.uploadFile(result.files.single.path!, folder: 'chat_documents');

          // Save picked document locally using gal
          final bytes = await File(result.files.single.path!).readAsBytes();
          final downloadService = Get.find<MediaDownloadService>();
          await downloadService.saveLocalFileWithGal(bytes, result.files.single.name);

          await chatService.sendMessage(
            chatId,
            documentUrl: url,
            documentName: result.files.single.name,
          );
        } finally {
          if (mounted) setState(() => isUploadingDocument = false);
        }
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick/send document: $e');
    }
  }

  Future<void> _pickAndSendImage(String chatId, {bool fromCamera = false}) async {
    try {
      final img = await ImagePicker().pickImage(
        source: fromCamera ? ImageSource.camera : ImageSource.gallery,
        imageQuality: 80,
      );
      if (img == null) return;

      setState(() => isUploadingImage = true);
      try {
        final cloudinary = Get.find<CloudinaryService>();
        final chatService = Get.find<ChatService>();
        final url = await cloudinary.uploadFile(img.path, folder: 'chat_images');

        // Save sent image locally using gal
        final bytes = await File(img.path).readAsBytes();
        final downloadService = Get.find<MediaDownloadService>();
        await downloadService.saveImageWithGal(bytes);

        await chatService.sendMessage(chatId, imageUrl: url);
      } finally {
        if (mounted) setState(() => isUploadingImage = false);
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to pick/send image: $e');
    }
  }

  void _showAttachmentOptions(String chatId) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.purple, child: Icon(Icons.image, color: Colors.white)),
              title: const Text('Image'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(chatId);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.insert_drive_file, color: Colors.white)),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendDocument(chatId);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.orange, child: Icon(Icons.camera_alt, color: Colors.white)),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickAndSendImage(chatId, fromCamera: true);
              },
            ),
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.red, child: Icon(Icons.mic, color: Colors.white)),
              title: const Text('Voice Message'),
              onTap: () {
                Navigator.pop(context);
                _startRecording();
              },
            ),
          ],
        ),
      ),
    );
  }

  void _startVoiceCall(String? otherUserId, String contactName) {
    if (otherUserId == null) {
      Get.snackbar(
        'Error',
        'Cannot start call',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return;
    }

    final callService = Get.find<WebRTCCallService>();
    callService.startVoiceCall(otherUserId, contactName);
  }

  @override
  Widget build(BuildContext context) {
    final args = Get.arguments as Map<String, dynamic>?;
    final chatId = args?['chatId'] as String? ?? 'unknown';
    final contactName = args?['contact'] as String?;
    final otherUserId = args?['otherUserId'] as String?;
    final isGroup = args?['isGroup'] as bool? ?? false;

    final chatService = Get.find<ChatService>();
    final currentUserId = chatService.currentUserId;

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () {
            if (isGroup) {
              Get.to(() => GroupDetailsPage(groupId: chatId));
            } else if (otherUserId != null) {
              Get.to(() => UserDetailsPage(userId: otherUserId));
            }
          },
          child: Row(
            children: [
              if (!isGroup && otherUserId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: StreamBuilder<AppUser?>(
                    stream: chatService.userStream(otherUserId),
                    builder: (context, snapshot) {
                      final user = snapshot.data;
                      return CircleAvatar(
                        radius: 18,
                        backgroundImage: user?.avatarUrl != null ? NetworkImage(user!.avatarUrl!) : null,
                        child: user?.avatarUrl == null ? const Icon(Icons.person, size: 18) : null,
                      );
                    },
                  ),
                ),
              Expanded(
                child: Text(
                  contactName ?? 'Chat',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (!isGroup) ...[
            IconButton(onPressed: () => _startVoiceCall(otherUserId, contactName ?? 'User'), icon: const Icon(Icons.call)),
          ],
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<MessageModel>>(
              stream: chatService.decryptedMessagesStream(chatId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.message_outlined, size: 64, color: Colors.grey[400]),
                        const SizedBox(height: 16),
                        Text('No messages yet', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock, size: 16, color: Colors.grey[500]),
                            const SizedBox(width: 4),
                            Text('End-to-end encrypted', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ],
                        ),
                      ],
                    ),
                  );
                }

                final messages = snapshot.data!;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == currentUserId;

                    if (message.hasDocument) {
                      return GestureDetector(
                        onLongPress: isMe ? () => _showDeleteDialog(chatService, chatId, message.id) : null,
                        onTap: () async {
                          if (!isMe && message.documentUrl != null) {
                            await _saveReceivedFile(message.documentUrl!, message.documentName ?? 'Document');
                          }
                        },
                        child: _buildDocumentMessage(
                          message.documentUrl!,
                          message.documentName ?? 'Document',
                          isMe,
                          message.sentAt,
                        ),
                      );
                    }

                    if (message.hasVoice) {
                      return GestureDetector(
                        onLongPress: isMe ? () => _showDeleteDialog(chatService, chatId, message.id) : null,
                        child: _buildVoiceMessageBubble(message, isMe),
                      );
                    }

                    if (message.hasImage) {
                      return GestureDetector(
                        onLongPress: isMe ? () => _showDeleteDialog(chatService, chatId, message.id) : null,
                        onTap: () async {
                          Get.to(() => ImageViewerPage(imageUrl: message.imageUrl!));
                          if (!isMe && message.imageUrl != null) {
                            await _saveReceivedFile(message.imageUrl!, 'image_${message.id}.jpg');
                          }
                        },
                        child: _buildImageMessage(message, isMe),
                      );
                    }

                    return isGroup && !isMe
                        ? StreamBuilder<AppUser?>(
                      stream: chatService.userStream(message.senderId),
                      builder: (context, snapshot) {
                        final senderUser = snapshot.data;
                        return MessageBubble(
                          text: message.text,
                          isMe: isMe,
                          time: _formatMessageTime(message.sentAt),
                          messageId: message.id,
                          chatId: chatId,
                          sender: senderUser,
                          status: message.status,
                        );
                      },
                    )
                        : MessageBubble(
                      text: message.text,
                      isMe: isMe,
                      time: _formatMessageTime(message.sentAt),
                      messageId: message.id,
                      chatId: chatId,
                      sender: null,
                      status: message.status,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 10),
              child: isRecording
                  ? _buildRecordingUI(chatId)
                  : Row(
                children: [
                  IconButton(
                    onPressed: isUploadingImage || isUploadingDocument || isUploadingVoice ? null : () => _showAttachmentOptions(chatId),
                    icon: isUploadingImage || isUploadingDocument || isUploadingVoice
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_circle_outline),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: textCtrl,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Message',
                          isDense: true,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () async {
                      final text = textCtrl.text.trim();
                      if (text.isNotEmpty) {
                        try {
                          await Get.find<ChatService>().sendMessage(chatId, text: text);
                          textCtrl.clear();
                        } catch (e) {
                          Get.snackbar('Error', 'Failed to send message: $e');
                        }
                      }
                    },
                    child: Container(
                      height: 44,
                      width: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.gradientStart, AppColors.gradientEnd],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: const Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _saveReceivedFile(String url, String filename) async {
    if (!await _ensureGalAccess()) return;

    try {
      final downloadService = Get.find<MediaDownloadService>();
      await downloadService.downloadAndSaveWithGal(url: url, filename: filename);
      Get.snackbar('Saved', 'File saved to Gallery/Downloads', backgroundColor: Colors.green);
    } catch (e) {
      Get.snackbar('Error', 'Failed to save file: $e', backgroundColor: Colors.red);
    }
  }

  void _showDeleteDialog(ChatService chatService, String chatId, String messageId) {
    Get.dialog(
      AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Message?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Get.back();
              try {
                await chatService.deleteMessage(chatId: chatId, messageId: messageId);
                Get.snackbar('Deleted', 'Message removed');
              } catch (e) {
                Get.snackbar('Error', 'Failed to delete message');
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentMessage(String documentUrl, String documentName, bool isMe, DateTime sentAt) {
    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.outgoingBubble : AppColors.incomingBubble,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => launchUrl(Uri.parse(documentUrl), mode: LaunchMode.externalApplication),
              child: Icon(Icons.insert_drive_file, color: isMe ? Colors.white : AppColors.gradientEnd),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: GestureDetector(
                onTap: () => launchUrl(Uri.parse(documentUrl), mode: LaunchMode.externalApplication),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      documentName,
                      style: TextStyle(color: isMe ? Colors.white : AppColors.textPrimary, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('Tap to open', style: TextStyle(color: isMe ? Colors.white70 : Colors.grey, fontSize: 11)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _saveReceivedFile(documentUrl, documentName),
              child: Icon(Icons.download, color: isMe ? Colors.white70 : Colors.grey, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessageBubble(MessageModel message, bool isMe) {
    final isCurrentlyPlaying = _currentlyPlayingMessageId == message.id;
    final totalDuration = Duration(seconds: message.voiceDuration ?? 0);
    final currentPos = isCurrentlyPlaying ? _currentPosition : Duration.zero;
    final progress = totalDuration.inMilliseconds > 0 ? currentPos.inMilliseconds / totalDuration.inMilliseconds : 0.0;

    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7, minWidth: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: isMe
              ? const LinearGradient(colors: [AppColors.gradientStart, AppColors.gradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight)
              : null,
          color: isMe ? null : AppColors.incomingBubble,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.08), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                if (isCurrentlyPlaying && _isPlaying) {
                  await _audioPlayer.pause();
                } else if (isCurrentlyPlaying && !_isPlaying) {
                  await _audioPlayer.resume();
                } else {
                  if (_currentlyPlayingMessageId != null) await _audioPlayer.stop();

                  setState(() {
                    _currentlyPlayingMessageId = message.id;
                    _totalDuration = totalDuration;
                  });

                  if (!isMe && message.voiceUrl != null) {
                    await _saveReceivedFile(message.voiceUrl!, 'voice_${message.id}.m4a');
                  }

                  try {
                    await _audioPlayer.play(UrlSource(message.voiceUrl!));
                  } catch (e) {
                    Get.snackbar('Error', 'Failed to play voice message');
                    setState(() => _currentlyPlayingMessageId = null);
                  }
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(color: (isMe ? Colors.white : AppColors.gradientEnd).withOpacity(0.2), shape: BoxShape.circle),
                child: Icon(
                  isCurrentlyPlaying && _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: isMe ? Colors.white : AppColors.gradientEnd,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 3,
                      backgroundColor: (isMe ? Colors.white : AppColors.gradientEnd).withOpacity(0.2),
                      valueColor: AlwaysStoppedAnimation<Color>(isMe ? Colors.white : AppColors.gradientEnd),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(isCurrentlyPlaying ? currentPos : totalDuration),
                        style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                      Text(
                        _formatDuration(totalDuration),
                        style: TextStyle(color: isMe ? Colors.white70 : Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageMessage(MessageModel message, bool isMe) {
    return Container(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.7,
            maxHeight: 300,
          ),
          child: Image.network(
            message.imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => Container(
              color: Colors.grey[300],
              padding: const EdgeInsets.all(16),
              child: const Icon(Icons.broken_image),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRecordingUI(String chatId) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(30)),
      child: Row(
        children: [
          IconButton(onPressed: _cancelRecording, icon: const Icon(Icons.delete, color: Colors.red)),
          const SizedBox(width: 8),
          Container(width: 12, height: 12, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(
            '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
            style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.red),
          ),
          const Spacer(),
          const Text('Recording...', style: TextStyle(color: Colors.red)),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _stopRecording(chatId),
            child: Container(
              height: 44,
              width: 44,
              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.red),
              child: const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatMessageTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}