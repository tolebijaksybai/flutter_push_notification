// main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'cloudpayment_page.dart';
import 'notifications_page.dart';
import 'order_cancel.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FCM + CloudPayments Demo',
      home: const HomeScreen(),
      routes: {
        NotificationsPage.routeName: (context) => const NotificationsPage(),
        CloudPaymentPage.routeName: (context) => const CloudPaymentPage(),
        OrderCancelPage.routeName: (context) => const OrderCancelPage(),
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Главная страница')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, NotificationsPage.routeName);
              },
              child: const Text('Перейти к уведомлениям'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, CloudPaymentPage.routeName);
              },
              child: const Text('Перейти к тесту CloudPayments'),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(context, OrderCancelPage.routeName);
              },
              child: const Text('Перейти к отмене заказа'), // 🆕 кнопка отмены
            ),
          ],
        ),
      ),
    );
  }
}
