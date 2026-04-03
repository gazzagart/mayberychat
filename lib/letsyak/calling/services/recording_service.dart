import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// Service for controlling LiveKit Egress (server-side recording).
///
/// Communicates with the LiveKit server API to start/stop recording
/// of a room. Requires API key/secret to be proxied through a backend
/// endpoint for security — never embed LiveKit API secrets in the client.
///
/// In practice, your backend should expose a thin REST endpoint that
/// the client calls, and the backend calls LiveKit Egress with the secret.
class RecordingService {
  final Client _client;
  final String _recordingApiUrl;

  RecordingService({required Client client, required String recordingApiUrl})
    : _client = client,
      _recordingApiUrl = recordingApiUrl;

  /// Start recording the given LiveKit room.
  ///
  /// Calls the backend recording API which proxies to LiveKit Egress.
  /// Returns an egress ID that can be used to stop recording.
  Future<String?> startRecording(String roomId) async {
    if (_recordingApiUrl.isEmpty) return null;

    final accessToken = _client.accessToken;
    if (accessToken == null) return null;

    try {
      final response = await http.post(
        Uri.parse('$_recordingApiUrl/start'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'room_id': roomId}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return data['egress_id'] as String?;
      }
      Logs().w('Failed to start recording: ${response.statusCode}');
    } catch (e) {
      Logs().e('Failed to start recording', e);
    }
    return null;
  }

  /// Stop an active recording by its egress ID.
  Future<bool> stopRecording(String egressId) async {
    if (_recordingApiUrl.isEmpty) return false;

    final accessToken = _client.accessToken;
    if (accessToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$_recordingApiUrl/stop'),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: json.encode({'egress_id': egressId}),
      );

      return response.statusCode == 200;
    } catch (e) {
      Logs().e('Failed to stop recording', e);
      return false;
    }
  }
}
