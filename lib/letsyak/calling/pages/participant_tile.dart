import 'package:fluffychat/letsyak/calling/models/call_participant.dart';
import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

/// A single video tile for a call participant.
///
/// Shows the participant's video track if available, or their avatar
/// with a colored background if video is muted.
class ParticipantTile extends StatelessWidget {
  final CallParticipant participant;
  final bool isActiveSpeaker;
  final bool isLarge;
  final VoidCallback? onTap;

  const ParticipantTile({
    required this.participant,
    this.isActiveSpeaker = false,
    this.isLarge = false,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasVideo =
        participant.videoTrack?.track != null && !participant.isCameraMuted;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(12),
          border: isActiveSpeaker
              ? Border.all(color: theme.colorScheme.primary, width: 3)
              : null,
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Video or avatar
            if (hasVideo)
              VideoTrackRenderer(
                participant.videoTrack!.track as VideoTrack,
                fit: VideoViewFit.cover,
                mirrorMode: participant.isLocal
                    ? VideoViewMirrorMode.mirror
                    : VideoViewMirrorMode.off,
              )
            else
              _AvatarPlaceholder(
                displayName: participant.displayName,
                isLarge: isLarge,
              ),

            // Bottom bar: name + indicators
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                  ),
                ),
                child: Row(
                  children: [
                    if (participant.hasRaisedHand)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Text('✋', style: TextStyle(fontSize: 14)),
                      ),
                    Expanded(
                      child: Text(
                        participant.isLocal ? 'You' : participant.displayName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (participant.isMicrophoneMuted)
                      const Icon(
                        Icons.mic_off,
                        color: Colors.redAccent,
                        size: 16,
                      ),
                    if (participant.isScreenSharing)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(
                          Icons.screen_share,
                          color: Colors.blueAccent,
                          size: 16,
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Connection quality indicator
            if (!participant.isLocal &&
                participant.connectionQuality == ConnectionQuality.poor)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.signal_wifi_statusbar_connected_no_internet_4,
                  color: Colors.orangeAccent,
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  final String displayName;
  final bool isLarge;

  const _AvatarPlaceholder({required this.displayName, this.isLarge = false});

  @override
  Widget build(BuildContext context) {
    final initials = displayName.isNotEmpty
        ? displayName[0].toUpperCase()
        : '?';
    final size = isLarge ? 80.0 : 48.0;
    final fontSize = isLarge ? 32.0 : 20.0;

    return Center(
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Colors.blueGrey.shade700,
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: fontSize,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
