import 'package:fluffychat/l10n/l10n.dart';
import 'package:fluffychat/utils/matrix_sdk_extensions/matrix_locals.dart';
import 'package:fluffychat/utils/vault/vault_api.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/material.dart';

class VaultManageSharesDialog extends StatefulWidget {
  final VaultFile file;
  final VaultApi api;

  const VaultManageSharesDialog({
    required this.file,
    required this.api,
    super.key,
  });

  @override
  State<VaultManageSharesDialog> createState() =>
      _VaultManageSharesDialogState();
}

class _VaultManageSharesDialogState extends State<VaultManageSharesDialog> {
  static const _pageSizeOptions = [25, 50, 100];

  final TextEditingController _searchController = TextEditingController();
  var _loading = true;
  var _revoking = false;
  String? _error;
  List<VaultShare> _shares = [];
  final Set<String> _selectedShareIds = {};
  var _pageIndex = 0;
  var _pageSize = _pageSizeOptions.first;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadShares());
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    setState(() => _pageIndex = 0);
  }

  Future<void> _loadShares() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final allShares = await widget.api.listMyShares();
      final now = DateTime.now();
      final shares =
          allShares
              .where(
                (share) =>
                    share.objectKey == widget.file.path &&
                    !share.isRevoked &&
                    (share.expiresAt == null || share.expiresAt!.isAfter(now)),
              )
              .toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

      if (!mounted) return;
      setState(() {
        _shares = shares;
        _pageIndex = 0;
        _selectedShareIds.removeWhere(
          (shareId) => !shares.any((share) => share.shareId == shareId),
        );
        _loading = false;
      });
    } on VaultApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _toggleShare(VaultShare share) {
    if (_revoking) return;
    setState(() {
      if (!_selectedShareIds.add(share.shareId)) {
        _selectedShareIds.remove(share.shareId);
      }
    });
  }

  void _toggleSelectAll() {
    if (_revoking) return;
    final visibleShareIds = _filteredShares
        .map((share) => share.shareId)
        .toSet();
    if (visibleShareIds.isEmpty) return;

    setState(() {
      if (visibleShareIds.every(_selectedShareIds.contains)) {
        _selectedShareIds.removeWhere(visibleShareIds.contains);
      } else {
        _selectedShareIds.addAll(visibleShareIds);
      }
    });
  }

  Future<void> _revokeSelected() async {
    final selected = _shares
        .where((share) => _selectedShareIds.contains(share.shareId))
        .toList();
    await _revokeShares(selected);
  }

  Future<void> _revokeShares(List<VaultShare> shares) async {
    if (shares.isEmpty || _revoking) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog.adaptive(
        title: Text(
          shares.length == 1
              ? 'Revoke this share?'
              : 'Revoke ${shares.length} shares?',
        ),
        content: const Text(
          'Receivers lose access on their next refresh. The file stays in your Vault.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _revoking = true);
    var failures = 0;
    for (final share in shares) {
      try {
        await widget.api.revokeShare(shareId: share.shareId);
      } on VaultApiException {
        failures++;
      }
    }

    if (!mounted) return;
    _selectedShareIds.clear();
    setState(() => _revoking = false);
    await _loadShares();

    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (failures == 0) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            shares.length == 1
                ? 'Share revoked'
                : '${shares.length} shares revoked',
          ),
        ),
      );
    } else {
      messenger?.showSnackBar(
        SnackBar(content: Text('Failed to revoke $failures share(s)')),
      );
    }
  }

  String _targetTitle(VaultShare share) {
    if (share.shareType == 'link') return 'Public share link';
    final targetId = share.targetId;
    if (targetId == null || targetId.isEmpty) return 'Room share';

    final client = Matrix.of(context).client;
    for (final room in client.rooms) {
      if (room.id == targetId) {
        return room.getLocalizedDisplayname(MatrixLocals(L10n.of(context)));
      }
    }
    return _shortRoomId(targetId);
  }

  String _shortRoomId(String roomId) {
    if (roomId.length <= 18) return roomId;
    return '${roomId.substring(0, 15)}...';
  }

  String _subtitle(VaultShare share) {
    final parts = <String>[
      share.shareType == 'link' ? 'Link share' : 'Room share',
      'Created ${_dateLabel(share.createdAt)}',
      '${share.downloadCount} downloads',
    ];
    if (share.expiresAt != null) {
      parts.add('Expires ${_dateLabel(share.expiresAt!)}');
    }
    return parts.join(' · ');
  }

  String _dateLabel(DateTime date) => '${date.day}/${date.month}/${date.year}';

  List<VaultShare> get _filteredShares {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return _shares;

    return _shares.where((share) {
      final searchableText = [
        _targetTitle(share),
        share.targetId ?? '',
        share.shareType == 'link' ? 'Public share link' : 'Room share',
        _dateLabel(share.createdAt),
        if (share.expiresAt != null) _dateLabel(share.expiresAt!),
      ].join(' ').toLowerCase();
      return searchableText.contains(query);
    }).toList();
  }

  int _pageCountFor(int itemCount) {
    if (itemCount == 0) return 1;
    return ((itemCount - 1) ~/ _pageSize) + 1;
  }

  int _clampedPageIndex(int itemCount) {
    final pageCount = _pageCountFor(itemCount);
    return _pageIndex.clamp(0, pageCount - 1);
  }

  List<VaultShare> _pageShares(List<VaultShare> shares, int pageIndex) {
    if (shares.isEmpty) return const [];
    final start = pageIndex * _pageSize;
    final end = start + _pageSize > shares.length
        ? shares.length
        : start + _pageSize;
    return shares.sublist(start, end);
  }

  void _setPageSize(int? pageSize) {
    if (pageSize == null || pageSize == _pageSize || _revoking) return;
    setState(() {
      _pageSize = pageSize;
      _pageIndex = 0;
    });
  }

  void _setPage(int pageIndex) {
    if (_revoking) return;
    setState(() => _pageIndex = pageIndex);
  }

  void _clearSearch() {
    if (_revoking) return;
    _searchController.clear();
  }

  String _resultSummary({
    required int totalCount,
    required int filteredCount,
    required int pageIndex,
  }) {
    if (filteredCount == 0) {
      return totalCount == 0
          ? 'No active shares'
          : 'No matches in $totalCount shares';
    }

    final first = pageIndex * _pageSize + 1;
    final last = first + _pageSize - 1 > filteredCount
        ? filteredCount
        : first + _pageSize - 1;
    if (filteredCount == totalCount) {
      return 'Showing $first-$last of $totalCount shares';
    }
    return 'Showing $first-$last of $filteredCount matches ($totalCount total)';
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedShareIds.length;
    final filteredShares = _filteredShares;
    final pageIndex = _clampedPageIndex(filteredShares.length);
    final pageCount = _pageCountFor(filteredShares.length);
    final pageShares = _pageShares(filteredShares, pageIndex);
    final selectedFilteredCount = filteredShares
        .where((share) => _selectedShareIds.contains(share.shareId))
        .length;
    final allSelected =
        filteredShares.isNotEmpty &&
        selectedFilteredCount == filteredShares.length;
    final hasSearch = _searchController.text.trim().isNotEmpty;
    final Widget content;

    if (_loading) {
      content = const SizedBox(
        width: 320,
        height: 160,
        child: Center(child: CircularProgressIndicator.adaptive()),
      );
    } else if (_error != null) {
      content = SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _loadShares,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      );
    } else if (_shares.isEmpty) {
      content = SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.link_off_outlined,
              size: 40,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              'No active shares for ${widget.file.name}.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      final maxListHeight = (MediaQuery.sizeOf(context).height * 0.32).clamp(
        160.0,
        320.0,
      );
      final listHeight = (pageShares.length * 72.0).clamp(96.0, maxListHeight);

      content = SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              enabled: !_revoking,
              decoration: InputDecoration(
                isDense: true,
                prefixIcon: const Icon(Icons.search),
                hintText: 'Search rooms and links',
                suffixIcon: hasSearch
                    ? IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _resultSummary(
                  totalCount: _shares.length,
                  filteredCount: filteredShares.length,
                  pageIndex: pageIndex,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 8),
            if (filteredShares.isEmpty)
              SizedBox(
                height: 140,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.search_off_outlined,
                        size: 36,
                        color: Theme.of(context).colorScheme.outline,
                      ),
                      const SizedBox(height: 8),
                      const Text('No shares match your search.'),
                    ],
                  ),
                ),
              )
            else
              SizedBox(
                height: listHeight,
                child: ListView.separated(
                  itemCount: pageShares.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final share = pageShares[index];
                    return _ShareTile(
                      selected: _selectedShareIds.contains(share.shareId),
                      revoking: _revoking,
                      title: _targetTitle(share),
                      subtitle: _subtitle(share),
                      onToggle: () => _toggleShare(share),
                      onRevoke: () => _revokeShares([share]),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
            _PageControls(
              pageSize: _pageSize,
              pageSizeOptions: _pageSizeOptions,
              pageIndex: pageIndex,
              pageCount: pageCount,
              revoking: _revoking,
              onPageSizeChanged: _setPageSize,
              onPageChanged: _setPage,
            ),
          ],
        ),
      );
    }

    return AlertDialog(
      title: const Text('Manage shares'),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: MediaQuery.sizeOf(context).height * 0.72,
        ),
        child: content,
      ),
      actions: [
        TextButton(
          onPressed: _revoking ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        if (_shares.isNotEmpty)
          TextButton(
            onPressed: _revoking || filteredShares.isEmpty
                ? null
                : _toggleSelectAll,
            child: Text(
              allSelected
                  ? (hasSearch ? 'Clear matches' : 'Clear')
                  : (hasSearch ? 'Select matches' : 'Select all'),
            ),
          ),
        if (_shares.isNotEmpty)
          FilledButton.icon(
            onPressed: selectedCount == 0 || _revoking ? null : _revokeSelected,
            icon: _revoking
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_off_outlined),
            label: Text(
              selectedCount == 0 ? 'Revoke selected' : 'Revoke $selectedCount',
            ),
          ),
      ],
    );
  }
}

class _ShareTile extends StatelessWidget {
  final bool selected;
  final bool revoking;
  final String title;
  final String subtitle;
  final VoidCallback onToggle;
  final VoidCallback onRevoke;

  const _ShareTile({
    required this.selected,
    required this.revoking,
    required this.title,
    required this.subtitle,
    required this.onToggle,
    required this.onRevoke,
  });

  @override
  Widget build(BuildContext context) => ListTile(
    enabled: !revoking,
    contentPadding: EdgeInsets.zero,
    leading: Checkbox(
      value: selected,
      onChanged: revoking ? null : (_) => onToggle(),
    ),
    title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
    subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: IconButton(
      tooltip: 'Revoke',
      icon: Icon(
        Icons.link_off_outlined,
        color: Theme.of(context).colorScheme.error,
      ),
      onPressed: revoking ? null : onRevoke,
    ),
    onTap: onToggle,
  );
}

class _PageControls extends StatelessWidget {
  final int pageSize;
  final List<int> pageSizeOptions;
  final int pageIndex;
  final int pageCount;
  final bool revoking;
  final ValueChanged<int?> onPageSizeChanged;
  final ValueChanged<int> onPageChanged;

  const _PageControls({
    required this.pageSize,
    required this.pageSizeOptions,
    required this.pageIndex,
    required this.pageCount,
    required this.revoking,
    required this.onPageSizeChanged,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    final canGoBack = pageIndex > 0;
    final canGoForward = pageIndex < pageCount - 1;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Rows'),
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: pageSize,
              onChanged: revoking ? null : onPageSizeChanged,
              items: pageSizeOptions
                  .map(
                    (pageSize) => DropdownMenuItem<int>(
                      value: pageSize,
                      child: Text('$pageSize'),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'Previous page',
              onPressed: canGoBack && !revoking
                  ? () => onPageChanged(pageIndex - 1)
                  : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              'Page ${pageIndex + 1} of $pageCount',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            IconButton(
              tooltip: 'Next page',
              onPressed: canGoForward && !revoking
                  ? () => onPageChanged(pageIndex + 1)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }
}
