/* Minimal Firebase Messaging service worker fallback
   This helps avoid the 'unsupported MIME type (text/html)' error when the
   browser tries to register firebase-messaging-sw.js but it's missing.
   It provides a simple push handler so registration succeeds even without
   full Firebase config.
*/

self.addEventListener("push", function (event) {
  let data = {};
  try {
    data = event.data ? event.data.json() : {};
  } catch (e) {
    data = {
      notification: { title: "Notification", body: event.data?.text() ?? "" },
    };
  }

  const title =
    (data.notification && data.notification.title) || "Notification";
  const options = {
    body: (data.notification && data.notification.body) || "",
    icon: "/favicon.png",
  };

  event.waitUntil(self.registration.showNotification(title, options));
});

self.addEventListener("notificationclick", function (event) {
  event.notification.close();
  event.waitUntil(
    clients
      .matchAll({ type: "window", includeUncontrolled: true })
      .then(function (clientList) {
        if (clientList.length > 0) {
          const client = clientList[0];
          return client.focus();
        }
        return clients.openWindow("/");
      }),
  );
});
