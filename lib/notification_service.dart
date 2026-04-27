
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _notificationService = NotificationService._internal();

  factory NotificationService() {
    return _notificationService;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // 1. Configuración específica para Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. Configuración específica para iOS/macOS
    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings();

    // 3. Objeto de configuración general que agrupa las configuraciones de cada plataforma
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // 4. Inicializar el plugin usando el argumento con nombre "settings:"
    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings, // <<-- ESTA ERA LA SOLUCIÓN
      onDidReceiveNotificationResponse: onDidReceiveNotificationResponse,
    );
  }

  void onDidReceiveNotificationResponse(NotificationResponse notificationResponse) async {
    // Lógica para cuando el usuario toca la notificación
  }

  Future<void> showNotification(String title, String body) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'your channel id', // id del canal
          'your channel name', // nombre del canal
          channelDescription: 'your channel description', // descripción
          importance: Importance.max,
          priority: Priority.high,
        );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    // La función show utiliza argumentos con nombre, lo cual ya estaba correcto.
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
  }
}
