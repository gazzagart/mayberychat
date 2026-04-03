import 'package:fluffychat/letsyak/calling/models/call_participant.dart';
import 'package:fluffychat/letsyak/calling/models/call_permissions.dart';

/// The overall state of a LetsYak call session.
enum CallStatus {
  /// No call active.
  idle,

  /// In the pre-join lobby, previewing camera/mic.
  lobby,

  /// Connecting to the LiveKit SFU.
  connecting,

  /// Connected and media is flowing.
  connected,

  /// Reconnecting after a network interruption.
  reconnecting,

  /// Call has ended (local hang-up or remote).
  ended,
}

/// Immutable snapshot of the current call state.
///
/// Rebuilt by [LiveKitService] whenever state changes, and provided
/// to the UI via [ValueNotifier].
class CallSessionModel {
  final CallStatus status;
  final String? roomId;
  final String? livekitRoomName;
  final List<CallParticipant> participants;
  final CallParticipant? localParticipant;
  final CallPermissions permissions;

  /// Whether the local user's microphone is muted.
  final bool isMicMuted;

  /// Whether the local user's camera is off.
  final bool isCameraMuted;

  /// Whether the local user is sharing their screen.
  final bool isScreenSharing;

  /// Whether any Admin/Mod has started recording.
  final bool isRecording;

  /// Active speaker's matrix ID, if any.
  final String? activeSpeakerId;

  /// Error message if the call failed.
  final String? error;

  const CallSessionModel({
    this.status = CallStatus.idle,
    this.roomId,
    this.livekitRoomName,
    this.participants = const [],
    this.localParticipant,
    this.permissions = const CallPermissions(CallRole.participant),
    this.isMicMuted = false,
    this.isCameraMuted = true,
    this.isScreenSharing = false,
    this.isRecording = false,
    this.activeSpeakerId,
    this.error,
  });

  CallSessionModel copyWith({
    CallStatus? status,
    String? roomId,
    String? livekitRoomName,
    List<CallParticipant>? participants,
    CallParticipant? localParticipant,
    CallPermissions? permissions,
    bool? isMicMuted,
    bool? isCameraMuted,
    bool? isScreenSharing,
    bool? isRecording,
    String? activeSpeakerId,
    String? error,
  }) {
    return CallSessionModel(
      status: status ?? this.status,
      roomId: roomId ?? this.roomId,
      livekitRoomName: livekitRoomName ?? this.livekitRoomName,
      participants: participants ?? this.participants,
      localParticipant: localParticipant ?? this.localParticipant,
      permissions: permissions ?? this.permissions,
      isMicMuted: isMicMuted ?? this.isMicMuted,
      isCameraMuted: isCameraMuted ?? this.isCameraMuted,
      isScreenSharing: isScreenSharing ?? this.isScreenSharing,
      isRecording: isRecording ?? this.isRecording,
      activeSpeakerId: activeSpeakerId ?? this.activeSpeakerId,
      error: error ?? this.error,
    );
  }
}
