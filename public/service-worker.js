self.addEventListener('push', function(event) {
  event.waitUntil(self.registration.showNotification("Snarky Pucks turn reminder", {
    body: "It's time to make your move in Snarky Pucks!",
    icon: "/icon.png",
    tag: "snarky-pucks-turn-notification-tag"
  }));
});

self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  event.waitUntil(clients.matchAll({ type: "window" }).then(function(clientList) {
    for (var i = 0; i < clientList.length; i++) {
      var client = clientList[i];
      if (client.url == "/" && "focus" in client) {
        return client.focus();
      }
    }
    if (clients.openWindow) {
      return clients.openWindow("/");
    }
  }));
});
