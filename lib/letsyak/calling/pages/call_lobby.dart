import 'package:fluffychat/letsyak/calling/services/livekit_service.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart' as lk;

/// Pre-join lobby screen where the user can preview their camera/mic
/// before entering the call.
class CallLobby extends StatefulWidget {
  final String roomDisplayName;
  final bool isGroupCall;
  final int participantCount;
  final LiveKitService livekitService;
  final VoidCallback onJoinAudio;
  final VoidCallback onJoinVideo;
  final VoidCallback onCancel;

  const CallLobby({
    required this.roomDisplayName,
    required this.isGroupCall,
    required this.participantCount,
    required this.livekitService,
    required this.onJoinAudio,
    required this.onJoinVideo,
    required this.onCancel,
    super.key,
  });

  @override
  State<CallLobby> createState() => _CallLobbyState();
}

class _CallLobbyState extends State<CallLobby> {
  bool _micEnabled = true;
  bool _cameraEnabled = true;
  lk.LocalVideoTrack? _previewTrack;

  @override
  void initState() {
    super.initState();
    _startPreview();
  }

  Future<void> _startPreview() async {
    try {
      _previewTrack = await lk.LocalVideoTrack.createCameraTrack(
        const lk.CameraCaptureOptions(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      // Camera not available — that's fine
    }
  }

  @override
  void dispose() {
    _previewTrack?.stop();
    super.dispose();
  }

  void _toggleMic() => setState(() => _micEnabled = !_micEnabled);

  void _toggleCamera() {
    if (_cameraEnabled) {
      _previewTrack?.stop();
      _previewTrack = null;
    } else {
      _startPreview();
    }
    setState(() => _cameraEnabled = !_cameraEnabled);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                  const Spacer(),
                  Text(
                    widget.roomDisplayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48), // balance close button
                ],
              ),
            ),

            // Participant count
            if (widget.participantCount > 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  '${widget.participantCount} participant${widget.participantCount == 1 ? '' : 's'} in call',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ),

            // Camera preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _cameraEnabled && _previewTrack != null
                      ? lk.VideoTrackRenderer(
                          _previewTrack!,
                          fit: lk.VideoViewFit.cover,
                          mirrorMode: lk.VideoViewMirrorMode.mirror,
                        )
                      : Container(
                          color: Colors.grey[900],
                          child: const Center(
                            child: Icon(
                              Icons.videocam_off,
                              color: Colors.white38,
                              size: 64,
                            ),
                          ),
                        ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Mic/Camera toggles
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LobbyToggle(
                  icon: _micEnabled ? Icons.mic : Icons.mic_off,
                  label: _micEnabled ? 'Mic on' : 'Mic off',
                  isActive: _micEnabled,
                  onTap: _toggleMic,
                ),
                const SizedBox(width: 32),
                _LobbyToggle(
                  icon: _cameraEnabled ? Icons.videocam : Icons.videocam_off,
                  label: _cameraEnabled ? 'Camera on' : 'Camera off',
                  isActive: _cameraEnabled,
                  onTap: _toggleCamera,
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Join buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: widget.onJoinAudio,
                      icon: const Icon(Icons.phone),
                      label: const Text('Audio only'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white38),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: widget.onJoinVideo,
                      icon: const Icon(Icons.videocam),
                      label: const Text('Join call'),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _LobbyToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _LobbyToggle({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.red.withValues(alpha: 0.3),
            ),
            child: Icon(
              icon,
              color: isActive ? Colors.white : Colors.redAccent,
              size: 28,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.redAccent,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
