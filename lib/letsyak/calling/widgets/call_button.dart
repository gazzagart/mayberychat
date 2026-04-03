import 'package:fluffychat/letsyak/calling/calling_module.dart';
import 'package:fluffychat/letsyak/calling/config/calling_config.dart';
import 'package:fluffychat/letsyak/calling/pages/call_screen.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Call button that replaces the upstream VoIP/Jitsi button in the chat
/// header when the LetsYak calling module is enabled.
///
/// Works for both 1:1 and group chats.
class LetsYakCallButton extends StatelessWidget {
  final Room room;

  const LetsYakCallButton({required this.room, super.key});

  /// Whether this button should be shown for the given context.
  static bool shouldShow(BuildContext context) {
    if (!CallingConfig.isEnabled) return false;
    final matrixState = Matrix.of(context);
    return matrixState.letsyakCalling != null;
  }

  @override
  Widget build(BuildContext context) {
    final module = Matrix.of(context).letsyakCalling;
    if (module == null) return const SizedBox.shrink();

    final signaling = module.signaling;
    final hasActiveCall = signaling.hasActiveCall(room);

    return IconButton(
      icon: Icon(
        hasActiveCall ? Icons.call : Icons.call_outlined,
        color: hasActiveCall ? Theme.of(context).colorScheme.primary : null,
      ),
      tooltip: hasActiveCall ? 'Join call' : 'Start call',
      onPressed: () => _startOrJoinCall(context, module),
    );
  }

  void _startOrJoinCall(BuildContext context, LetsYakCallingModule module) {
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
