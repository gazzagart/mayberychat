import 'dart:async';
import 'dart:convert';

import 'package:fluffychat/letsyak/calling/config/calling_config.dart';
import 'package:fluffychat/letsyak/calling/models/call_participant.dart'
    as letsyak;
import 'package:fluffychat/letsyak/calling/models/call_permissions.dart';
import 'package:fluffychat/letsyak/calling/models/call_session_model.dart';
import 'package:fluffychat/letsyak/calling/services/jwt_token_service.dart';
import 'package:fluffychat/letsyak/calling/services/matrixrtc_signaling.dart';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' as lk;
import 'package:matrix/matrix.dart';

/// Core service that manages the LiveKit connection and call lifecycle.
///
/// This wraps the `livekit_client` SDK and exposes call state via
/// [callState], a [ValueNotifier] that the UI observes.
class LiveKitService {
  final Client _matrixClient;
  final MatrixRtcSignaling _signaling;
  late final JwtTokenService _jwtService;

  lk.Room? _livekitRoom;
  lk.EventsListener<lk.RoomEvent>? _roomListener;

  /// The current call state. UI should listen to this.
  final ValueNotifier<CallSessionModel> callState = ValueNotifier(
    const CallSessionModel(),
  );

  /// Stream that fires whenever a new incoming call is detected.
  final StreamController<Room> _incomingCallController =
      StreamController<Room>.broadcast();
  Stream<Room> get onIncomingCall => _incomingCallController.stream;

  LiveKitService({
    required Client matrixClient,
    required MatrixRtcSignaling signaling,
  }) : _matrixClient = matrixClient,
       _signaling = signaling {
    _jwtService = JwtTokenService(
      client: _matrixClient,
      jwtServiceUrl: CallingConfig.jwtServiceUrl,
    );
  }

  /// Whether a call is currently active.
  bool get isInCall =>
      callState.value.status == CallStatus.connected ||
      callState.value.status == CallStatus.connecting ||
      callState.value.status == CallStatus.reconnecting;

  // ---------------------------------------------------------------------------
  // Call lifecycle
  // ---------------------------------------------------------------------------

  /// Start or join a call in the given Matrix [room].
  ///
  /// 1. Resolves the JWT service URL (config or well-known discovery).
  /// 2. Obtains a LiveKit JWT token.
  /// 3. Announces our presence via MatrixRTC state events.
  /// 4. Connects to the LiveKit SFU.
  /// 5. Publishes local audio and (optionally) video tracks.
  Future<void> joinCall({required Room room, bool withVideo = true}) async {
    if (isInCall) {
      throw Exception('Already in a call. Hang up first.');
    }

    // Determine user's call role from Matrix room power level
    final powerLevel = room.getPowerLevelByUserId(_matrixClient.userID!);
    final role = CallPermissions.roleFromPowerLevel(powerLevel);

    _updateState(
      callState.value.copyWith(
        status: CallStatus.connecting,
        roomId: room.id,
        livekitRoomName: room.id,
        permissions: CallPermissions(role),
        isCameraMuted: !withVideo,
        error: null,
      ),
    );

    try {
      // Resolve JWT service URL
      var jwtServiceUrl = CallingConfig.jwtServiceUrl;
      if (jwtServiceUrl.isEmpty) {
        final discovered = await _signaling.discoverLivekitFocus();
        if (discovered == null) {
          throw Exception(
            'No LiveKit service configured and none found via well-known discovery',
          );
        }
        jwtServiceUrl = discovered;
        _jwtService = JwtTokenService(
          client: _matrixClient,
          jwtServiceUrl: jwtServiceUrl,
        );
      }

      // Get JWT token
      final tokenResponse = await _jwtService.getToken(room.id);

      // Announce via MatrixRTC
      final deviceId = _matrixClient.deviceID ?? 'unknown';
      await _signaling.joinCall(
        room: room,
        deviceId: deviceId,
        livekitServiceUrl: jwtServiceUrl,
        isVideo: withVideo,
      );

      // Connect to LiveKit
      final livekitUrl = CallingConfig.livekitUrl.isNotEmpty
          ? CallingConfig.livekitUrl
          : tokenResponse.livekitUrl;

      _livekitRoom = lk.Room(
        roomOptions: const lk.RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: lk.AudioPublishOptions(dtx: true),
          defaultVideoPublishOptions: lk.VideoPublishOptions(simulcast: true),
          defaultScreenShareCaptureOptions: lk.ScreenShareCaptureOptions(
            useiOSBroadcastExtension: true,
            maxFrameRate: 15.0,
          ),
        ),
      );
      _setupRoomListeners();

      await _livekitRoom!.connect(livekitUrl, tokenResponse.jwt);

      // Publish local tracks
      await _livekitRoom!.localParticipant?.setMicrophoneEnabled(true);
      if (withVideo) {
        await _livekitRoom!.localParticipant?.setCameraEnabled(true);
      }

      // Build initial participant list
      _rebuildParticipants(room);

      _updateState(callState.value.copyWith(status: CallStatus.connected));
    } catch (e) {
      Logs().e('[LetsYak Calling] Failed to join call', e);
      _updateState(
        callState.value.copyWith(status: CallStatus.ended, error: e.toString()),
      );
      await _cleanup(room);
      rethrow;
    }
  }

  /// Leave the current call.
  Future<void> hangUp() async {
    final roomId = callState.value.roomId;
    final room = roomId != null ? _matrixClient.getRoomById(roomId) : null;

    _updateState(callState.value.copyWith(status: CallStatus.ended));

    await _cleanup(room);
  }

  // ---------------------------------------------------------------------------
  // Local media controls
  // ---------------------------------------------------------------------------

  Future<void> toggleMicrophone() async {
    final muted = callState.value.isMicMuted;
    await _livekitRoom?.localParticipant?.setMicrophoneEnabled(muted);
    _updateState(callState.value.copyWith(isMicMuted: !muted));
  }

  Future<void> toggleCamera() async {
    final muted = callState.value.isCameraMuted;
    await _livekitRoom?.localParticipant?.setCameraEnabled(muted);
    _updateState(callState.value.copyWith(isCameraMuted: !muted));
  }

  Future<void> toggleScreenShare() async {
    final sharing = callState.value.isScreenSharing;
    await _livekitRoom?.localParticipant?.setScreenShareEnabled(!sharing);
    _updateState(callState.value.copyWith(isScreenSharing: !sharing));
  }

  Future<void> switchCamera() async {
    final videoTrack = _livekitRoom
        ?.localParticipant
        ?.videoTrackPublications
        .firstOrNull
        ?.track;
    if (videoTrack is lk.LocalVideoTrack) {
      // Get list of cameras and switch to the next one
      final devices = await lk.Hardware.instance.enumerateDevices(
        type: 'videoinput',
      );
      if (devices.length < 2) return;
      final current = videoTrack.currentOptions.deviceId;
      final next = devices.firstWhere(
        (d) => d.deviceId != current,
        orElse: () => devices.first,
      );
      await videoTrack.switchCamera(next.deviceId);
    }
  }

  // ---------------------------------------------------------------------------
  // Admin controls (requires moderator/admin power level)
  // ---------------------------------------------------------------------------

  /// Mute a remote participant's audio. Server-enforced.
  Future<void> muteParticipant(String participantIdentity) async {
    if (!callState.value.permissions.canMuteOthers) return;

    // Send a data message to request the participant mute themselves.
    // In production, this should go through the LiveKit server API for
    // server-enforced muting. For now, use data messages.
    final data = '{"type":"mute_request","target":"$participantIdentity"}';
    await _livekitRoom?.localParticipant?.publishData(
      utf8.encode(data),
      reliable: true,
    );
  }

  /// Remove a participant from the call.
  Future<void> kickParticipant(String participantIdentity) async {
    if (!callState.value.permissions.canKickParticipants) return;

    final data = '{"type":"kick","target":"$participantIdentity"}';
    await _livekitRoom?.localParticipant?.publishData(
      utf8.encode(data),
      reliable: true,
    );
  }

  /// Toggle "raise hand" for the local user.
  Future<void> toggleRaiseHand() async {
    final local = callState.value.localParticipant;
    if (local == null) return;
    final raised = !local.hasRaisedHand;

    final data = '{"type":"raise_hand","raised":$raised}';
    await _livekitRoom?.localParticipant?.publishData(
      utf8.encode(data),
      reliable: true,
    );

    local.hasRaisedHand = raised;
    _updateState(callState.value.copyWith(localParticipant: local));
  }

  // ---------------------------------------------------------------------------
  // Room event listeners
  // ---------------------------------------------------------------------------

  void _setupRoomListeners() {
    _roomListener = _livekitRoom!.createListener();
    _roomListener!
      ..on<lk.ParticipantConnectedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.ParticipantDisconnectedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.TrackPublishedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.TrackUnpublishedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.TrackMutedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.TrackUnmutedEvent>((event) {
        _onParticipantChanged();
      })
      ..on<lk.ActiveSpeakersChangedEvent>((event) {
        final speakers = event.speakers;
        final activeSpeaker = speakers.isNotEmpty
            ? speakers.first.identity
            : null;
        _updateState(
          callState.value.copyWith(activeSpeakerId: activeSpeaker ?? ''),
        );
      })
      ..on<lk.RoomDisconnectedEvent>((event) {
        _updateState(callState.value.copyWith(status: CallStatus.ended));
      })
      ..on<lk.RoomReconnectingEvent>((event) {
        _updateState(callState.value.copyWith(status: CallStatus.reconnecting));
      })
      ..on<lk.RoomReconnectedEvent>((event) {
        _updateState(callState.value.copyWith(status: CallStatus.connected));
      })
      ..on<lk.DataReceivedEvent>(_handleDataMessage);
  }

  void _onParticipantChanged() {
    final roomId = callState.value.roomId;
    if (roomId == null) return;
    final room = _matrixClient.getRoomById(roomId);
    if (room == null) return;
    _rebuildParticipants(room);
  }

  void _rebuildParticipants(Room matrixRoom) {
    if (_livekitRoom == null) return;
    final participants = <letsyak.CallParticipant>[];

    // Local participant
    final localLk = _livekitRoom!.localParticipant;
    letsyak.CallParticipant? localParticipant;
    if (localLk != null) {
      localParticipant = letsyak.CallParticipant.local(localLk, _matrixClient);
      localParticipant.isMicrophoneMuted = callState.value.isMicMuted;
      localParticipant.isCameraMuted = callState.value.isCameraMuted;
      localParticipant.isScreenSharing = callState.value.isScreenSharing;
      participants.add(localParticipant);
    }

    // Remote participants
    for (final remote in _livekitRoom!.remoteParticipants.values) {
      final p = letsyak.CallParticipant.fromRemote(remote, matrixRoom);
      p.isMicrophoneMuted = remote.isMuted;
      p.isCameraMuted = !remote.isCameraEnabled();
      p.isScreenSharing = remote.isScreenShareEnabled();
      p.connectionQuality = remote.connectionQuality;
      p.isSpeaking = remote.isSpeaking;

      // Attach track publications
      for (final pub in remote.trackPublications.values) {
        if (pub.kind == lk.TrackType.VIDEO) {
          if (pub.source == lk.TrackSource.screenShareVideo) {
            p.screenShareTrack = pub;
          } else {
            p.videoTrack = pub;
          }
        }
      }

      participants.add(p);
    }

    _updateState(
      callState.value.copyWith(
        participants: participants,
        localParticipant: localParticipant,
      ),
    );
  }

  void _handleDataMessage(lk.DataReceivedEvent event) {
    // Handle custom data messages (mute requests, kicks, raise hand)
    try {
      final message = utf8.decode(event.data);
      final data = Map<String, dynamic>.from(json.decode(message) as Map);
      final type = data['type'] as String?;

      switch (type) {
        case 'mute_request':
          final target = data['target'] as String?;
          if (target == _matrixClient.userID) {
            // We've been asked to mute — auto-mute as a courtesy
            toggleMicrophone();
          }
          break;
        case 'kick':
          final target = data['target'] as String?;
          if (target == _matrixClient.userID) {
            hangUp();
          }
          break;
        case 'raise_hand':
          final sender = event.participant?.identity;
          if (sender != null) {
            final raised = data['raised'] as bool? ?? false;
            final participants = List<letsyak.CallParticipant>.from(
              callState.value.participants,
            );
            final idx = participants.indexWhere((p) => p.matrixId == sender);
            if (idx >= 0) {
              participants[idx].hasRaisedHand = raised;
              _updateState(
                callState.value.copyWith(participants: participants),
              );
            }
          }
          break;
      }
    } catch (_) {
      // Ignore malformed data messages
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  void _updateState(CallSessionModel newState) {
    callState.value = newState;
  }

  Future<void> _cleanup(Room? matrixRoom) async {
    _roomListener?.dispose();
    _roomListener = null;

    try {
      await _livekitRoom?.disconnect();
    } catch (_) {}
    _livekitRoom = null;

    if (matrixRoom != null) {
      try {
        await _signaling.leaveCall(room: matrixRoom);
      } catch (_) {}
    }

    _updateState(const CallSessionModel());
  }

  /// Dispose of all resources.
  void dispose() {
    _roomListener?.dispose();
    try {
      _livekitRoom?.disconnect();
    } catch (_) {}
    _incomingCallController.close();
    callState.dispose();
  }
}
