import 'dart:convert';

import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WorkspaceSessionStore {
  static const _keyPrefix = 'com.letsyak.workspace_config.';

  static String keyForClient(String clientName) => '$_keyPrefix$clientName';

  static WorkspaceConfig? get(SharedPreferences store, String clientName) {
    final raw = store.getString(keyForClient(clientName));
    if (raw == null || raw.isEmpty) return null;
    try {
      return WorkspaceConfig.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(
    SharedPreferences store,
    String clientName,
    WorkspaceConfig workspace,
  ) {
    return store.setString(
      keyForClient(clientName),
      jsonEncode(workspace.toJson()),
    );
  }

  static Future<void> remove(SharedPreferences store, String clientName) {
    return store.remove(keyForClient(clientName));
  }
}
