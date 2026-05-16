import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/utils/size_string.dart';

abstract class ChatUploadLimits {
  static const int fallbackMaxUploadSizeBytes =
      AppConfig.chatMaxUploadFallbackBytes;

  static int resolveMaxUploadSize(int? serverMaxUploadSize) =>
      serverMaxUploadSize ?? fallbackMaxUploadSizeBytes;

  static bool isOverLimit({
    required int fileSize,
    required int maxUploadSize,
  }) => fileSize > maxUploadSize;

  static bool shouldBlockBeforeUpload({
    required int fileSize,
    required int maxUploadSize,
    required bool willCompressBeforeUpload,
  }) =>
      isOverLimit(fileSize: fileSize, maxUploadSize: maxUploadSize) &&
      !willCompressBeforeUpload;

  static String formatBytes(int bytes) => bytes.toDouble().sizeString;
}
