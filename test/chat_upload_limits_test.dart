import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/pages/chat/chat_upload_limits.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ChatUploadLimits', () {
    test('uses the launch fallback when Synapse config is unavailable', () {
      expect(
        ChatUploadLimits.resolveMaxUploadSize(null),
        AppConfig.chatMaxUploadFallbackBytes,
      );
      expect(AppConfig.chatMaxUploadFallbackBytes, 50 * 1024 * 1024);
    });

    test('uses the Synapse advertised upload limit when available', () {
      expect(ChatUploadLimits.resolveMaxUploadSize(12345), 12345);
    });

    test('allows files exactly at the upload limit', () {
      expect(
        ChatUploadLimits.isOverLimit(fileSize: 50, maxUploadSize: 50),
        isFalse,
      );
    });

    test('blocks oversize files before upload unless compression will run', () {
      expect(
        ChatUploadLimits.shouldBlockBeforeUpload(
          fileSize: 51,
          maxUploadSize: 50,
          willCompressBeforeUpload: false,
        ),
        isTrue,
      );
      expect(
        ChatUploadLimits.shouldBlockBeforeUpload(
          fileSize: 51,
          maxUploadSize: 50,
          willCompressBeforeUpload: true,
        ),
        isFalse,
      );
    });
  });
}
