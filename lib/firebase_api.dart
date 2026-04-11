import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Maneja el mensaje cuando la app esta en segundo plano o terminada
Future<void> handleBackgroundMessage(RemoteMessage message) async {
  print('Title: ${message.notification?.title}');
  print('Body: ${message.notification?.body}');
  print('Payload: ${message.data}');
}

class FirebaseApi {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _localNotifications = FlutterLocalNotificationsPlugin();

  // Create a channel for Android notifications
  final _androidChannel = const AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.', // description
    importance: Importance.defaultImportance,
  );


  // Funcion para inicializar las notificaciones
  Future<void> initNotifications() async {
    // Pedir permiso al usuario
    await _firebaseMessaging.requestPermission();

    // Obtener el token FCM
    final fCMToken = await _firebaseMessaging.getToken();

    // Suscribirse al tema "allUsers"
    await _firebaseMessaging.subscribeToTopic("allUsers");

    // Imprimir el token (Opcional)
    print('Token: $fCMToken');

    // Inicializar las notificaciones push
    initPushNotifications();
    initLocalNotifications();
  }

  // Funcion para manejar los mensajes
  void handleMessage(RemoteMessage? message) {
    // Si el mensaje es nulo, no hacer nada
    if (message == null) return;
  }

  Future<void> initLocalNotifications() async {
      const iOS = DarwinInitializationSettings();
      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const settings = InitializationSettings(android: android, iOS: iOS);

      await _localNotifications.initialize(settings);

      final platform = _localNotifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await platform?.createNotificationChannel(_androidChannel);
  }

  // Funcion para inicializar las notificaciones push
  Future initPushNotifications() async {
    // Handle notification if the app was terminated and now opened
    FirebaseMessaging.instance.getInitialMessage().then(handleMessage);

    // Attach a listener for when a notification is received and the app is in the foreground
    FirebaseMessaging.onMessage.listen((message) {
        final notification = message.notification;
        if (notification == null) return;

        _localNotifications.show(
            notification.hashCode,
            notification.title,
            notification.body,
            NotificationDetails(
                android: AndroidNotificationDetails(
                    _androidChannel.id,
                    _androidChannel.name,
                    channelDescription: _androidChannel.description,
                    icon: '@mipmap/ic_launcher'
                )
            ),
        );
    });

    // Attach a listener for when a notification is tapped and the app is in the background
    FirebaseMessaging.onMessageOpenedApp.listen(handleMessage);

     // Attach a listener for background messages
    FirebaseMessaging.onBackgroundMessage(handleBackgroundMessage);
  }
}
