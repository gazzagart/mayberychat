import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

/// Simple dialog to create a new folder in the vault.
class VaultFolderDialog extends StatefulWidget {
  final String currentPath;

  const VaultFolderDialog({required this.currentPath, super.key});

  @override
  State<VaultFolderDialog> createState() => _VaultFolderDialogState();
}

class _VaultFolderDialogState extends State<VaultFolderDialog> {
  final _controller = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _loading = true);
    try {
      final client = Matrix.of(context).client;
      final api = VaultApi(matrixClient: client);
      final path = widget.currentPath.endsWith('/')
          ? '${widget.currentPath}$name/'
          : '${widget.currentPath}/$name/';
      await api.createFolder(path: path);
      if (mounted) Navigator.of(context).pop(true);
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Folder'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: const InputDecoration(
          labelText: 'Folder name',
          border: OutlineInputBorder(),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _create(),
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _create,
          child: _loading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create'),
        ),
      ],
    );
  }
}
