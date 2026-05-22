import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart' hide navigator;
import '../pages/home/call_page.dart';

// Call state enum - ADDED DIRECTLY IN SERVICE
enum CallState {
  initializing,   // Setting up the call
  dialing,        // Caller: dialing/ringing
  ringing,        // Callee: incoming ring
  connecting,     // Media is connecting
  connected,      // Call is active
  disconnected,   // Call ended
  failed,         // Call failed
}

class WebRTCCallService extends GetxService {
  // WebRTC instances
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream;

  // Observables with call state
  final callState = CallState.initializing.obs;
  final isCallActive = false.obs;
  final isAudioEnabled = true.obs;
  final remoteStream = Rx<MediaStream?>(null);
  final localStream = Rx<MediaStream?>(null);

  // Firebase
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // Current call info
  String? currentCallId;
  String? currentPeerId;
  String? peerName;

  // ICE Servers Configuration (FREE)
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      // Google's free STUN servers
      {
        'urls': [
          'stun:stun.l.google.com:19302',
          'stun:stun1.l.google.com:19302',
          'stun:stun2.l.google.com:19302',
        ]
      },
      // Metered.ca FREE TURN servers
      {
        'urls': 'turn:openrelay.metered.ca:80',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
      {
        'urls': 'turn:openrelay.metered.ca:443',
        'username': 'openrelayproject',
        'credential': 'openrelayproject',
      },
    ]
  };

  // Audio only constraints for voice call
  final Map<String, dynamic> _audioOnlyConstraints = {
    'audio': true,
    'video': false,
  };

  @override
  void onInit() {
    super.onInit();
    _listenForIncomingCalls();
  }

  /// Start a voice call
  Future<void> startVoiceCall(String peerId, String peerName) async {
    try {
      callState.value = CallState.dialing;
      this.peerName = peerName;
      await _initializeCall(peerId, peerName);
    } catch (e) {
      print('Error starting voice call: $e');
      callState.value = CallState.failed;
      Get.snackbar('Error', 'Failed to start voice call');
    }
  }

  /// Initialize call
  Future<void> _initializeCall(String peerId, String peerName) async {
    currentPeerId = peerId;
    currentCallId = _firestore.collection('calls').doc().id;

    // Get local audio stream
    try {
      _localStream = await navigator.mediaDevices.getUserMedia(_audioOnlyConstraints);
      localStream.value = _localStream;
    } catch (e) {
      print('Error getting microphone: $e');
      callState.value = CallState.failed;
      Get.snackbar('Error', 'Microphone access denied');
      return;
    }

    // Create peer connection
    _peerConnection = await createPeerConnection(_configuration);

    // Add local audio track to peer connection
    _localStream!.getTracks().forEach((track) {
      _peerConnection!.addTrack(track, _localStream!);
    });

    // Listen for remote stream
    _peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        _remoteStream = event.streams[0];
        remoteStream.value = _remoteStream;
        callState.value = CallState.connected;
        isCallActive.value = true;
      }
    };

    // Listen for ICE candidates
    _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      _firestore.collection('calls').doc(currentCallId).collection('candidates').add({
        'candidate': candidate.toMap(),
        'from': _auth.currentUser!.uid,
      });
    };

    // Create offer
    RTCSessionDescription offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);

    // Save call to Firestore
    await _firestore.collection('calls').doc(currentCallId).set({
      'callerId': _auth.currentUser!.uid,
      'callerName': _auth.currentUser!.displayName ?? 'Unknown',
      'receiverId': peerId,
      'receiverName': peerName,
      'offer': offer.toMap(),
      'isVideo': false, // Always false for voice call
      'status': 'ringing',
      'timestamp': FieldValue.serverTimestamp(),
    });

    // Listen for answer
    _listenForAnswer();

    // Navigate to call screen
    Get.to(
          () => CallScreen(),
      arguments: {
        'callId': currentCallId,
        'peerId': peerId,
        'peerName': peerName,
        'isCaller': true,
      },
    );
  }

  /// Listen for incoming calls
  void _listenForIncomingCalls() {
    _firestore
        .collection('calls')
        .where('receiverId', isEqualTo: _auth.currentUser?.uid)
        .where('status', isEqualTo: 'ringing')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;
          final callerId = data['callerId'];

          if (callerId != _auth.currentUser?.uid) {
            // Update state to ringing
            callState.value = CallState.ringing;
            this.peerName = data['callerName'] ?? 'Unknown';

            _showIncomingCallDialog(
              callId: change.doc.id,
              callerName: data['callerName'] ?? 'Unknown',
              callerId: callerId,
            );
          }
        }
      }
    });
  }

  /// Show incoming call dialog
  void _showIncomingCallDialog({
    required String callId,
    required String callerName,
    required String callerId,
  }) {
    Get.defaultDialog(
      title: 'Incoming Voice Call',
      middleText: '$callerName is calling...',
      textConfirm: 'Accept',
      textCancel: 'Decline',
      confirmTextColor: Get.theme.colorScheme.onPrimary,
      onConfirm: () {
        Get.back();
        answerCall(callId, callerId, callerName);
      },
      onCancel: () {
        Get.back();
        declineCall(callId);
      },
    );
  }

  /// Answer incoming call
  Future<void> answerCall(String callId, String callerId, String callerName) async {
    try {
      callState.value = CallState.connecting;
      currentCallId = callId;
      currentPeerId = callerId;
      this.peerName = callerName;

      // Get call data
      final callDoc = await _firestore.collection('calls').doc(callId).get();
      final callData = callDoc.data()!;

      // Get local audio stream
      _localStream = await navigator.mediaDevices.getUserMedia(_audioOnlyConstraints);
      localStream.value = _localStream;

      // Create peer connection
      _peerConnection = await createPeerConnection(_configuration);

      // Add local audio track
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // Listen for remote stream
      _peerConnection!.onTrack = (RTCTrackEvent event) {
        if (event.streams.isNotEmpty) {
          _remoteStream = event.streams[0];
          remoteStream.value = _remoteStream;
          callState.value = CallState.connected;
          isCallActive.value = true;
        }
      };

      // Listen for ICE candidates from caller
      _listenForIceCandidates();

      // Set remote description (offer)
      await _peerConnection!.setRemoteDescription(
        RTCSessionDescription(
          callData['offer']['sdp'],
          callData['offer']['type'],
        ),
      );

      // Create answer
      RTCSessionDescription answer = await _peerConnection!.createAnswer();
      await _peerConnection!.setLocalDescription(answer);

      // Send answer
      await _firestore.collection('calls').doc(callId).update({
        'answer': answer.toMap(),
        'status': 'active',
      });

      // Listen for ICE candidates
      _peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        _firestore.collection('calls').doc(callId).collection('candidates').add({
          'candidate': candidate.toMap(),
          'from': _auth.currentUser!.uid,
        });
      };

      // Navigate to call screen
      Get.to(
            () => CallScreen(),
        arguments: {
          'callId': callId,
          'peerId': callerId,
          'peerName': callerName,
          'isCaller': false,
        },
      );
    } catch (e) {
      print('Error answering call: $e');
      callState.value = CallState.failed;
      Get.snackbar('Error', 'Failed to answer call');
    }
  }

  /// Listen for answer from receiver
  void _listenForAnswer() {
    _firestore.collection('calls').doc(currentCallId).snapshots().listen((doc) async {
      final data = doc.data();
      if (data != null && data['answer'] != null && data['status'] == 'active') {
        callState.value = CallState.connecting;
        await _peerConnection!.setRemoteDescription(
          RTCSessionDescription(
            data['answer']['sdp'],
            data['answer']['type'],
          ),
        );
        _listenForIceCandidates();
      }
    });
  }

  /// Listen for ICE candidates
  void _listenForIceCandidates() {
    _firestore
        .collection('calls')
        .doc(currentCallId)
        .collection('candidates')
        .where('from', isEqualTo: currentPeerId)
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        _peerConnection!.addCandidate(
          RTCIceCandidate(
            data['candidate']['candidate'],
            data['candidate']['sdpMid'],
            data['candidate']['sdpMLineIndex'],
          ),
        );
      }
    });
  }

  /// Decline call
  Future<void> declineCall(String callId) async {
    callState.value = CallState.disconnected;
    await _firestore.collection('calls').doc(callId).update({
      'status': 'declined',
    });
  }

  /// End call
  Future<void> endCall() async {
    try {
      // Update call status
      if (currentCallId != null) {
        await _firestore.collection('calls').doc(currentCallId).update({
          'status': 'ended',
          'endTime': FieldValue.serverTimestamp(),
        });
      }

      // Stop local stream
      _localStream?.getTracks().forEach((track) {
        track.stop();
      });

      // Close peer connection
      await _peerConnection?.close();

      // Clear streams
      _localStream = null;
      _remoteStream = null;
      localStream.value = null;
      remoteStream.value = null;

      // Reset state
      callState.value = CallState.disconnected;
      isCallActive.value = false;
      currentCallId = null;
      currentPeerId = null;
      peerName = null;

      Get.back();
    } catch (e) {
      print('Error ending call: $e');
      callState.value = CallState.failed;
    }
  }

  /// Toggle audio (mute/unmute)
  void toggleAudio() {
    if (_localStream != null) {
      final audioTrack = _localStream!.getAudioTracks().first;
      audioTrack.enabled = !audioTrack.enabled;
      isAudioEnabled.value = audioTrack.enabled;
    }
  }

  @override
  void onClose() {
    endCall();
    super.onClose();
  }
}