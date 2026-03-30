// Web implementation — calls the Firebase JS SDK functions exposed on `window`
// by the initialisation script block in web/index.html.

import 'dart:js_interop';

import 'package:matrix/matrix.dart';

@JS('_letsyak_requestNotificationPermission')
external JSPromise<JSString> _requestPermission();

@JS('_letsyak_getWebFcmToken')
external JSPromise<JSAny?> _getToken(JSString vapidKey);

/// Requests browser notification permission, then obtains and returns an FCM
/// web push token using [vapidKey].  Returns `null` on any failure or if the
/// user denies the permission.
Future<String?> requestWebFcmToken(String vapidKey) async {
  final permission = (await _requestPermission().toDart).toDart;
  if (permission != 'granted') {
    Logs().w('[Push] Notification permission not granted: "$permission"');
    return null;
  }
  Logs().i('[Push] Notification permission granted, requesting token...');
  final tokenJs = await _getToken(vapidKey.toJS).toDart;
  if (tokenJs == null) {
    Logs().w('[Push] getToken returned null');
    return null;
  }
  return (tokenJs as JSString).toDart;
}
