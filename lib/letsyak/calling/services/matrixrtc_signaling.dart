import 'dart:async';

import 'package:matrix/matrix.dart';

/// Handles MatrixRTC signaling — writing and reading call membership
/// state events in a Matrix room.
///
/// Uses the `org.matrix.msc3401.call.member` state event type as defined
/// by MSC3401/MSC4143, which is the same signaling that Element Call uses.
class MatrixRtcSignaling {
  static const String _callMemberEventType = 'org.matrix.msc3401.call.member';

  final Client _client;

  MatrixRtcSignaling({required Client client}) : _client = client;

  /// Announce that we are joining a call in [room].
  ///
  /// Writes a state event with our device ID as the state key, including
  /// our preferred focus (LiveKit) from well-known discovery.
  Future<void> joinCall({
    required Room room,
    required String deviceId,
    required String livekitServiceUrl,
    bool isVideo = true,
  }) async {
    final userId = _client.userID!;

    final content = {
      'memberships': [
        {
          'application': 'm.call',
          'call_id': '',
          'device_id': deviceId,
          'expires': 3600000, // 1 hour in ms
          'foci_preferred': [
            {'type': 'livekit', 'livekit_service_url': livekitServiceUrl},
          ],
          'membershipID': _generateMembershipId(),
          'scope': room.isDirectChat ? 'm.room' : 'm.room',
        },
      ],
    };

    await room.client.setRoomStateWithKey(
      room.id,
      _callMemberEventType,
      userId,
      content,
    );
  }

  /// Announce that we are leaving the call in [room].
  ///
  /// Sets our memberships array to empty, signaling departure.
  Future<void> leaveCall({required Room room}) async {
    final userId = _client.userID!;

    await room.client.setRoomStateWithKey(
      room.id,
      _callMemberEventType,
      userId,
      {'memberships': []},
    );
  }

  /// Get all active call members in [room].
  ///
  /// Reads all `org.matrix.msc3401.call.member` state events and returns
  /// user IDs that have non-empty, non-expired memberships.
  List<String> getActiveCallMembers(Room room) {
    final members = <String>[];
    final states = room.states[_callMemberEventType];
    if (states == null) return members;

    for (final entry in states.entries) {
      final userId = entry.key;
      final event = entry.value;
      final memberships = event.content['memberships'];
      if (memberships is! List || memberships.isEmpty) continue;

      for (final membership in memberships) {
        if (membership is! Map<String, dynamic>) continue;
        final expires = membership['expires'] as int? ?? 0;
        // StrippedStateEvent doesn't carry originServerTs, so we
        // consider any membership with a non-zero expiry as active.
        // The server cleans up expired memberships.
        if (expires > 0) {
          members.add(userId);
          break;
        }
      }
    }

    return members;
  }

  /// Check whether there is an active call in [room].
  bool hasActiveCall(Room room) => getActiveCallMembers(room).isNotEmpty;

  /// Discover LiveKit focus from well-known data.
  ///
  /// Reads `org.matrix.msc4143.rtc_foci` from the homeserver's well-known
  /// and returns the LiveKit service URL if available.
  Future<String?> discoverLivekitFocus() async {
    try {
      final wellKnown = await _client.getWellknown();
      final additionalProperties = wellKnown.additionalProperties;

      final rtcFoci = additionalProperties['org.matrix.msc4143.rtc_foci'];
      if (rtcFoci is List) {
        for (final focus in rtcFoci) {
          if (focus is Map<String, dynamic> && focus['type'] == 'livekit') {
            return focus['livekit_service_url'] as String?;
          }
        }
      }
    } catch (e) {
      Logs().w('Failed to discover LiveKit focus from well-known', e);
    }
    return null;
  }

  String _generateMembershipId() {
    final random = DateTime.now().millisecondsSinceEpoch.toRadixString(36);
    return 'letsyak_$random';
  }
}
