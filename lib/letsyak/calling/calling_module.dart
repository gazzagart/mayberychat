import 'package:fluffychat/letsyak/calling/config/calling_config.dart';
import 'package:fluffychat/letsyak/calling/services/call_notification_service.dart';
import 'package:fluffychat/letsyak/calling/services/livekit_service.dart';
import 'package:fluffychat/letsyak/calling/services/matrixrtc_signaling.dart';
import 'package:fluffychat/letsyak/calling/services/recording_service.dart';
import 'package:matrix/matrix.dart';

/// Entry point for the LetsYak calling module.
///
/// Initializes all calling services and exposes them to the app.
/// Created by [MatrixState] when the calling feature flag is enabled.
class LetsYakCallingModule {
  late final MatrixRtcSignaling signaling;
  late final LiveKitService livekitService;
  late final CallNotificationService notificationService;
  RecordingService? recordingService;

  LetsYakCallingModule._();

  /// Create and initialize the calling module.
  ///
  /// Returns `null` if the feature is disabled or not configured.
  static LetsYakCallingModule? init({required Client client}) {
    if (!CallingConfig.isEnabled) {
      Logs().i('[LetsYak Calling] Feature flag disabled — module not loaded');
      return null;
    }

    Logs().i('[LetsYak Calling] Initializing calling module...');

    final module = LetsYakCallingModule._();

    // Signaling
    module.signaling = MatrixRtcSignaling(client: client);

    // Core LiveKit service
    module.livekitService = LiveKitService(
      matrixClient: client,
      signaling: module.signaling,
    );

    // Notification sounds
    module.notificationService = CallNotificationService();

    // Recording (only if a recording API URL is configured)
    // For now, the recording API URL will be derived from the JWT service URL.
    // Users can override this later via config.
    final jwtUrl = CallingConfig.jwtServiceUrl;
    if (jwtUrl.isNotEmpty) {
      // Assume recording API is at the same host as the JWT service
      final jwtUri = Uri.tryParse(jwtUrl);
      if (jwtUri != null) {
        final recordingUrl = jwtUri.replace(path: '/recording').toString();
        module.recordingService = RecordingService(
          client: client,
          recordingApiUrl: recordingUrl,
        );
      }
    }

    Logs().i('[LetsYak Calling] Module initialized successfully');
    return module;
  }

  /// Dispose all resources.
  void dispose() {
    livekitService.dispose();
    notificationService.dispose();
  }
}
