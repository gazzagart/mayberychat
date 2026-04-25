import 'dart:async';

import 'package:fluffychat/pages/vault/vault_folder_dialog.dart';
import 'package:fluffychat/pages/vault/vault_manage_shares_dialog.dart';
import 'package:fluffychat/pages/vault/vault_page_view.dart';
import 'package:fluffychat/pages/vault/vault_preview_page.dart';
import 'package:fluffychat/pages/vault/vault_share_dialog.dart';
import 'package:fluffychat/pages/vault/vault_upload_dialog.dart';
import 'package:fluffychat/utils/file_selector.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/utils/vault/vault_event_content.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart' show EventTypes, Logs;

/// Controller and entry point for the vault file browser.
///
/// When [pickerMode] is true, selecting a file returns it via Navigator.pop
/// instead of opening a preview. This is used when attaching from chat.
class VaultPage extends StatefulWidget {
  final bool pickerMode;
  final String? roomId;

  const VaultPage({this.pickerMode = false, this.roomId, super.key});

  @override
  State<VaultPage> createState() => VaultPageController();
}

class VaultPageController extends State<VaultPage>
    with SingleTickerProviderStateMixin {
  late VaultApi api;
  List<VaultFile> files = [];
  VaultQuota quota = VaultQuota.empty();
  String currentPath = '/';
  bool loading = true;
  String? error;

  // Tab state (only used when not in pickerMode)
  late final TabController tabController;
  // "Shared with me" tab state
  List<VaultShare> sharedWithMe = [];
  bool sharedWithMeLoading = false;
  String? sharedWithMeError;
  StreamSubscription? _vaultSyncSub;

  // Multi-select state
  final Set<String> selectedPaths = {};
  bool get isSelecting => selectedPaths.isNotEmpty;

  void toggleSelection(VaultFile file) {
    setState(() {
      if (selectedPaths.contains(file.path)) {
        selectedPaths.remove(file.path);
      } else {
        selectedPaths.add(file.path);
      }
    });
  }

  void clearSelection() {
    setState(selectedPaths.clear);
  }

  List<VaultFile> get selectedFiles =>
      files.where((f) => selectedPaths.contains(f.path)).toList();

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 2, vsync: this);
    tabController.addListener(() {
      // Load shared-with-me on first switch to that tab.
      if (tabController.index == 1 &&
          !tabController.indexIsChanging &&
          sharedWithMe.isEmpty &&
          !sharedWithMeLoading) {
        refreshSharedWithMe();
      }
    });
    _vaultSyncSub = Matrix.of(context).client.onSync.stream
        .where(
          (syncUpdate) =>
              syncUpdate.rooms?.join?.values.any(
                (roomUpdate) =>
                    roomUpdate.timeline?.events?.any(
                      (event) =>
                          event.type == EventTypes.Message &&
                          event.content['msgtype'] == VaultEventContent.msgtype,
                    ) ??
                    false,
              ) ??
              false,
        )
        .listen((_) {
          if (tabController.index == 1 && !sharedWithMeLoading) {
            refreshSharedWithMe();
          }
        });
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _vaultSyncSub?.cancel();
    tabController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    final client = Matrix.of(context).client;
    api = VaultApi(matrixClient: client);
    Logs().i('[VaultPage] Using vault API base URL: ${api.baseUrl}');
    Logs().i('[VaultPage] Matrix homeserver: ${client.homeserver}');
    Logs().i(
      '[VaultPage] Matrix access token present: ${client.accessToken != null}',
    );
    try {
      await api.provision();
    } on VaultApiException catch (e) {
      // Already provisioned — fine
      Logs().i(
        '[VaultPage] Provision response (expected if already set up): $e',
      );
    }
    await refresh();
  }

  Future<void> refresh() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        api.listFiles(path: currentPath),
        api.getQuota(),
      ]);
      if (!mounted) return;
      setState(() {
        files = results[0] as List<VaultFile>;
        quota = results[1] as VaultQuota;
        loading = false;
      });
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.message;
        loading = false;
      });
    }
  }

  /// Loads all shares targeting the rooms the current user belongs to.
  Future<void> refreshSharedWithMe() async {
    setState(() {
      sharedWithMeLoading = true;
      sharedWithMeError = null;
    });
    try {
      final results = await api.listSharedWithMe();
      final seen = <String>{};
      final deduped = results.where((s) => seen.add(s.shareId)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (!mounted) return;
      setState(() {
        sharedWithMe = deduped;
        sharedWithMeLoading = false;
      });
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() {
        sharedWithMeError = _sharedWithMeErrorMessage(e);
        sharedWithMeLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        sharedWithMeError = e.toString();
        sharedWithMeLoading = false;
      });
    }
  }

  String _sharedWithMeErrorMessage(VaultApiException error) {
    if (error.statusCode == 401) {
      return 'Your session expired. Please sign in again, then retry.';
    }
    if (error.statusCode == 502 || error.statusCode == 503) {
      return 'Unable to check your joined rooms right now. Please retry.';
    }
    if (error.statusCode >= 500) {
      return 'Vault could not load shared files right now. Please retry.';
    }
    return error.message;
  }

  void navigateToFolder(VaultFile folder) {
    setState(() => currentPath = folder.path);
    refresh();
  }

  void navigateUp() {
    if (currentPath == '/') return;
    // Strip trailing slash then find the parent
    final trimmed = currentPath.endsWith('/')
        ? currentPath.substring(0, currentPath.length - 1)
        : currentPath;
    final lastSlash = trimmed.lastIndexOf('/');
    currentPath = lastSlash <= 0 ? '/' : '${trimmed.substring(0, lastSlash)}/';
    refresh();
  }

  String get breadcrumb {
    if (currentPath == '/') return 'My Vault';
    final parts = currentPath.split('/').where((p) => p.isNotEmpty);
    return 'My Vault / ${parts.join(' / ')}';
  }

  Future<void> uploadFiles() async {
    final selected = await selectFiles(context, allowMultiple: true);
    if (selected.isEmpty || !mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VaultUploadDialog(
        files: selected,
        currentPath: currentPath,
        onComplete: refresh,
      ),
    );
  }

  Future<void> createFolder() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => VaultFolderDialog(currentPath: currentPath),
    );
    if (result == true) refresh();
  }

  Future<void> deleteFile(VaultFile file) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete ${file.isFolder ? 'folder' : 'file'}?'),
        content: Text(
          'Are you sure you want to delete "${file.name}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      _showDeletingDialog();
      await api.deleteFile(path: file.path);
      _dismissDeletingDialog();
      refresh();
    } on VaultApiException catch (e) {
      _dismissDeletingDialog();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Handle tapping a file in the list.
  Future<void> onFileTap(VaultFile file) async {
    // In multi-select mode, taps toggle selection
    if (isSelecting) {
      toggleSelection(file);
      return;
    }

    if (file.isFolder) {
      navigateToFolder(file);
      return;
    }

    if (widget.pickerMode) {
      // In picker mode: create a share and return it
      final share = await showDialog<VaultShare>(
        context: context,
        builder: (context) =>
            VaultShareDialog(file: file, roomId: widget.roomId),
      );
      if (share != null && mounted) {
        Navigator.of(context).pop(share);
      }
      return;
    }

    if (vaultPreviewTypeFor(file) != VaultPreviewType.download) {
      await _openPreview(file);
      return;
    }

    // Normal mode: show actions bottom sheet for file types without preview.
    _showFileActions(file);
  }

  void _showFileActions(VaultFile file) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.download_outlined),
              title: const Text('Download'),
              onTap: () {
                Navigator.of(context).pop();
                _downloadFile(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Share link'),
              onTap: () async {
                Navigator.of(context).pop();
                await _createShareLink(file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.link_outlined),
              title: const Text('Manage shares'),
              onTap: () {
                Navigator.of(context).pop();
                _manageShares(file);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete_outline,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                deleteFile(file);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _manageShares(VaultFile file) async {
    await showDialog<void>(
      context: context,
      builder: (context) => VaultManageSharesDialog(file: file, api: api),
    );
  }

  Future<void> _openPreview(VaultFile file) async {
    final action = await Navigator.of(context).push<VaultPreviewAction>(
      MaterialPageRoute(
        builder: (context) => VaultPreviewPage(
          file: file,
          loadDownloadUrl: (file) => api.getDownloadUrl(path: file.path),
        ),
      ),
    );
    if (!mounted || action == null) return;

    switch (action) {
      case VaultPreviewAction.shareLink:
        await _createShareLink(file);
      case VaultPreviewAction.manageShares:
        await _manageShares(file);
      case VaultPreviewAction.delete:
        await deleteFile(file);
    }
  }

  Future<void> _createShareLink(VaultFile file) async {
    final scaffoldContext = context;
    final scaffoldMessenger = ScaffoldMessenger.of(scaffoldContext);
    final share = await showDialog<VaultShare>(
      context: scaffoldContext,
      builder: (context) => VaultShareDialog(file: file),
    );
    if (share != null && mounted && scaffoldContext.mounted) {
      await Clipboard.setData(ClipboardData(text: share.vaultUrl));
      if (!mounted || !scaffoldContext.mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: const Text('Share link copied to clipboard'),
          action: SnackBarAction(
            label: 'Open',
            onPressed: () =>
                UrlLauncher(scaffoldContext, share.vaultUrl).launchUrl(),
          ),
        ),
      );
    }
  }

  Future<void> deleteSelected() async {
    final selected = selectedFiles;
    final count = selected.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text('Delete $count ${count == 1 ? 'item' : 'items'}?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    _showDeletingDialog(count: count);
    var errors = 0;
    for (final file in selected) {
      try {
        await api.deleteFile(path: file.path);
      } on VaultApiException {
        errors++;
      }
    }
    _dismissDeletingDialog();
    clearSelection();
    refresh();
    if (errors > 0 && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete $errors item(s)')),
      );
    }
  }

  Future<void> downloadSelected() async {
    final selected = selectedFiles.where((f) => !f.isFolder).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No files selected (folders skipped)')),
      );
      return;
    }
    for (final file in selected) {
      try {
        final url = await api.getDownloadUrl(path: file.path);
        if (!mounted) return;
        UrlLauncher(context, url).launchUrl();
      } on VaultApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to download ${file.name}: ${e.message}'),
          ),
        );
      }
    }
    clearSelection();
  }

  /// Opens the share preview page for a shared file in a browser tab.
  void openShareLink(VaultShare share) {
    UrlLauncher(context, share.vaultUrl).launchUrl();
  }

  /// Downloads a shared file via its authenticated download endpoint.
  Future<void> downloadShare(VaultShare share) async {
    try {
      final url = await api.getShareDownloadUrl(shareId: share.shareId);
      if (!mounted) return;
      UrlLauncher(context, url).launchUrl();
    } on VaultApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _showDeletingDialog({int count = 1}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog.adaptive(
          content: Row(
            children: [
              const CircularProgressIndicator.adaptive(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  count > 1
                      ? 'Deleting $count items...\nPlease wait.'
                      : 'Deleting...\nPlease wait.',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _dismissDeletingDialog() {
    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> _downloadFile(VaultFile file) async {
    try {
      final url = await api.getDownloadUrl(path: file.path);
      if (!mounted) return;
      UrlLauncher(context, url).launchUrl();
    } on VaultApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) => VaultPageView(this);
}
