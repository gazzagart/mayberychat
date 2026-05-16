import 'package:async/async.dart' show Result;
import 'package:cross_file/cross_file.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/localized_exception_extension.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_file_extension.dart';
import 'package:fluffychat/utils/other_party_can_receive.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/adaptive_dialog_action.dart';
import 'package:fluffychat/widgets/adaptive_dialogs/dialog_text_field.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart' hide Result;
import 'package:mime/mime.dart';

import '../../utils/resize_video.dart';
import 'chat_upload_limits.dart';

class SendFileDialog extends StatefulWidget {
  final Room room;
  final List<XFile> files;
  final BuildContext outerContext;
  final String? threadLastEventId, threadRootEventId;

  const SendFileDialog({
    required this.room,
    required this.files,
    required this.outerContext,
    required this.threadLastEventId,
    required this.threadRootEventId,
    super.key,
  });

  @override
  SendFileDialogState createState() => SendFileDialogState();
}

class SendFileDialogState extends State<SendFileDialog> {
  bool compress = true;

  /// Images smaller than 20kb don't need compression.
  static const int minSizeToCompress = 20 * 1000;

  final TextEditingController _labelTextController = TextEditingController();
  late final Future<_ChatUploadPreflight> _preflightFuture;

  @override
  void initState() {
    super.initState();
    _preflightFuture = _loadPreflight();
  }

  Future<_ChatUploadPreflight> _loadPreflight() async {
    final clientConfig = await Result.capture(widget.room.client.getConfig());
    final maxUploadSize = ChatUploadLimits.resolveMaxUploadSize(
      clientConfig.asValue?.value.mUploadSize,
    );
    final files = await Future.wait(
      widget.files.map(
        (file) async => _ChatUploadFileInfo(length: await file.length()),
      ),
    );
    return _ChatUploadPreflight(maxUploadSize: maxUploadSize, files: files);
  }

  bool _willTryVideoCompression(String? mimeType, int length) =>
      PlatformInfos.isMobile &&
      mimeType != null &&
      mimeType.startsWith('video') &&
      length > minSizeToCompress &&
      compress;

  Future<void> _send() async {
    final scaffoldMessenger = ScaffoldMessenger.of(widget.outerContext);
    final l10n = L10n.of(context);

    try {
      if (!widget.room.otherPartyCanReceiveMessages) {
        throw OtherPartyCanNotReceiveMessages();
      }
      scaffoldMessenger.showLoadingSnackBar(l10n.prepareSendingAttachment);
      Navigator.of(context, rootNavigator: false).pop();
      final preflight = await _preflightFuture;
      final maxUploadSize = preflight.maxUploadSize;

      for (var index = 0; index < widget.files.length; index++) {
        final xfile = widget.files[index];
        final MatrixFile file;
        MatrixImageFile? thumbnail;
        final length = preflight.files[index].length;
        final mimeType = xfile.mimeType ?? lookupMimeType(xfile.path);
        final willTryVideoCompression = _willTryVideoCompression(
          mimeType,
          length,
        );

        if (ChatUploadLimits.shouldBlockBeforeUpload(
          fileSize: length,
          maxUploadSize: maxUploadSize,
          willCompressBeforeUpload: willTryVideoCompression,
        )) {
          throw FileTooBigMatrixException(length, maxUploadSize);
        }

        // Generate video thumbnail
        if (PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video')) {
          scaffoldMessenger.showLoadingSnackBar(l10n.generatingVideoThumbnail);
          thumbnail = await xfile.getVideoThumbnail();
        }

        // If file is a video, shrink it!
        if (PlatformInfos.isMobile &&
            mimeType != null &&
            mimeType.startsWith('video')) {
          scaffoldMessenger.showLoadingSnackBar(l10n.compressVideo);
          file = await xfile.getVideoInfo(
            compress: length > minSizeToCompress && compress,
          );
        } else {
          // Else we just create a MatrixFile
          file = MatrixFile(
            bytes: await xfile.readAsBytes(),
            name: xfile.name,
            mimeType: mimeType,
          ).detectFileType;
        }

        if (file.bytes.length > maxUploadSize) {
          throw FileTooBigMatrixException(length, maxUploadSize);
        }

        if (widget.files.length > 1) {
          scaffoldMessenger.showLoadingSnackBar(
            l10n.sendingAttachmentCountOfCount(index + 1, widget.files.length),
          );
        }

        final label = _labelTextController.text.trim();

        try {
          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? 1600 : null,
            extraContent: label.isEmpty ? null : {'body': label},
            threadRootEventId: widget.threadRootEventId,
            threadLastEventId: widget.threadLastEventId,
          );
        } on MatrixException catch (e) {
          final retryAfterMs = e.retryAfterMs;
          if (e.error != MatrixError.M_LIMIT_EXCEEDED || retryAfterMs == null) {
            rethrow;
          }
          final retryAfterDuration = Duration(
            milliseconds: retryAfterMs + 1000,
          );

          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(
                l10n.serverLimitReached(retryAfterDuration.inSeconds),
              ),
            ),
          );
          await Future.delayed(retryAfterDuration);

          scaffoldMessenger.showLoadingSnackBar(l10n.sendingAttachment);

          await widget.room.sendFileEvent(
            file,
            thumbnail: thumbnail,
            shrinkImageMaxDimension: compress ? 1600 : null,
            extraContent: label.isEmpty ? null : {'body': label},
          );
        }
      }
      scaffoldMessenger.clearSnackBars();
    } catch (e) {
      scaffoldMessenger.clearSnackBars();
      if (!mounted || !widget.outerContext.mounted) rethrow;
      final theme = Theme.of(context);
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: theme.colorScheme.errorContainer,
          closeIconColor: theme.colorScheme.onErrorContainer,
          content: Text(
            e.toLocalizedString(widget.outerContext),
            style: TextStyle(color: theme.colorScheme.onErrorContainer),
          ),
          duration: const Duration(seconds: 30),
          showCloseIcon: true,
        ),
      );
      rethrow;
    }

    return;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    var sendStr = L10n.of(context).sendFile;
    final uniqueFileType = widget.files
        .map((file) => file.mimeType ?? lookupMimeType(file.name))
        .map((mimeType) => mimeType?.split('/').first)
        .toSet()
        .singleOrNull;

    final fileName = widget.files.length == 1
        ? widget.files.single.name
        : L10n.of(context).countFiles(widget.files.length);
    final fileTypes = widget.files
        .map((file) => file.name.split('.').last)
        .toSet()
        .join(', ')
        .toUpperCase();

    if (uniqueFileType == 'image') {
      if (widget.files.length == 1) {
        sendStr = L10n.of(context).sendImage;
      } else {
        sendStr = L10n.of(context).sendImages(widget.files.length);
      }
    } else if (uniqueFileType == 'audio') {
      sendStr = L10n.of(context).sendAudio;
    } else if (uniqueFileType == 'video') {
      sendStr = L10n.of(context).sendVideo;
    }

    final compressionSupported =
        uniqueFileType != 'video' || PlatformInfos.isMobile;

    return FutureBuilder<_ChatUploadPreflight>(
      future: _preflightFuture,
      builder: (context, snapshot) {
        final preflight = snapshot.data;
        final sizeString =
            preflight?.combinedSizeString ??
            L10n.of(context).calculatingFileSize;
        final oversizedFiles = preflight?.oversizedFiles ?? const [];
        final canTryCompression =
            uniqueFileType == 'video' &&
            PlatformInfos.isMobile &&
            compressionSupported &&
            compress;
        final blocksSend = oversizedFiles.isNotEmpty && !canTryCompression;

        return AlertDialog.adaptive(
          title: Text(sendStr),
          content: SizedBox(
            width: 256,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                children: [
                  const SizedBox(height: 12),
                  if (uniqueFileType == 'image' && preflight == null)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        height: 256,
                        child: Center(
                          child: CircularProgressIndicator.adaptive(),
                        ),
                      ),
                    ),
                  if (uniqueFileType == 'image' &&
                      preflight != null &&
                      !blocksSend)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: SizedBox(
                        height: 256,
                        child: Center(
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: widget.files.length,
                            scrollDirection: Axis.horizontal,
                            itemBuilder: (context, i) => Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: Material(
                                borderRadius: BorderRadius.circular(
                                  AppConfig.borderRadius / 2,
                                ),
                                color: Colors.black,
                                clipBehavior: Clip.hardEdge,
                                child: FutureBuilder(
                                  future: widget.files[i].readAsBytes(),
                                  builder: (context, snapshot) {
                                    final bytes = snapshot.data;
                                    if (bytes == null) {
                                      return const Center(
                                        child:
                                            CircularProgressIndicator.adaptive(),
                                      );
                                    }
                                    if (snapshot.error != null) {
                                      Logs().w(
                                        'Unable to preview image',
                                        snapshot.error,
                                        snapshot.stackTrace,
                                      );
                                      return const Center(
                                        child: SizedBox(
                                          width: 256,
                                          height: 256,
                                          child: Icon(
                                            Icons.broken_image_outlined,
                                            size: 64,
                                          ),
                                        ),
                                      );
                                    }
                                    return Image.memory(
                                      bytes,
                                      height: 256,
                                      width: widget.files.length == 1
                                          ? 256 - 36
                                          : null,
                                      fit: BoxFit.contain,
                                      errorBuilder: (context, e, s) {
                                        Logs().w(
                                          'Unable to preview image',
                                          e,
                                          s,
                                        );
                                        return const Center(
                                          child: SizedBox(
                                            width: 256,
                                            height: 256,
                                            child: Icon(
                                              Icons.broken_image_outlined,
                                              size: 64,
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (uniqueFileType != 'image' || blocksSend)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Row(
                        children: [
                          Icon(
                            uniqueFileType == null
                                ? Icons.description_outlined
                                : uniqueFileType == 'video'
                                ? Icons.video_file_outlined
                                : uniqueFileType == 'audio'
                                ? Icons.audio_file_outlined
                                : Icons.description_outlined,
                            size: 32,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisSize: .min,
                              crossAxisAlignment: .start,
                              children: [
                                Text(
                                  fileName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                Text(
                                  '$sizeString - $fileTypes',
                                  style: theme.textTheme.labelSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (widget.files.length == 1)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: DialogTextField(
                        controller: _labelTextController,
                        labelText: L10n.of(context).optionalMessage,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 255,
                        counterText: '',
                      ),
                    ),
                  // Workaround for SwitchListTile.adaptive crashes in CupertinoDialog
                  if ({'image', 'video'}.contains(uniqueFileType))
                    Row(
                      crossAxisAlignment: .center,
                      children: [
                        if ({
                          TargetPlatform.iOS,
                          TargetPlatform.macOS,
                        }.contains(theme.platform))
                          CupertinoSwitch(
                            value: compressionSupported && compress,
                            onChanged: compressionSupported
                                ? (v) => setState(() => compress = v)
                                : null,
                          )
                        else
                          Switch.adaptive(
                            value: compressionSupported && compress,
                            onChanged: compressionSupported
                                ? (v) => setState(() => compress = v)
                                : null,
                          ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            mainAxisSize: .min,
                            crossAxisAlignment: .start,
                            children: [
                              Row(
                                mainAxisSize: .min,
                                children: [
                                  Text(
                                    L10n.of(context).compress,
                                    style: theme.textTheme.titleMedium,
                                    textAlign: TextAlign.left,
                                  ),
                                ],
                              ),
                              if (!compress)
                                Text(
                                  ' ($sizeString)',
                                  style: theme.textTheme.labelSmall,
                                ),
                              if (!compressionSupported)
                                Text(
                                  L10n.of(context).notSupportedOnThisDevice,
                                  style: theme.textTheme.labelSmall,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  if (preflight != null && oversizedFiles.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: _UploadLimitWarning(
                        maxUploadSize: preflight.maxUploadSize,
                        canTryCompression: canTryCompression,
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            AdaptiveDialogAction(
              onPressed: () =>
                  Navigator.of(context, rootNavigator: false).pop(),
              child: Text(L10n.of(context).cancel),
            ),
            AdaptiveDialogAction(
              onPressed: preflight == null || blocksSend ? null : _send,
              child: Text(L10n.of(context).send),
            ),
          ],
        );
      },
    );
  }
}

class _ChatUploadPreflight {
  final int maxUploadSize;
  final List<_ChatUploadFileInfo> files;

  const _ChatUploadPreflight({
    required this.maxUploadSize,
    required this.files,
  });

  List<_ChatUploadFileInfo> get oversizedFiles => files
      .where(
        (file) => ChatUploadLimits.isOverLimit(
          fileSize: file.length,
          maxUploadSize: maxUploadSize,
        ),
      )
      .toList(growable: false);

  String get combinedSizeString => ChatUploadLimits.formatBytes(
    files.fold<int>(0, (total, file) => total + file.length),
  );
}

class _ChatUploadFileInfo {
  final int length;

  const _ChatUploadFileInfo({required this.length});
}

class _UploadLimitWarning extends StatelessWidget {
  final int maxUploadSize;
  final bool canTryCompression;

  const _UploadLimitWarning({
    required this.maxUploadSize,
    required this.canTryCompression,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = ChatUploadLimits.formatBytes(maxUploadSize);
    final text = canTryCompression
        ? 'This video is larger than the $max chat limit. LetsYak will try to compress it before uploading; if it is still too large, it will not be sent.'
        : L10n.of(context).fileIsTooBigForServer(max);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppConfig.borderRadius / 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline,
              size: 20,
              color: theme.colorScheme.onErrorContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension on ScaffoldMessengerState {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> showLoadingSnackBar(
    String title,
  ) {
    clearSnackBars();
    return showSnackBar(
      SnackBar(
        duration: const Duration(minutes: 5),
        dismissDirection: DismissDirection.none,
        content: Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text(title),
          ],
        ),
      ),
    );
  }
}
