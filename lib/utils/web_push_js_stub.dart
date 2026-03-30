// Stub for non-web builds.  These functions are never called because
// setupWebPush() is guarded by `if (!kIsWeb) return;`.

// ignore: avoid_unused_parameters
Future<String?> requestWebFcmToken(String vapidKey) async => null;
