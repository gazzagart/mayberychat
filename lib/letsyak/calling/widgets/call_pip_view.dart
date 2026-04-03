import 'package:fluffychat/letsyak/calling/models/call_session_model.dart';
import 'package:fluffychat/letsyak/calling/pages/participant_tile.dart';
import 'package:fluffychat/letsyak/calling/services/livekit_service.dart';
import 'package:flutter/material.dart';

/// A draggable floating Picture-in-Picture view that shows the local
/// participant's video feed when the user navigates away from the
/// call screen while in an active call.
///
/// This is rendered as an overlay in the widget tree, typically from
/// the MatrixState widget.
class CallPipView extends StatefulWidget {
  final LiveKitService livekitService;

  const CallPipView({required this.livekitService, super.key});

  @override
  State<CallPipView> createState() => _CallPipViewState();
}

class _CallPipViewState extends State<CallPipView> {
  Offset _position = const Offset(16, 100);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CallSessionModel>(
      valueListenable: widget.livekitService.callState,
      builder: (context, callSession, _) {
        // Only show PiP when connected
        if (callSession.status != CallStatus.connected) {
          return const SizedBox.shrink();
        }

        final localParticipant = callSession.localParticipant;
        if (localParticipant == null) return const SizedBox.shrink();

        return Positioned(
          left: _position.dx,
          top: _position.dy,
          child: GestureDetector(
            onPanUpdate: (details) {
              setState(() {
                _position += details.delta;
              });
            },
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 120,
                height: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ParticipantTile(
                        participant: localParticipant,
                        isActiveSpeaker: false,
                      ),
                      // Tap to return to call screen
                      Positioned.fill(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              // Navigate back to call screen
                              // This will be handled by the calling module's
                              // navigation helper.
                            },
                          ),
                        ),
                      ),
                      // Call info bar
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          color: Colors.black54,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Icon(
                                callSession.isMicMuted
                                    ? Icons.mic_off
                                    : Icons.mic,
                                color: callSession.isMicMuted
                                    ? Colors.red
                                    : Colors.white,
                                size: 14,
                              ),
                              Icon(
                                callSession.isCameraMuted
                                    ? Icons.videocam_off
                                    : Icons.videocam,
                                color: callSession.isCameraMuted
                                    ? Colors.red
                                    : Colors.white,
                                size: 14,
                              ),
                              GestureDetector(
                                onTap: widget.livekitService.hangUp,
                                child: const Icon(
                                  Icons.call_end,
                                  color: Colors.red,
                                  size: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
