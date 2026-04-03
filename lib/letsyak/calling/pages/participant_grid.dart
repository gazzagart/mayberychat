import 'package:fluffychat/letsyak/calling/models/call_participant.dart';
import 'package:fluffychat/letsyak/calling/models/call_session_model.dart';
import 'package:fluffychat/letsyak/calling/pages/participant_tile.dart';
import 'package:flutter/material.dart';

/// Adaptive grid layout for call participant video tiles.
///
/// Automatically adjusts grid columns based on participant count:
/// - 1 participant: full screen
/// - 2 participants: 1 column, 2 rows
/// - 3-4 participants: 2x2 grid
/// - 5-6 participants: 2x3 grid
/// - 7-9 participants: 3x3 grid
/// - 10+ participants: 3+ columns, scrollable
class ParticipantGrid extends StatelessWidget {
  final CallSessionModel callSession;
  final String? activeSpeakerId;
  final ValueChanged<CallParticipant>? onParticipantTap;

  const ParticipantGrid({
    required this.callSession,
    this.activeSpeakerId,
    this.onParticipantTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final participants = callSession.participants;
    if (participants.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for participants...',
          style: TextStyle(color: Colors.white70),
        ),
      );
    }

    // If someone is screen sharing, use speaker layout
    final screenSharer = participants
        .where((p) => p.isScreenSharing && !p.isLocal)
        .firstOrNull;
    if (screenSharer != null) {
      return _SpeakerLayout(
        spotlight: screenSharer,
        others: participants.where((p) => p != screenSharer).toList(),
        activeSpeakerId: activeSpeakerId,
        onParticipantTap: onParticipantTap,
      );
    }

    // Single participant — full screen
    if (participants.length == 1) {
      return Padding(
        padding: const EdgeInsets.all(4),
        child: ParticipantTile(
          participant: participants.first,
          isActiveSpeaker: true,
          isLarge: true,
        ),
      );
    }

    // Grid layout
    final columns = _columnsForCount(participants.length);
    return GridView.builder(
      padding: const EdgeInsets.all(4),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        childAspectRatio: 16 / 12,
      ),
      itemCount: participants.length,
      itemBuilder: (context, index) {
        final p = participants[index];
        return ParticipantTile(
          participant: p,
          isActiveSpeaker: p.matrixId == activeSpeakerId,
          onTap: onParticipantTap != null ? () => onParticipantTap!(p) : null,
        );
      },
    );
  }

  int _columnsForCount(int count) {
    if (count <= 2) return 1;
    if (count <= 4) return 2;
    if (count <= 9) return 3;
    return 4;
  }
}

/// Layout with one spotlight tile (large) and a strip of thumbnails.
/// Used when someone is screen sharing.
class _SpeakerLayout extends StatelessWidget {
  final CallParticipant spotlight;
  final List<CallParticipant> others;
  final String? activeSpeakerId;
  final ValueChanged<CallParticipant>? onParticipantTap;

  const _SpeakerLayout({
    required this.spotlight,
    required this.others,
    this.activeSpeakerId,
    this.onParticipantTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Main spotlight
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: ParticipantTile(
              participant: spotlight,
              isActiveSpeaker: true,
              isLarge: true,
            ),
          ),
        ),
        // Thumbnail strip
        if (others.isNotEmpty)
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              itemCount: others.length,
              itemBuilder: (context, index) {
                final p = others[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: AspectRatio(
                    aspectRatio: 16 / 12,
                    child: ParticipantTile(
                      participant: p,
                      isActiveSpeaker: p.matrixId == activeSpeakerId,
                      onTap: onParticipantTap != null
                          ? () => onParticipantTap!(p)
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
