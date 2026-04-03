import 'package:livekit_client/livekit_client.dart' hide Room;
import 'package:matrix/matrix.dart';

/// Represents a participant in a LetsYak call.
class CallParticipant {
  final String matrixId;
  final String displayName;
  final Uri? avatarUrl;
  final bool isLocal;

  bool isMicrophoneMuted;
  bool isCameraMuted;
  bool isScreenSharing;
  bool isSpeaking;
  bool hasRaisedHand;
  ConnectionQuality connectionQuality;

  /// The LiveKit participant, if connected.
  Participant? livekitParticipant;

  /// The primary video track publication.
  TrackPublication? videoTrack;

  /// The screen share track publication.
  TrackPublication? screenShareTrack;

  CallParticipant({
    required this.matrixId,
    required this.displayName,
    this.avatarUrl,
    this.isLocal = false,
    this.isMicrophoneMuted = false,
    this.isCameraMuted = true,
    this.isScreenSharing = false,
    this.isSpeaking = false,
    this.hasRaisedHand = false,
    this.connectionQuality = ConnectionQuality.excellent,
    this.livekitParticipant,
    this.videoTrack,
    this.screenShareTrack,
  });

  /// Create from a LiveKit [RemoteParticipant] and Matrix room member info.
  factory CallParticipant.fromRemote(
    RemoteParticipant participant,
    Room matrixRoom,
  ) {
    final matrixId = participant.identity;
    final member = matrixRoom.unsafeGetUserFromMemoryOrFallback(matrixId);

    return CallParticipant(
      matrixId: matrixId,
      displayName: member.displayName ?? matrixId,
      avatarUrl: member.avatarUrl,
      isLocal: false,
      livekitParticipant: participant,
    );
  }

  /// Create for the local user.
  factory CallParticipant.local(LocalParticipant participant, Client client) {
    return CallParticipant(
      matrixId: client.userID!,
      displayName: client.userID!,
      avatarUrl: null,
      isLocal: true,
      livekitParticipant: participant,
    );
  }
}
