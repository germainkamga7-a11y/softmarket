importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-app-compat.js");
importScripts("https://www.gstatic.com/firebasejs/10.7.1/firebase-messaging-compat.js");

firebase.initializeApp({
  apiKey: "AIzaSyBGsbEObzNb4QiIPIKpFL6bIW8Qx7IQLGk",
  authDomain: "softmarket-55f22.firebaseapp.com",
  projectId: "softmarket-55f22",
  storageBucket: "softmarket-55f22.appspot.com",
  messagingSenderId: "795518110767",
  appId: "1:795518110767:web:12f2e5ac320fee117c4ada",
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage(function (payload) {
  const title = payload.notification?.title ?? "CamerMarket";
  const body = payload.notification?.body ?? "";
  self.registration.showNotification(title, { body });
});
