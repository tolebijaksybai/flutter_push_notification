// notifications_page.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

// Импортируем из main.dart, чтобы иметь доступ к flutterLocalNotificationsPlugin
import 'main.dart';

/// Адрес Laravel API (для Android-эмулятора)
const String backendUrl = 'http://10.0.2.2:8000/api/profile/device-token';

/// Laravel Sanctum-токен (замените на свой! )
const String sanctumToken =
    'Bearer 1|0wDXZiVSSilt7gcs9SkP4G6Nu8NnOKb7a3KtHARs4ac3f8b3';

class NotificationsPage extends StatefulWidget {
  static const routeName = '/notifications';

  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  String? deviceToken;
  String responseMessage = "";

  @override
  void initState() {
    super.initState();
    _initFCM();
  }

  Future<void> _initFCM() async {
    // Слушаем уведомления в Foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      print("🎉 Foreground Push получен!");
      print(
          "📩 ${message.notification?.title} | ${message.notification?.body}");

      if (message.notification != null) {
        await flutterLocalNotificationsPlugin.show(
          message.notification.hashCode,
          message.notification?.title,
          message.notification?.body,
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'fcm_channel',
              'FCM Notifications',
              channelDescription: 'Этот канал для FCM уведомлений',
              importance: Importance.high,
              icon: 'ic_notification',
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    // Слушаем, когда пользователь открыл уведомление
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Пользователь открыл уведомление");
    });

    // Проверяем, не открыто ли приложение уведомлением при старте
    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print(
            "🔄 Приложение открыто через уведомление: ${message.notification?.title}");
      }
    });

    // Запрашиваем разрешения
    NotificationSettings settings =
        await FirebaseMessaging.instance.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      // Получаем FCM-токен
      final token = await FirebaseMessaging.instance.getToken();
      setState(() {
        deviceToken = token;
      });
      if (token != null) {
        await _sendTokenToBackend(token);
      }
    } else {
      setState(() {
        responseMessage = "Разрешение на уведомления не получено";
      });
    }
  }

  Future<void> _sendTokenToBackend(String token) async {
    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': sanctumToken,
      },
      body: '{"device_token": "$token"}',
    );

    print("Device Token: $token");
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    setState(() {
      responseMessage = response.statusCode == 200
          ? '✅ Токен успешно отправлен!'
          : '❌ Ошибка: ${response.statusCode} ${response.body}';
    });
  }

  Future<void> _refreshTokenAndResend() async {
    final settings = await FirebaseMessaging.instance.requestPermission();
    if (settings.authorizationStatus != AuthorizationStatus.authorized) {
      setState(() {
        responseMessage = "⛔ Разрешение на уведомления не получено повторно";
      });
      return;
    }

    final refreshedToken = await FirebaseMessaging.instance.getToken();
    if (refreshedToken != null) {
      setState(() {
        deviceToken = refreshedToken;
      });
      await _sendTokenToBackend(refreshedToken);
    } else {
      setState(() {
        responseMessage = "❌ Не удалось получить токен повторно";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FCM Notifications'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'FCM Token:',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              SelectableText(deviceToken ?? 'Получение токена...'),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _refreshTokenAndResend,
                icon: const Icon(Icons.refresh),
                label: const Text("Обновить токен и отправить заново"),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  // Удаляем токен, затем пробуем заново
                  await FirebaseMessaging.instance.deleteToken();
                  await _refreshTokenAndResend();
                },
                icon: const Icon(Icons.delete),
                label: const Text("Удалить токен и пересоздать"),
              ),
              const SizedBox(height: 20),
              Text(responseMessage),
            ],
          ),
        ),
      ),
    );
  }
}
