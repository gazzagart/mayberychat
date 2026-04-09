import 'dart:convert';

import 'package:fluffychat/config/vault_config.dart';
import 'package:fluffychat/utils/vault/vault_models.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// HTTP client for the LetsYak Vault API.
///
/// All requests are authenticated with the user's Matrix access token.
class VaultApi {
  final Client matrixClient;
  final String baseUrl;

  VaultApi({required this.matrixClient, String? baseUrl})
    : baseUrl = baseUrl ?? VaultConfig.vaultApiBaseUrl;

  Map<String, String> get _headers => {
    'Authorization': 'Bearer ${matrixClient.accessToken}',
    'Content-Type': 'application/json',
  };

  Uri _uri(String path, [Map<String, String>? queryParams]) =>
      Uri.parse('$baseUrl$path').replace(queryParameters: queryParams);

  // ── Provisioning ──────────────────────────────────────────────────

  /// Provision the user's vault bucket. Safe to call multiple times
  /// (the server is idempotent).
  Future<void> provision() async {
    final response = await http.post(
      _uri('/api/v1/auth/provision'),
      headers: _headers,
    );
    _ensureSuccess(response);
  }

  // ── Quota ─────────────────────────────────────────────────────────

  Future<VaultQuota> getQuota() async {
    final response = await http.get(_uri('/api/v1/quota'), headers: _headers);
    _ensureSuccess(response);
    return VaultQuota.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  // ── Files ─────────────────────────────────────────────────────────

  Future<List<VaultFile>> listFiles({String path = '/'}) async {
    final response = await http.get(
      _uri('/api/v1/files', {'path': path}),
      headers: _headers,
    );
    _ensureSuccess(response);
    final list = json.decode(response.body) as List;
    return list
        .map((e) => VaultFile.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns a presigned PUT URL for uploading a file.
  Future<String> getUploadUrl({
    required String path,
    required String fileName,
    required int fileSize,
    String? mimeType,
  }) async {
    final response = await http.post(
      _uri('/api/v1/files/upload-url'),
      headers: _headers,
      body: json.encode({
        'path': path,
        'file_name': fileName,
        'file_size': fileSize,
        if (mimeType != null) 'mime_type': mimeType,
      }),
    );
    _ensureSuccess(response);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['upload_url'] as String;
  }

  /// Returns a presigned GET URL for downloading a file.
  Future<String> getDownloadUrl({required String path}) async {
    final response = await http.post(
      _uri('/api/v1/files/download-url'),
      headers: _headers,
      body: json.encode({'path': path}),
    );
    _ensureSuccess(response);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['download_url'] as String;
  }

  Future<void> createFolder({required String path}) async {
    final response = await http.post(
      _uri('/api/v1/files/folder'),
      headers: _headers,
      body: json.encode({'path': path}),
    );
    _ensureSuccess(response);
  }

  Future<void> deleteFile({required String path}) async {
    final response = await http.delete(
      _uri('/api/v1/files', {'path': path}),
      headers: _headers,
    );
    _ensureSuccess(response);
  }

  Future<void> moveFile({
    required String fromPath,
    required String toPath,
  }) async {
    final response = await http.post(
      _uri('/api/v1/files/move'),
      headers: _headers,
      body: json.encode({'from': fromPath, 'to': toPath}),
    );
    _ensureSuccess(response);
  }

  // ── Shares ────────────────────────────────────────────────────────

  /// Create a share link for a vault file, optionally scoped to a room.
  Future<VaultShare> createShare({
    required String objectKey,
    required String fileName,
    required int fileSize,
    String? mimeType,
    String? targetId,
    String shareType = 'room',
    String? password,
    DateTime? expiresAt,
    int? maxDownloads,
  }) async {
    final response = await http.post(
      _uri('/api/v1/shares'),
      headers: _headers,
      body: json.encode({
        'object_key': objectKey,
        'file_name': fileName,
        'file_size': fileSize,
        if (mimeType != null) 'mime_type': mimeType,
        if (targetId != null) 'target_id': targetId,
        'share_type': shareType,
        if (password != null) 'password': password,
        if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        if (maxDownloads != null) 'max_downloads': maxDownloads,
      }),
    );
    _ensureSuccess(response);
    return VaultShare.fromJson(
      json.decode(response.body) as Map<String, dynamic>,
    );
  }

  /// Get the presigned download URL for a shared file.
  Future<String> getShareDownloadUrl({required String shareId}) async {
    final response = await http.get(
      _uri('/api/v1/shares/$shareId/download'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final data = json.decode(response.body) as Map<String, dynamic>;
    return data['download_url'] as String;
  }

  Future<void> revokeShare({required String shareId}) async {
    final response = await http.delete(
      _uri('/api/v1/shares/$shareId'),
      headers: _headers,
    );
    _ensureSuccess(response);
  }

  Future<List<VaultShare>> listMyShares() async {
    final response = await http.get(
      _uri('/api/v1/shares/mine'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final list = json.decode(response.body) as List;
    return list
        .map((e) => VaultShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Returns all active shares targeting [roomId], filtered to the current user's rooms.
  Future<List<VaultShare>> listRoomShares({required String roomId}) async {
    final encoded = Uri.encodeComponent(roomId);
    final response = await http.get(
      _uri('/api/v1/shares/room/$encoded'),
      headers: _headers,
    );
    _ensureSuccess(response);
    final list = json.decode(response.body) as List;
    return list
        .map((e) => VaultShare.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Helpers ───────────────────────────────────────────────────────

  void _ensureSuccess(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;

    String message;
    try {
      final body = json.decode(response.body) as Map<String, dynamic>;
      message =
          body['error'] as String? ?? response.reasonPhrase ?? 'Unknown error';
    } catch (_) {
      message = response.reasonPhrase ?? 'HTTP ${response.statusCode}';
    }
    throw VaultApiException(message, response.statusCode);
  }
}

class VaultApiException implements Exception {
  final String message;
  final int statusCode;

  const VaultApiException(this.message, this.statusCode);

  @override
  String toString() => 'VaultApiException($statusCode): $message';
}
