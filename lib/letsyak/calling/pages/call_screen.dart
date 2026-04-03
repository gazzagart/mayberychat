import 'package:fluffychat/letsyak/calling/models/call_participant.dart'
    as letsyak;
import 'package:fluffychat/letsyak/calling/models/call_session_model.dart';
import 'package:fluffychat/letsyak/calling/pages/admin_controls_sheet.dart';
import 'package:fluffychat/letsyak/calling/pages/call_controls_bar.dart';
import 'package:fluffychat/letsyak/calling/pages/call_lobby.dart';
import 'package:fluffychat/letsyak/calling/pages/participant_grid.dart';
import 'package:fluffychat/letsyak/calling/pages/recording_indicator.dart';
import 'package:fluffychat/letsyak/calling/services/call_notification_service.dart';
import 'package:fluffychat/letsyak/calling/services/livekit_service.dart';
import 'package:fluffychat/letsyak/calling/services/matrixrtc_signaling.dart';
import 'package:fluffychat/letsyak/calling/services/recording_service.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// The main call screen that manages the full call lifecycle:
/// lobby → connecting → connected → ended.
///
/// This is pushed as a full-screen route when a call is started or received.
class CallScreen extends StatefulWidget {
  final Room room;
  final LiveKitService livekitService;
  final RecordingService? recordingService;
  final CallNotificationService notificationService;
  final MatrixRtcSignaling signaling;
  final bool startWithVideo;

  const CallScreen({
    required this.room,
    required this.livekitService,
    required this.notificationService,
    required this.signaling,
    this.recordingService,
    this.startWithVideo = true,
    super.key,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  late final LiveKitService _lk;
  String? _activeEgressId;
  bool _showLobby = true;

  @override
  void initState() {
    super.initState();
    _lk = widget.livekitService;
    _lk.callState.addListener(_onCallStateChanged);
  }

  @override
  void dispose() {
    _lk.callState.removeListener(_onCallStateChanged);
    super.dispose();
  }

  void _onCallStateChanged() {
    if (!mounted) return;
    final status = _lk.callState.value.status;
    if (status == CallStatus.ended) {
      widget.notificationService.stopRingtone();
      // Pop the call screen after a brief delay so the user sees "Call ended"
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) Navigator.of(context).pop();
      });
    } else if (status == CallStatus.connected && _showLobby) {
      setState(() => _showLobby = false);
      widget.notificationService.playConnectedSound();
    }
    setState(() {});
  }

  Future<void> _joinCall({required bool withVideo}) async {
    setState(() => _showLobby = false);
    try {
      await _lk.joinCall(room: widget.room, withVideo: withVideo);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to join call: $e')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> _hangUp() async {
    await _lk.hangUp();
  }

  Future<void> _toggleRecording() async {
    final rs = widget.recordingService;
    if (rs == null) return;

    final cs = _lk.callState.value;
    if (cs.isRecording && _activeEgressId != null) {
      await rs.stopRecording(_activeEgressId!);
      _activeEgressId = null;
    } else {
      _activeEgressId = await rs.startRecording(cs.roomId ?? '');
    }
  }

  void _showAdminSheet(letsyak.CallParticipant participant) {
    showModalBottomSheet(
      context: context,
      builder: (_) => AdminControlsSheet(
        participant: participant,
        permissions: _lk.callState.value.permissions,
        onMuteParticipant: _lk.muteParticipant,
        onKickParticipant: _lk.kickParticipant,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent accidental back navigation during call
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _hangUp();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: ValueListenableBuilder<CallSessionModel>(
          valueListenable: _lk.callState,
          builder: (context, callSession, _) {
            // Show lobby if we haven't joined yet
            if (_showLobby) {
              final activeMembers =
                  widget.signaling.getActiveCallMembers(widget.room);
              return CallLobby(
                roomDisplayName: widget.room.getLocalizedDisplayname(),
                isGroupCall: !widget.room.isDirectChat,
                participantCount: activeMembers.length,
                livekitService: _lk,
                onJoinAudio: () => _joinCall(withVideo: false),
                onJoinVideo: () => _joinCall(withVideo: true),
                onCancel: () => Navigator.of(context).pop(),
              );
            }

            // Connecting / reconnecting overlay
            if (callSession.status == CallStatus.connecting ||
                callSession.status == CallStatus.reconnecting) {
              return _ConnectingOverlay(
                status: callSession.status,
                roomName: widget.room.getLocalizedDisplayname(),
                onCancel: _hangUp,
              );
            }

            // Ended
            if (callSession.status == CallStatus.ended) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call_end, color: Colors.white54, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      callSession.error ?? 'Call ended',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            // Connected — show participant grid + controls
            return Stack(
              children: [
                // Participant grid
                ParticipantGrid(
                  callSession: callSession,
                  activeSpeakerId: callSession.activeSpeakerId,
                  onParticipantTap: callSession.permissions.canMuteOthers
                      ? (p) {
                          if (!p.isLocal) _showAdminSheet(p);
                        }
                      : null,
                ),

                // Recording indicator
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: RecordingIndicator(callSession: callSession),
                  ),
                ),

                // Controls bar at bottom
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: CallControlsBar(
                    callSession: callSession,
                    onToggleMic: _lk.toggleMicrophone,
                    onToggleCamera: _lk.toggleCamera,
                    onSwitchCamera: _lk.switchCamera,
                    onToggleScreenShare: _lk.toggleScreenShare,
                    onToggleRaiseHand: _lk.toggleRaiseHand,
                    onHangUp: _hangUp,
                    onToggleRecording: widget.recordingService != null
                        ? _toggleRecording
                        : null,
                    onOpenAdminSheet: null, // Handled via participant tap
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Overlay shown while connecting or reconnecting.
class _ConnectingOverlay extends StatelessWidget {
  final CallStatus status;
  final String roomName;
  final VoidCallback onCancel;

  const _ConnectingOverlay({
    required this.status,
    required this.roomName,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isReconnecting = status == CallStatus.reconnecting;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: Colors.white),
          const SizedBox(height: 24),
          Text(
            isReconnecting ? 'Reconnecting...' : 'Connecting to $roomName...',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
          const SizedBox(height: 32),
          TextButton(
            onPressed: onCancel,
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }
}
