import 'package:fluffychat/letsyak/calling/calling_module.dart';
import 'package:fluffychat/letsyak/calling/pages/call_screen.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// A banner shown at the top of the chat when there's an incoming call
/// or an active call in the room that the user hasn't joined.
class IncomingCallBanner extends StatelessWidget {
  final Room room;
  final LetsYakCallingModule module;
  final List<String> activeCallers;

  const IncomingCallBanner({
    required this.room,
    required this.module,
    required this.activeCallers,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (activeCallers.isEmpty) return const SizedBox.shrink();

    // Don't show the banner if we're already in the call
    if (module.livekitService.isInCall) return const SizedBox.shrink();

    final callerNames = activeCallers
        .map(
          (id) => room.unsafeGetUserFromMemoryOrFallback(id).displayName ?? id,
        )
        .take(3)
        .join(', ');

    final extra = activeCallers.length > 3
        ? ' +${activeCallers.length - 3} more'
        : '';

    return Material(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.call,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$callerNames$extra in call',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton(
              onPressed: () => _joinCall(context),
              child: const Text('Join'),
            ),
            TextButton(
              onPressed: () {
                // Dismiss — just close the banner (do nothing).
                // The banner will reappear if the call is still active
                // and the user navigates back.
              },
              child: const Text('Dismiss'),
            ),
          ],
        ),
      ),
    );
  }

  void _joinCall(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => CallScreen(
          room: room,
          livekitService: module.livekitService,
          recordingService: module.recordingService,
          notificationService: module.notificationService,
          signaling: module.signaling,
        ),
      ),
    );
  }
}
