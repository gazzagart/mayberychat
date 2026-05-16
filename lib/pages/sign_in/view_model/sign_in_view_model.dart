import 'dart:async';

import 'package:collection/collection.dart';
import 'package:fluffychat/pages/sign_in/view_model/model/public_homeserver_data.dart';
import 'package:fluffychat/pages/sign_in/view_model/sign_in_state.dart';
import 'package:fluffychat/utils/workspace/workspace_api.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:flutter/widgets.dart';
import 'package:matrix/matrix_api_lite/utils/logs.dart';

class SignInViewModel extends ValueNotifier<SignInState> {
  final MatrixState matrixService;
  final bool signUp;
  final WorkspaceApi workspaceApi;
  final TextEditingController filterTextController = TextEditingController();
  Timer? _resolveCooldown;

  SignInViewModel(
    this.matrixService, {
    required this.signUp,
    WorkspaceApi? workspaceApi,
  }) : workspaceApi = workspaceApi ?? WorkspaceApi(),
       super(SignInState()) {
    refreshPublicHomeservers();
    filterTextController.addListener(_resolveWorkspacesWithCooldown);
  }

  @override
  void dispose() {
    _resolveCooldown?.cancel();
    filterTextController.removeListener(_resolveWorkspacesWithCooldown);
    super.dispose();
  }

  void _resolveWorkspacesWithCooldown() {
    _resolveCooldown?.cancel();
    final query = filterTextController.text.trim();
    if (query.isEmpty) {
      _setWorkspaceOptions(const []);
      return;
    }
    _resolveCooldown = Timer(
      const Duration(milliseconds: 350),
      () => resolveWorkspaceQuery(query),
    );
  }

  void refreshPublicHomeservers() {
    _setWorkspaceOptions(const []);
  }

  Future<void> resolveWorkspaceQuery(String rawQuery) async {
    final query = rawQuery.trim();
    if (query.isEmpty) {
      _setWorkspaceOptions(const []);
      return;
    }

    value = value.copyWith(
      selectedHomeserver: null,
      publicHomeservers: AsyncSnapshot.waiting(),
      filteredPublicHomeservers: const [],
    );

    try {
      final workspaces = await workspaceApi.resolve(
        email: _looksLikeEmail(query) ? query : null,
        slug: _looksLikeEmail(query) ? null : query,
      );
      final workspaceOptions = workspaces
          .map(PublicHomeserverData.fromWorkspace)
          .toList();
      final fallbackHomeserver = _fallbackHomeserver(query);
      if (fallbackHomeserver != null && workspaceOptions.isEmpty) {
        workspaceOptions.add(fallbackHomeserver);
      }
      _setWorkspaceOptions(workspaceOptions);
    } catch (e, s) {
      Logs().w('Unable to resolve LetsYak workspace', e, s);
      final fallbackHomeserver = _fallbackHomeserver(query);
      if (fallbackHomeserver != null) {
        _setWorkspaceOptions([fallbackHomeserver]);
        return;
      }
      value = value.copyWith(
        selectedHomeserver: null,
        publicHomeservers: AsyncSnapshot.withError(ConnectionState.done, e, s),
        filteredPublicHomeservers: const [],
      );
    }
  }

  void _setWorkspaceOptions(List<PublicHomeserverData> options) {
    value = value.copyWith(
      selectedHomeserver: options.singleOrNull,
      publicHomeservers: AsyncSnapshot.withData(ConnectionState.done, options),
      filteredPublicHomeservers: options,
    );
  }

  void selectHomeserver(PublicHomeserverData? publicHomeserverData) {
    value = value.copyWith(selectedHomeserver: publicHomeserverData);
  }

  void setLoginLoading(AsyncSnapshot<bool> loginLoading) {
    value = value.copyWith(loginLoading: loginLoading);
  }

  bool _looksLikeEmail(String query) {
    return query.contains('@') && !query.startsWith('@');
  }

  PublicHomeserverData? _fallbackHomeserver(String query) {
    if (_looksLikeEmail(query)) return null;
    final normalizedQuery = query.toLowerCase();
    final uri = Uri.tryParse(normalizedQuery);
    final looksLikeServer =
        normalizedQuery.length >= 3 &&
        (normalizedQuery.contains('.') ||
            normalizedQuery == 'localhost' ||
            (uri != null && uri.hasScheme && uri.host.isNotEmpty)) &&
        uri != null;
    if (!looksLikeServer) return null;
    return PublicHomeserverData(name: query);
  }
}
