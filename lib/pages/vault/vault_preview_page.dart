import 'package:chewie/chewie.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';
import 'package:video_player/video_player.dart';

enum VaultPreviewType { image, video, pdf, download }

enum VaultPreviewAction { shareLink, manageShares, delete }

typedef VaultDownloadUrlLoader = Future<String> Function(VaultFile file);
typedef VaultPdfPreviewBuilder =
    Widget Function(BuildContext context, String downloadUrl);

VaultPreviewType vaultPreviewTypeFor(VaultFile file) {
  if (file.isFolder) return VaultPreviewType.download;

  final mimeType = (file.mimeType ?? '').toLowerCase();
  final extension = file.extension.toLowerCase();
  if (mimeType.startsWith('image/') && mimeType != 'image/svg+xml') {
    return VaultPreviewType.image;
  }
  if (_rasterImageExtensions.contains(extension)) {
    return VaultPreviewType.image;
  }
  if (mimeType.startsWith('video/')) return VaultPreviewType.video;
  if (_videoExtensions.contains(extension)) return VaultPreviewType.video;
  if (mimeType == 'application/pdf' || extension == 'pdf') {
    return VaultPreviewType.pdf;
  }
  return VaultPreviewType.download;
}

const _rasterImageExtensions = {'jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'};

const _videoExtensions = {'mp4', 'mov', 'm4v', 'webm'};

class VaultPreviewPage extends StatefulWidget {
  final VaultFile file;
  final VaultDownloadUrlLoader loadDownloadUrl;
  final VaultPdfPreviewBuilder? pdfPreviewBuilder;

  const VaultPreviewPage({
    required this.file,
    required this.loadDownloadUrl,
    this.pdfPreviewBuilder,
    super.key,
  });

  @override
  State<VaultPreviewPage> createState() => _VaultPreviewPageState();
}

class _VaultPreviewPageState extends State<VaultPreviewPage> {
  late Future<String> _downloadUrlFuture;

  @override
  void initState() {
    super.initState();
    _downloadUrlFuture = _loadDownloadUrl();
  }

  Future<String> _loadDownloadUrl() async {
    await Future<void>.delayed(Duration.zero);
    return widget.loadDownloadUrl(widget.file);
  }

  void _retry() {
    setState(() {
      _downloadUrlFuture = _loadDownloadUrl();
    });
  }

  void _openExternally(String downloadUrl) {
    UrlLauncher(context, downloadUrl).launchUrl();
  }

  void _selectAction(VaultPreviewAction action) {
    Navigator.of(context).pop(action);
  }

  @override
  Widget build(BuildContext context) {
    final previewType = vaultPreviewTypeFor(widget.file);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          FutureBuilder<String>(
            future: _downloadUrlFuture,
            builder: (context, snapshot) => IconButton(
              tooltip: 'Open externally',
              icon: const Icon(Icons.open_in_new),
              onPressed: snapshot.hasData
                  ? () => _openExternally(snapshot.data!)
                  : null,
            ),
          ),
          PopupMenuButton<VaultPreviewAction>(
            tooltip: 'File actions',
            onSelected: _selectAction,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: VaultPreviewAction.shareLink,
                child: ListTile(
                  leading: Icon(Icons.share_outlined),
                  title: Text('Share link'),
                ),
              ),
              PopupMenuItem(
                value: VaultPreviewAction.manageShares,
                child: ListTile(
                  leading: Icon(Icons.link_outlined),
                  title: Text('Manage shares'),
                ),
              ),
              PopupMenuItem(
                value: VaultPreviewAction.delete,
                child: ListTile(
                  leading: Icon(Icons.delete_outline),
                  title: Text('Delete'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<String>(
          future: _downloadUrlFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const _PreviewLoading();
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _PreviewError(onRetry: _retry);
            }

            final downloadUrl = snapshot.data!;
            return switch (previewType) {
              VaultPreviewType.image => _VaultImagePreview(
                downloadUrl: downloadUrl,
                fileName: widget.file.name,
              ),
              VaultPreviewType.video => _VaultVideoPreview(
                downloadUrl: downloadUrl,
                fileName: widget.file.name,
                onOpenExternally: () => _openExternally(downloadUrl),
              ),
              VaultPreviewType.pdf =>
                widget.pdfPreviewBuilder?.call(context, downloadUrl) ??
                    _VaultPdfPreview(downloadUrl: downloadUrl),
              VaultPreviewType.download => _UnsupportedPreview(
                onOpenExternally: () => _openExternally(downloadUrl),
              ),
            };
          },
        ),
      ),
    );
  }
}

class _PreviewLoading extends StatelessWidget {
  const _PreviewLoading();

  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator.adaptive());
}

class _PreviewError extends StatelessWidget {
  final VoidCallback onRetry;

  const _PreviewError({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.broken_image_outlined, color: Colors.white70, size: 48),
          SizedBox(height: 16),
          Text(
            'Preview could not be loaded.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: Icon(Icons.refresh),
            label: Text('Retry'),
          ),
        ],
      ),
    ),
  );
}

class _VaultImagePreview extends StatelessWidget {
  final String downloadUrl;
  final String fileName;

  const _VaultImagePreview({required this.downloadUrl, required this.fileName});

  @override
  Widget build(BuildContext context) => Center(
    child: InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Image.network(
        downloadUrl,
        semanticLabel: fileName,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          final expectedBytes = loadingProgress.expectedTotalBytes;
          return Center(
            child: CircularProgressIndicator.adaptive(
              value: expectedBytes == null
                  ? null
                  : loadingProgress.cumulativeBytesLoaded / expectedBytes,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) => const _ImageLoadError(),
      ),
    ),
  );
}

class _ImageLoadError extends StatelessWidget {
  const _ImageLoadError();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(32),
    child: Text(
      'Image could not be displayed.',
      textAlign: TextAlign.center,
      style: TextStyle(color: Colors.white),
    ),
  );
}

class _VaultVideoPreview extends StatefulWidget {
  final String downloadUrl;
  final String fileName;
  final VoidCallback onOpenExternally;

  const _VaultVideoPreview({
    required this.downloadUrl,
    required this.fileName,
    required this.onOpenExternally,
  });

  @override
  State<_VaultVideoPreview> createState() => _VaultVideoPreviewState();
}

class _VaultVideoPreviewState extends State<_VaultVideoPreview> {
  ChewieController? _chewieController;
  VideoPlayerController? _videoPlayerController;
  Object? _error;

  bool get _supportsVideoPlayer =>
      !PlatformInfos.isWindows && !PlatformInfos.isLinux;

  @override
  void initState() {
    super.initState();
    if (_supportsVideoPlayer) {
      _initializeVideo();
    }
  }

  Future<void> _initializeVideo() async {
    final videoPlayerController = VideoPlayerController.networkUrl(
      Uri.parse(widget.downloadUrl),
    );
    try {
      await videoPlayerController.initialize();
      if (!mounted) {
        await videoPlayerController.dispose();
        return;
      }
      setState(() {
        _videoPlayerController = videoPlayerController;
        _chewieController = ChewieController(
          videoPlayerController: videoPlayerController,
          autoPlay: true,
          autoInitialize: true,
          showControlsOnInitialize: false,
          aspectRatio: videoPlayerController.value.aspectRatio,
        );
      });
    } catch (error) {
      await videoPlayerController.dispose();
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoPlayerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_supportsVideoPlayer) {
      return _UnsupportedVideoPreview(
        onOpenExternally: widget.onOpenExternally,
      );
    }
    if (_error != null) {
      return _VideoError(onOpenExternally: widget.onOpenExternally);
    }

    final chewieController = _chewieController;
    if (chewieController == null) return const _PreviewLoading();

    return Center(child: Chewie(controller: chewieController));
  }
}

class _VaultPdfPreview extends StatelessWidget {
  final String downloadUrl;

  const _VaultPdfPreview({required this.downloadUrl});

  @override
  Widget build(BuildContext context) => PdfViewer.uri(
    Uri.parse(downloadUrl),
    params: PdfViewerParams(
      backgroundColor: Colors.black,
      margin: 12,
      pageDropShadow: const BoxShadow(
        color: Colors.black54,
        blurRadius: 8,
        offset: Offset(0, 2),
      ),
      loadingBannerBuilder: (context, bytesDownloaded, totalBytes) =>
          _PdfLoadingBanner(
            bytesDownloaded: bytesDownloaded,
            totalBytes: totalBytes,
          ),
      errorBannerBuilder: (context, error, stackTrace, documentRef) =>
          const _PdfLoadError(),
    ),
  );
}

class _PdfLoadingBanner extends StatelessWidget {
  final int bytesDownloaded;
  final int? totalBytes;

  const _PdfLoadingBanner({
    required this.bytesDownloaded,
    required this.totalBytes,
  });

  @override
  Widget build(BuildContext context) {
    final totalBytes = this.totalBytes;
    final progress = totalBytes == null || totalBytes == 0
        ? null
        : bytesDownloaded / totalBytes;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: CircularProgressIndicator.adaptive(value: progress),
      ),
    );
  }
}

class _PdfLoadError extends StatelessWidget {
  const _PdfLoadError();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.topCenter,
    child: Padding(
      padding: EdgeInsets.all(16),
      child: Text(
        'PDF could not be displayed. Use Open externally to view it.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
}

class _UnsupportedVideoPreview extends StatelessWidget {
  final VoidCallback onOpenExternally;

  const _UnsupportedVideoPreview({required this.onOpenExternally});

  @override
  Widget build(BuildContext context) => _PreviewMessage(
    icon: Icons.video_file_outlined,
    message: 'Video preview is not available on this platform.',
    actionLabel: 'Open externally',
    onAction: onOpenExternally,
  );
}

class _VideoError extends StatelessWidget {
  final VoidCallback onOpenExternally;

  const _VideoError({required this.onOpenExternally});

  @override
  Widget build(BuildContext context) => _PreviewMessage(
    icon: Icons.video_file_outlined,
    message: 'Video could not be played.',
    actionLabel: 'Open externally',
    onAction: onOpenExternally,
  );
}

class _UnsupportedPreview extends StatelessWidget {
  final VoidCallback onOpenExternally;

  const _UnsupportedPreview({required this.onOpenExternally});

  @override
  Widget build(BuildContext context) => _PreviewMessage(
    icon: Icons.insert_drive_file_outlined,
    message: 'Preview is not available for this file type.',
    actionLabel: 'Open externally',
    onAction: onOpenExternally,
  );
}

class _PreviewMessage extends StatelessWidget {
  final IconData icon;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _PreviewMessage({
    required this.icon,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white70, size: 48),
          SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
          SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAction,
            icon: Icon(Icons.open_in_new),
            label: Text(actionLabel),
          ),
        ],
      ),
    ),
  );
}
