import 'dart:convert';

import 'package:fluffychat/config/setting_keys.dart';
import 'package:fluffychat/utils/workspace/workspace_models.dart';
import 'package:http/http.dart' as http;

class WorkspaceApi {
  final String baseUrl;
  final http.Client httpClient;

  WorkspaceApi({String? baseUrl, http.Client? httpClient})
    : baseUrl = baseUrl ?? AppSettings.controlPlaneBaseUrl.value,
      httpClient = httpClient ?? http.Client();

  Future<List<WorkspaceConfig>> resolve({String? email, String? slug}) async {
    final query = <String, String>{};
    final trimmedSlug = slug?.trim();
    final trimmedEmail = email?.trim();
    if (trimmedSlug != null && trimmedSlug.isNotEmpty) {
      query['slug'] = trimmedSlug;
    } else if (trimmedEmail != null && trimmedEmail.isNotEmpty) {
      query['email'] = trimmedEmail;
    } else {
      throw ArgumentError('email or slug is required');
    }

    final response = await httpClient.get(
      Uri.parse(
        '$baseUrl/api/v1/workspaces/resolve',
      ).replace(queryParameters: query),
      headers: const {'Accept': 'application/json'},
    );
    _ensureSuccess(response);

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final workspaces = data['workspaces'] as List? ?? const [];
    return workspaces
        .map((json) => WorkspaceConfig.fromJson(json as Map<String, dynamic>))
        .toList();
  }

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    var message = 'Workspace discovery failed';
    try {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      message = data['error'] as String? ?? message;
    } catch (_) {
      if (response.body.isNotEmpty) message = response.body;
    }
    throw WorkspaceApiException(message, response.statusCode);
  }
}

class WorkspaceApiException implements Exception {
  final String message;
  final int statusCode;

  const WorkspaceApiException(this.message, this.statusCode);

  @override
  String toString() => 'WorkspaceApiException($statusCode): $message';
}
