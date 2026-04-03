import 'package:fluffychat/letsyak/calling/models/call_session_model.dart';
import 'package:flutter/material.dart';

/// Bottom controls bar for the call screen.
///
/// Shows toggle buttons for: microphone, camera, camera flip, screen share,
/// raise hand, and hang up. Optionally shows admin controls (record, admin sheet).
class CallControlsBar extends StatelessWidget {
  final CallSessionModel callSession;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleScreenShare;
  final VoidCallback onToggleRaiseHand;
  final VoidCallback onHangUp;
  final VoidCallback? onToggleRecording;
  final VoidCallback? onOpenAdminSheet;

  const CallControlsBar({
    required this.callSession,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onSwitchCamera,
    required this.onToggleScreenShare,
    required this.onToggleRaiseHand,
    required this.onHangUp,
    this.onToggleRecording,
    this.onOpenAdminSheet,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMicMuted = callSession.isMicMuted;
    final isCameraMuted = callSession.isCameraMuted;
    final isScreenSharing = callSession.isScreenSharing;
    final isRecording = callSession.isRecording;
    final canRecord = callSession.permissions.canStartRecording;
    final canAdmin = callSession.permissions.canMuteOthers;
    final localRaisedHand =
        callSession.localParticipant?.hasRaisedHand ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.6),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Mic toggle
            _ControlButton(
              icon: isMicMuted ? Icons.mic_off : Icons.mic,
              label: isMicMuted ? 'Unmute' : 'Mute',
              isActive: !isMicMuted,
              onTap: onToggleMic,
            ),

            // Camera toggle
            _ControlButton(
              icon: isCameraMuted ? Icons.videocam_off : Icons.videocam,
              label: isCameraMuted ? 'Start Video' : 'Stop Video',
              isActive: !isCameraMuted,
              onTap: onToggleCamera,
            ),

            // Camera flip (only when camera is on)
            if (!isCameraMuted)
              _ControlButton(
                icon: Icons.flip_camera_ios,
                label: 'Flip',
                isActive: true,
                onTap: onSwitchCamera,
              ),

            // Screen share
            _ControlButton(
              icon: isScreenSharing
                  ? Icons.stop_screen_share
                  : Icons.screen_share,
              label: isScreenSharing ? 'Stop Share' : 'Share',
              isActive: isScreenSharing,
              activeColor: theme.colorScheme.primary,
              onTap: onToggleScreenShare,
            ),

            // Raise hand
            _ControlButton(
              icon: Icons.front_hand,
              label: localRaisedHand ? 'Lower' : 'Raise',
              isActive: localRaisedHand,
              activeColor: Colors.amber,
              onTap: onToggleRaiseHand,
            ),

            // Recording (admin/mod only)
            if (canRecord && onToggleRecording != null)
              _ControlButton(
                icon: isRecording
                    ? Icons.stop_circle
                    : Icons.fiber_manual_record,
                label: isRecording ? 'Stop Rec' : 'Record',
                isActive: isRecording,
                activeColor: Colors.red,
                onTap: onToggleRecording!,
              ),

            // Admin controls (admin/mod only)
            if (canAdmin && onOpenAdminSheet != null)
              _ControlButton(
                icon: Icons.admin_panel_settings,
                label: 'Admin',
                isActive: false,
                onTap: onOpenAdminSheet!,
              ),

            // Hang up
            _HangUpButton(onTap: onHangUp),
          ],
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color? activeColor;
  final VoidCallback onTap;

  const _ControlButton({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? (activeColor ?? Colors.white) : Colors.white54;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isActive
                    ? (activeColor ?? Colors.white).withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _HangUpButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HangUpButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red,
              ),
              child: const Icon(Icons.call_end, color: Colors.white, size: 28),
            ),
            const SizedBox(height: 4),
            const Text(
              'End',
              style: TextStyle(color: Colors.red, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
