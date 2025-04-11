import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );

  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  runApp(const MyApp());
}

// 🔁 Адрес Laravel API — для Android-эмулятора
const String backendUrl = 'http://10.0.2.2:8000/api/profile/device-token';

// 🔐 Laravel Sanctum-токен (замени на свой!)
const String sanctumToken =
    'Bearer 1|4FGMePWpWMnD85ESbzcipIrIAmcOZpwXMBj50DQg74b3fc50';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String? deviceToken;
  String responseMessage = "";

  @override
  void initState() {
    super.initState();
    initFCM();
  }

  Future<void> refreshTokenAndResend() async {
    // Повторный запрос разрешений (по желанию)
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
      await sendTokenToBackend(refreshedToken);
    } else {
      setState(() {
        responseMessage = "❌ Не удалось получить токен повторно";
      });
    }
  }

  Future<void> initFCM() async {
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
              'fcm_channel', // ID канала
              'FCM Notifications', // Название
              channelDescription: 'Этот канал используется для FCM уведомлений',
              importance: Importance.high,
              icon: 'ic_notification',
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      print("📲 Пользователь открыл уведомление");
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        print(
            "🔄 Приложение открыто через уведомление: ${message.notification?.title}");
      }
    });

    FirebaseMessaging.onMessage.listen((message) {
      print("🎉 Foreground Push получен!");
      print(
          "📩 ${message.notification?.title} | ${message.notification?.body}");
    });

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Запрос разрешений
    NotificationSettings settings = await messaging.requestPermission();
    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await messaging.getToken();
      setState(() {
        deviceToken = token;
      });
      if (token != null) {
        await sendTokenToBackend(token);
      }
    } else {
      setState(() {
        responseMessage = "Разрешение на уведомления не получено";
      });
    }
  }

  Future<void> sendTokenToBackend(String token) async {
    final response = await http.post(
      Uri.parse(backendUrl),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': sanctumToken,
      },
      body: '{"device_token": "$token"}',
    );

    print("Device Token: ${token}");
    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");

    setState(() {
      responseMessage = response.statusCode == 200
          ? '✅ Токен успешно отправлен !!'
          : '❌ Ошибка: ${response.statusCode} ${response.body}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM Token Demo',
      home: Scaffold(
        appBar: AppBar(title: const Text('FCM Token')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            // ← добавлено
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FCM Token:',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                SelectableText(deviceToken ?? 'Получение токена...'),
                const SizedBox(height: 20),
                Text(responseMessage),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: refreshTokenAndResend,
                  icon: const Icon(Icons.refresh),
                  label: const Text("Обновить токен и отправить заново"),
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: () async {
                    await FirebaseMessaging.instance.deleteToken();
                    await refreshTokenAndResend(); // ← уже есть функция
                  },
                  icon: const Icon(Icons.delete),
                  label: const Text("Удалить токен и пересоздать"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
