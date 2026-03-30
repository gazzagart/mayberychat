// Firebase Cloud Messaging service worker for LetsYak web push notifications.
// This file MUST be served at /firebase-messaging-sw.js (the root of the web server).
// In Flutter web, placing it in the web/ directory satisfies this requirement automatically.
//
// Background messages (received while the app tab is closed or hidden) are handled here.
// Foreground messages are handled in lib/utils/background_push.dart via FirebaseMessaging.onMessage.

importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyB6r5g7uLroBO7pLLbiI1o8tKPlozNQ_yQ',
  authDomain: 'let-s-yak.firebaseapp.com',
  projectId: 'let-s-yak',
  storageBucket: 'let-s-yak.firebasestorage.app',
  messagingSenderId: '18561045434',
  appId: '1:18561045434:web:118c3da131ac889d1cc383',
});

const messaging = firebase.messaging();

// Handle messages received while the web app is not in the foreground.
// The Matrix push gateway sends an event_id_only payload; show a generic
// notification here — the user can tap it to open the app and see the message.
messaging.onBackgroundMessage((payload) => {
  const notification = payload.notification || {};
  const data = payload.data || {};

  const title = notification.title || data.title || 'New Message';
  const body = notification.body || data.body || '';

  return self.registration.showNotification(title, {
    body: body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data: data,
  });
});
