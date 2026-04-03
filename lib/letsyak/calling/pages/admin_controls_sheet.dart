import 'package:fluffychat/letsyak/calling/models/call_participant.dart';
import 'package:fluffychat/letsyak/calling/models/call_permissions.dart';
import 'package:flutter/material.dart';

/// Bottom sheet for admin/moderator controls on a specific participant
/// or on the call as a whole.
///
/// Actions: mute participant, kick participant, etc.
class AdminControlsSheet extends StatelessWidget {
  final CallParticipant participant;
  final CallPermissions permissions;
  final ValueChanged<String> onMuteParticipant;
  final ValueChanged<String> onKickParticipant;

  const AdminControlsSheet({
    required this.participant,
    required this.permissions,
    required this.onMuteParticipant,
    required this.onKickParticipant,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Participant name
            Text(
              participant.displayName,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              participant.matrixId,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey,
                  ),
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Mute participant
            if (permissions.canMuteOthers)
              ListTile(
                leading: Icon(
                  participant.isMicrophoneMuted ? Icons.mic : Icons.mic_off,
                  color: Colors.orange,
                ),
                title: Text(
                  participant.isMicrophoneMuted
                      ? 'Participant is muted'
                      : 'Mute participant',
                ),
                onTap: participant.isMicrophoneMuted
                    ? null
                    : () {
                        onMuteParticipant(participant.matrixId);
                        Navigator.of(context).pop();
                      },
              ),

            // Kick participant
            if (permissions.canKickParticipants)
              ListTile(
                leading: const Icon(Icons.person_remove, color: Colors.red),
                title: const Text('Remove from call'),
                onTap: () {
                  _confirmKick(context);
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmKick(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove participant'),
        content: Text(
          'Remove ${participant.displayName} from this call?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              onKickParticipant(participant.matrixId);
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
