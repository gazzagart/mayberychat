import 'package:fluffychat/pages/vault/vault_file_tile.dart';
import 'package:fluffychat/pages/vault/vault_page.dart';
import 'package:fluffychat/pages/vault/vault_quota_widget.dart';
import 'package:fluffychat/pages/vault/vault_shared_tile.dart';
import 'package:flutter/material.dart';

class VaultPageView extends StatelessWidget {
  final VaultPageController controller;

  const VaultPageView(this.controller, {super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showTabs = !controller.widget.pickerMode;

    return Scaffold(
      appBar: controller.isSelecting
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: controller.clearSelection,
              ),
              title: Text('${controller.selectedPaths.length} selected'),
              actions: [
                IconButton(
                  icon: const Icon(Icons.download_outlined),
                  tooltip: 'Download selected',
                  onPressed: controller.downloadSelected,
                ),
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    color: theme.colorScheme.error,
                  ),
                  tooltip: 'Delete selected',
                  onPressed: controller.deleteSelected,
                ),
              ],
            )
          : AppBar(
              title: Text(
                controller.widget.pickerMode ? 'Choose File' : 'Vault',
              ),
              leading: controller.currentPath != '/'
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: controller.navigateUp,
                    )
                  : controller.widget.pickerMode
                  ? IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null,
              actions: [
                if (!controller.widget.pickerMode)
                  IconButton(
                    icon: const Icon(Icons.create_new_folder_outlined),
                    tooltip: 'New folder',
                    onPressed: controller.createFolder,
                  ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: controller.refresh,
                ),
              ],
              bottom: showTabs
                  ? TabBar(
                      controller: controller.tabController,
                      tabs: const [
                        Tab(icon: Icon(Icons.cloud_outlined), text: 'My Files'),
                        Tab(
                          icon: Icon(Icons.people_outline),
                          text: 'Shared with me',
                        ),
                      ],
                    )
                  : null,
            ),
      floatingActionButton:
          controller.isSelecting ||
              (showTabs && controller.tabController.index == 1)
          ? null
          : FloatingActionButton(
              onPressed: controller.uploadFiles,
              tooltip: 'Upload file',
              child: const Icon(Icons.upload_file),
            ),
      body: showTabs
          ? TabBarView(
              controller: controller.tabController,
              children: [
                _MyFilesBody(controller: controller),
                _SharedWithMeBody(controller: controller),
              ],
            )
          : _MyFilesBody(controller: controller),
    );
  }
}

// ── My Files tab ──────────────────────────────────────────────────

class _MyFilesBody extends StatelessWidget {
  final VaultPageController controller;

  const _MyFilesBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Text(
            controller.breadcrumb,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        VaultQuotaWidget(quota: controller.quota),
        const Divider(height: 1),
        Expanded(child: _VaultContentBody(controller: controller)),
      ],
    );
  }
}

// ── File list (used inside My Files tab) ─────────────────────────

class _VaultContentBody extends StatelessWidget {
  final VaultPageController controller;

  const _VaultContentBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.loading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (controller.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                controller.error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.refresh,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.files.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                controller.currentPath == '/'
                    ? 'Your vault is empty.\nTap + to upload your first file.'
                    : 'This folder is empty.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort: folders first, then by name
    final sorted = controller.files.toList()
      ..sort((a, b) {
        if (a.isFolder && !b.isFolder) return -1;
        if (!a.isFolder && b.isFolder) return 1;
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final file = sorted[index];
          return VaultFileTile(
            file: file,
            selected: controller.selectedPaths.contains(file.path),
            onTap: () => controller.onFileTap(file),
            onLongPress: () => controller.toggleSelection(file),
          );
        },
      ),
    );
  }
}

// ── Shared with me tab ────────────────────────────────────────────

class _SharedWithMeBody extends StatelessWidget {
  final VaultPageController controller;

  const _SharedWithMeBody({required this.controller});

  @override
  Widget build(BuildContext context) {
    if (controller.sharedWithMeLoading) {
      return const Center(child: CircularProgressIndicator.adaptive());
    }

    if (controller.sharedWithMeError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(controller.sharedWithMeError!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: controller.refreshSharedWithMe,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (controller.sharedWithMe.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.people_outline,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'No files have been shared with your rooms yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: controller.refreshSharedWithMe,
      child: ListView.builder(
        itemCount: controller.sharedWithMe.length,
        itemBuilder: (context, index) {
          final share = controller.sharedWithMe[index];
          return VaultSharedTile(
            share: share,
            onTap: () => controller.openShareLink(share),
            onDownload: () => controller.downloadShare(share),
          );
        },
      ),
    );
  }
}
