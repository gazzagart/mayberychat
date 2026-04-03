import 'package:fluffychat/config/setting_keys.dart';

/// Configuration for the LetsYak calling module.
///
/// Reads LiveKit and JWT service URLs from [AppSettings].
/// Falls back to MatrixRTC well-known discovery if URLs are not set.
class CallingConfig {
  CallingConfig._();

  static bool get isEnabled => AppSettings.letsyakCalling.value;

  static String get livekitUrl => AppSettings.letsyakLivekitUrl.value;

  static String get jwtServiceUrl => AppSettings.letsyakJwtServiceUrl.value;

  static bool get hasServerConfig =>
      livekitUrl.isNotEmpty && jwtServiceUrl.isNotEmpty;
}
