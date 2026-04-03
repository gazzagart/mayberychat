import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Helper for requesting camera and microphone permissions
/// before joining a call.
///
/// On mobile, the `livekit_client` SDK requests permissions automatically
/// when media tracks are created. This helper exists for any pre-flight
/// checks needed before entering the lobby.
class CallPermissionsHelper {
  /// Check if we can likely request media permissions.
  ///
  /// On web, the browser handles permissions natively.
  /// On mobile, LiveKit's `LocalVideoTrack.createCameraTrack()` and
  /// `LocalAudioTrack.create()` trigger the OS permission dialogs
  /// automatically. This method returns `true` in most cases — if
  /// permissions are actually denied, the track creation will throw
  /// and we handle it at the call site.
  static Future<bool> canRequestMedia() async {
    if (kIsWeb) return true;
    // On native, LiveKit handles permission prompts internally.
    // We return true and let the actual track creation surface errors.
    Logs().v('[LetsYak] Permission check: deferring to LiveKit SDK');
    return true;
  }
}
