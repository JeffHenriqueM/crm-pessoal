// Firebase Messaging Service Worker — Villamor CRM
// Responsável por receber notificações push em background

importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBWsDC_91UQH3oxiKmXS2ewHpvLGzHV_H4',
  authDomain: 'crm-pessoal-d993d.firebaseapp.com',
  projectId: 'crm-pessoal-d993d',
  storageBucket: 'crm-pessoal-d993d.firebasestorage.app',
  messagingSenderId: '908967144787',
  appId: '1:908967144787:web:8545a3e9caa9566bb485a6',
});

const messaging = firebase.messaging();

// Recebe mensagens em background e exibe a notificação
messaging.onBackgroundMessage((payload) => {
  const { title, body, icon } = payload.notification ?? {};
  self.registration.showNotification(title ?? 'Villamor CRM', {
    body: body ?? '',
    icon: icon ?? '/icons/Icon-192.png',
    badge: '/favicon.png',
    tag: payload.data?.tag ?? 'villamor-crm',
    data: payload.data ?? {},
  });
});

// Clique na notificação — abre/foca o app
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      if (clientList.length > 0) {
        return clientList[0].focus();
      }
      return clients.openWindow('/');
    })
  );
});
