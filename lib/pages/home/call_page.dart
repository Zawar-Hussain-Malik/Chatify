import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

import '../../services/call_service.dart';

class CallScreen extends StatefulWidget {
  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final WebRTCCallService _callService = Get.find<WebRTCCallService>();
  late String peerName;
  late bool isCaller;

  @override
  void initState() {
    super.initState();
    final args = Get.arguments as Map<String, dynamic>;
    peerName = args['peerName'];
    isCaller = args['isCaller'];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Background gradient
          _buildWaitingUI(),

          // Glassmorphism overlay for better UI visibility
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.4),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.6),
                  ],
                  stops: [0.0, 0.2, 0.7, 1.0],
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Top section with peer info
                _buildTopSection(),

                Spacer(),

                // Call controls (only show when connected)
                Obx(() {
                  if (_callService.callState.value == CallState.connected) {
                    return _buildCallControls();
                  }
                  return SizedBox.shrink();
                }),

                SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingUI() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF667eea),
            Color(0xFF764ba2),
            Color(0xFFf093fb),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated avatar with ripple effect
          Stack(
            alignment: Alignment.center,
            children: [
              // Conditional ripple animations
              Obx(() {
                final state = _callService.callState.value;
                if (state == CallState.dialing || state == CallState.ringing) {
                  return _RippleAnimation(delay: 0, size: 180, maxExpansion: 40);
                }
                return SizedBox.shrink();
              }),
              Obx(() {
                final state = _callService.callState.value;
                if (state == CallState.dialing || state == CallState.ringing) {
                  return _RippleAnimation(delay: 500, size: 160, maxExpansion: 60);
                }
                return SizedBox.shrink();
              }),

              // Avatar with different icons based on state
              Obx(() {
                final state = _callService.callState.value;
                IconData icon;
                Color iconColor;

                if (state == CallState.failed) {
                  icon = Icons.error_outline;
                  iconColor = Colors.red[300]!;
                } else if (state == CallState.disconnected) {
                  icon = Icons.call_end;
                  iconColor = Colors.white;
                } else if (state == CallState.connected) {
                  icon = Icons.call;
                  iconColor = Colors.greenAccent;
                } else {
                  icon = Icons.person;
                  iconColor = Colors.white;
                }

                return Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withOpacity(state == CallState.connected ? 0.5 : 0.3),
                        Colors.white.withOpacity(state == CallState.connected ? 0.3 : 0.1),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.white.withOpacity(state == CallState.connected ? 0.5 : 0.3),
                      width: state == CallState.connected ? 4 : 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 70,
                    color: iconColor,
                  ),
                );
              }),
            ],
          ),

          SizedBox(height: 40),

          // Peer name
          Text(
            peerName,
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              shadows: [
                Shadow(
                  offset: Offset(0, 2),
                  blurRadius: 8,
                  color: Colors.black.withOpacity(0.3),
                ),
              ],
            ),
          ),

          SizedBox(height: 12),

          // Detailed status with proper state handling
          Obx(() {
            final state = _callService.callState.value;
            String status;
            Color statusColor;

            switch (state) {
              case CallState.initializing:
                status = 'Initializing...';
                statusColor = Colors.white.withOpacity(0.9);
                break;
              case CallState.dialing:
                status = isCaller ? 'Calling...' : 'Connecting...';
                statusColor = Colors.white.withOpacity(0.9);
                break;
              case CallState.ringing:
                status = isCaller ? 'Ringing...' : 'Incoming Call';
                statusColor = Colors.greenAccent;
                break;
              case CallState.connecting:
                status = 'Connecting...';
                statusColor = Colors.white.withOpacity(0.9);
                break;
              case CallState.connected:
                status = 'Connected';
                statusColor = Colors.greenAccent;
                break;
              case CallState.disconnected:
                status = 'Call Ended';
                statusColor = Colors.red[300]!;
                break;
              case CallState.failed:
                status = 'Call Failed';
                statusColor = Colors.red[300]!;
                break;
              default:
                status = 'Connecting...';
                statusColor = Colors.white.withOpacity(0.9);
            }

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: statusColor,
                    boxShadow: [
                      if (state == CallState.connected || state == CallState.ringing)
                        BoxShadow(
                          color: statusColor.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
                if (state == CallState.dialing ||
                    state == CallState.ringing ||
                    state == CallState.connecting) ...[
                  SizedBox(width: 4),
                  _buildAnimatedDots(),
                ],
              ],
            );
          }),

          SizedBox(height: 8),

          // Call type indicator
          Obx(() {
            final state = _callService.callState.value;
            final isActive = state == CallState.connected;

            return Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isActive ? Colors.green.withOpacity(0.2) : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isActive ? Colors.green.withOpacity(0.5) : Colors.white.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.phone,
                    color: isActive ? Colors.greenAccent : Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Voice Call',
                    style: TextStyle(
                      color: isActive ? Colors.greenAccent : Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }),

          // Add accept/reject buttons for incoming calls
          if (!isCaller)
            Obx(() {
              if (_callService.callState.value == CallState.ringing) {
                return Padding(
                  padding: EdgeInsets.only(top: 40),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Reject button
                      _buildIncomingCallButton(
                        icon: Icons.call_end,
                        label: 'Decline',
                        color: Colors.red,
                        onPressed: () => _callService.endCall(),
                      ),
                      SizedBox(width: 40),
                      // Accept button
                      _buildIncomingCallButton(
                        icon: Icons.call,
                        label: 'Accept',
                        color: Colors.green,
                        onPressed: () => _callService.answerCall(
                          _callService.currentCallId!,
                          _callService.currentPeerId!,
                          _callService.peerName!,
                        ),
                      ),
                    ],
                  ),
                );
              }
              return SizedBox.shrink();
            }),
        ],
      ),
    );
  }

  Widget _buildAnimatedDots() {
    return Row(
      children: List.generate(3, (index) {
        return _AnimatedDot(index: index);
      }),
    );
  }

  Widget _buildTopSection() {
    return Padding(
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          // Back button (minimized during active call)
          Obx(() {
            if (_callService.callState.value != CallState.connected) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => _callService.endCall(),
                ),
              );
            }
            return SizedBox.shrink();
          }),

          Spacer(),

          // Connection status indicator
          Obx(() {
            final state = _callService.callState.value;

            if (state == CallState.connected) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.green.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.greenAccent.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Connected',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            } else if (state == CallState.ringing && !isCaller) {
              return Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.orange.withOpacity(0.5),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Colors.orangeAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.orangeAccent.withOpacity(0.6),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Incoming',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }
            return SizedBox.shrink();
          }),
        ],
      ),
    );
  }

  Widget _buildCallControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        children: [
          // Primary controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Mute/Unmute
              Obx(() => _buildControlButton(
                icon: _callService.isAudioEnabled.value
                    ? Icons.mic
                    : Icons.mic_off,
                label: _callService.isAudioEnabled.value ? 'Mute' : 'Unmuted',
                onPressed: () => _callService.toggleAudio(),
                isActive: _callService.isAudioEnabled.value,
              )),

              // End call button (larger, red)
              _buildEndCallButton(),

              // Speaker toggle
              _buildControlButton(
                icon: Icons.volume_up,
                label: 'Speaker',
                onPressed: () {}, // Add speaker toggle functionality
                isActive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    required bool isActive,
    bool isSecondary = false,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSecondary ? 50 : 65,
          height: isSecondary ? 50 : 65,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? Colors.white.withOpacity(0.2)
                : Colors.red.withOpacity(0.8),
            border: Border.all(
              color: isActive
                  ? Colors.white.withOpacity(0.3)
                  : Colors.red.withOpacity(0.5),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: (isActive ? Colors.white : Colors.red).withOpacity(0.2),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onPressed,
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: isSecondary ? 24 : 28,
                ),
              ),
            ),
          ),
        ),
        if (!isSecondary) ...[
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildEndCallButton() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 75,
          height: 75,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFF416C),
                Color(0xFFFF4B2B),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: Color(0xFFFF4B2B).withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => _callService.endCall(),
              child: Center(
                child: Icon(
                  Icons.call_end,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          'End',
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildIncomingCallButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: onPressed,
              child: Center(
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// Ripple animation widget for continuous animation
class _RippleAnimation extends StatefulWidget {
  final int delay;
  final double size;
  final double maxExpansion;

  const _RippleAnimation({
    required this.delay,
    required this.size,
    required this.maxExpansion,
  });

  @override
  State<_RippleAnimation> createState() => _RippleAnimationState();
}

class _RippleAnimationState extends State<_RippleAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 2000),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    // Start with delay
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Container(
          width: widget.size + (_animation.value * widget.maxExpansion),
          height: widget.size + (_animation.value * widget.maxExpansion),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withOpacity(0.8 * (1 - _animation.value)),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}

// Animated dot widget for loading animation
class _AnimatedDot extends StatefulWidget {
  final int index;

  const _AnimatedDot({required this.index});

  @override
  State<_AnimatedDot> createState() => _AnimatedDotState();
}

class _AnimatedDotState extends State<_AnimatedDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: Duration(milliseconds: 1200),
      vsync: this,
    );

    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);

    // Start with delay based on index
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) {
        _controller.repeat();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Padding(
          padding: EdgeInsets.only(left: 2),
          child: Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(_animation.value),
            ),
          ),
        );
      },
    );
  }
}