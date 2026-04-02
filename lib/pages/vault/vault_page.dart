import 'package:fluffychat/pages/vault/vault_folder_dialog.dart';
import 'package:fluffychat/pages/vault/vault_page_view.dart';
import 'package:fluffychat/pages/vault/vault_share_dialog.dart';
import 'package:fluffychat/pages/vault/vault_upload_dialog.dart';
import 'package:fluffychat/utils/file_selector.dart';
import 'package:fluffychat/utils/url_launcher.dart';
import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

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

class VaultPageController extends State<VaultPage> {
  late VaultApi api;
  List<VaultFile> files = [];
  VaultQuota quota = VaultQuota.empty();
  String currentPath = '/';
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    final client = Matrix.of(context).client;
    api = VaultApi(matrixClient: client);
    try {
      await api.provision();
    } on VaultApiException {
      // Already provisioned — fine
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

  void navigateToFolder(VaultFile folder) {
    setState(() => currentPath = folder.path);
    refresh();
  }

  void navigateUp() {
    if (currentPath == '/') return;
    final parts = currentPath.split('/')..removeLast();
    if (parts.last.isEmpty) parts.removeLast();
    currentPath = parts.isEmpty ? '/' : '${parts.join('/')}/';
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
      await api.deleteFile(path: file.path);
      refresh();
    } on VaultApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  /// Handle tapping a file in the list.
  Future<void> onFileTap(VaultFile file) async {
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

    // Normal mode: show actions bottom sheet
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
                final share = await showDialog<VaultShare>(
                  context: this.context,
                  builder: (ctx) => VaultShareDialog(file: file),
                );
                if (share != null && mounted) {
                  ScaffoldMessenger.of(this.context).showSnackBar(
                    SnackBar(
                      content: Text('Share link created for ${file.name}'),
                    ),
                  );
                }
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
