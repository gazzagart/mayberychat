import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

/// Fetches LiveKit JWT tokens from the MatrixRTC authorization service
/// (lk-jwt-service).
///
/// The service validates the user's Matrix access token and returns a
/// LiveKit JWT that grants access to a specific LiveKit room.
class JwtTokenService {
  final Client _client;
  final String _jwtServiceUrl;

  JwtTokenService({required Client client, required String jwtServiceUrl})
    : _client = client,
      _jwtServiceUrl = jwtServiceUrl;

  /// Request a LiveKit JWT for the given [roomId].
  ///
  /// The lk-jwt-service validates our Matrix access token and returns
  /// a response containing the LiveKit WebSocket URL and a JWT.
  ///
  /// Returns a [JwtTokenResponse] on success, throws on failure.
  Future<JwtTokenResponse> getToken(String roomId) async {
    final uri = Uri.parse(_jwtServiceUrl);
    final accessToken = _client.accessToken;
    if (accessToken == null) {
      throw Exception('Not logged in — no Matrix access token available');
    }

    final response = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: json.encode({
        'room': roomId,
        'openid_token': await _getOpenIdToken(),
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'JWT service returned ${response.statusCode}: ${response.body}',
      );
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return JwtTokenResponse(
      jwt: data['jwt'] as String? ?? data['token'] as String,
      livekitUrl: data['url'] as String? ?? data['livekit_url'] as String,
    );
  }

  /// Obtain an OpenID token from the Matrix homeserver.
  /// This is used by lk-jwt-service to verify our Matrix identity.
  Future<Map<String, dynamic>> _getOpenIdToken() async {
    final credentials = await _client.requestOpenIdToken(_client.userID!, {});
    return credentials.toJson();
  }
}

/// The response from the JWT token service.
class JwtTokenResponse {
  final String jwt;
  final String livekitUrl;

  const JwtTokenResponse({required this.jwt, required this.livekitUrl});
}
