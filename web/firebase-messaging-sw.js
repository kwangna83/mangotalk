importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAq_OejXpUSBpIaAO03e5ymirSl2NRpVjw',
  authDomain: 'mangotalk-notifications.firebaseapp.com',
  projectId: 'mangotalk-notifications',
  storageBucket: 'mangotalk-notifications.firebasestorage.app',
  messagingSenderId: '682588856465',
  appId: '1:682588856465:web:e9623f8ec0fd5a78551f30',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((message) => {
  if (message.notification) return;
  const data = message.data || {};
  self.registration.showNotification(data.title || 'MangoTalk', {
    body: data.body || '새 메시지가 도착했어요.',
    icon: 'icons/Icon-192.png',
    badge: 'icons/Icon-192.png',
    data,
  });
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const roomId = event.notification.data?.roomId;
  const target = new URL('./', self.registration.scope);
  if (roomId) target.searchParams.set('room', roomId);
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const windowClient of windows) {
        if (windowClient.url.startsWith(self.registration.scope)) {
          windowClient.navigate(target.href);
          return windowClient.focus();
        }
      }
      return clients.openWindow(target.href);
    }),
  );
});
