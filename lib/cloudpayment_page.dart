import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:webview_flutter/webview_flutter.dart';

class CloudPaymentPage extends StatefulWidget {
  static const routeName = '/cloudpayments';

  const CloudPaymentPage({super.key});

  @override
  State<CloudPaymentPage> createState() => _CloudPaymentPageState();
}

class _CloudPaymentPageState extends State<CloudPaymentPage> {
  late final WebViewController _webViewController;
  bool _isLoading = true;

  final String token =
      'Bearer 1|0wDXZiVSSilt7gcs9SkP4G6Nu8NnOKb7a3KtHARs4ac3f8b3';
  final int shopId = 1;
  final int shippingAddressId = 1;
  final String accountEmail = 'user@user.com';
  final String publicId = 'test_api_00000000000000000000001';

  String? invoiceId;
  double? amount;
  String description = '';

  @override
  void initState() {
    super.initState();

    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'CloudPaymentsChannel',
        onMessageReceived: (JavaScriptMessage message) {
          print('📦 CloudPaymentsChannel received: ${message.message}');
          final data = jsonDecode(message.message);
          final status = data['status'];
          final metadata = data['metadata'];

          print('📍 TransactionId: ${metadata["TransactionId"]}');
          print('📍 CardLastFour: ${metadata["CardLastFour"]}');
          print('📍 Статус: ${metadata["Status"]}');

          _sendCallback(status, metadata);
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            if (request.url.startsWith('cpresult://')) {
              print('🔄 Перехват URL: ${request.url}');
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
          onPageStarted: (url) => setState(() => _isLoading = true),
          onPageFinished: (url) {
            setState(() => _isLoading = false);
            print('✅ Страница загружена: $url');
          },
        ),
      );

    _startOrderFlow();
  }

  Future<void> _startOrderFlow() async {
    try {
      // 🛒 Создание заказа
      final orderRes = await http.post(
        Uri.parse('http://10.0.2.2:8000/api/orders'),
        headers: {
          'Authorization': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'shop_id': shopId,
          'shipping_address_id': shippingAddressId,
        }),
      );

      final decodedOrderBody = jsonDecode(utf8.decode(orderRes.bodyBytes));
      print('📥 Ответ от /orders: ${orderRes.statusCode}');
      print(decodedOrderBody);

      if (orderRes.statusCode != 201) {
        String errorMessage =
            decodedOrderBody['message'] ?? 'Неизвестная ошибка';
        if (decodedOrderBody['errors'] != null) {
          errorMessage += '\n' + decodedOrderBody['errors'].toString();
        }
        _showErrorAndExit('Ошибка при создании заказа:\n$errorMessage');
        return;
      }

      invoiceId = decodedOrderBody['order_number'];
      description = 'Оплата заказа №${decodedOrderBody['order_id']}';

      // 💳 Создание платежа
      final paymentRes = await http.post(
        Uri.parse(
            'http://10.0.2.2:8000/api/orders/${decodedOrderBody['order_id']}/payments'),
        headers: {
          'Authorization': token,
          'Accept': 'application/json',
        },
      );

      final decodedPaymentBody = jsonDecode(utf8.decode(paymentRes.bodyBytes));
      print('📥 Ответ от /payments: ${paymentRes.statusCode}');
      print(decodedPaymentBody);

      if (paymentRes.statusCode != 200) {
        String errorMessage =
            decodedPaymentBody['message'] ?? 'Неизвестная ошибка';
        _showErrorAndExit('Ошибка при создании платежа:\n$errorMessage');
        return;
      }

      amount = decodedPaymentBody['amount'].toDouble();

      print(amount);

      final html = getPaymentHtml(
        publicId: publicId,
        invoiceId: invoiceId!,
        amount: amount!,
        description: description,
        accountId: accountEmail,
      );

      _webViewController.loadHtmlString(html);
    } catch (e) {
      _showErrorAndExit('Непредвиденная ошибка: $e');
    }
  }

  void _showErrorAndExit(String message) {
    print('❌ $message');
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
    Navigator.pop(context);
  }

  Future<void> _sendCallback(
      String status, Map<String, dynamic> metadata) async {
    if (invoiceId == null) return;

    print('📡 Отправка callback -> /payments/callback');
    print('Статус : $status');
    print('Metadata: $metadata');

    final res = await http.post(
      Uri.parse('http://10.0.2.2:8000/api/payments/callback'),
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'order_number': invoiceId,
        'status': status,
        'metadata': metadata,
      }),
    );

    print('📥 Ответ от /payments/callback: ${res.statusCode}');
    print(res.body);

    final msg =
        status == 'success' ? 'Оплата прошла успешно' : 'Оплата не удалась';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    Navigator.pop(context);
  }

  String getPaymentHtml({
    required String publicId,
    required String invoiceId,
    required double amount,
    required String description,
    required String accountId,
    String currency = 'KZT',
  }) {
    return """
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8" />
  <title>CloudPayments</title>
  <script src="https://widget.cloudpayments.ru/bundles/cloudpayments.js"></script>
</head>
<body onload="pay();" style="margin: 0; padding: 0;">
<script>
function pay() {
  var widget = new cp.CloudPayments();
  widget.charge({
    publicId: '$publicId',
    description: '$description',
    amount: $amount,
    currency: '$currency',
    invoiceId: '$invoiceId',
    accountId: '$accountId',
    skin: 'classic'
  },
  function onSuccess(options) {
    // 👇 Прокидываем весь объект options
    CloudPaymentsChannel.postMessage(JSON.stringify({
      status: "success",
      metadata: options
    }));
  },
  function onFail(reason) {
    CloudPaymentsChannel.postMessage(JSON.stringify({
      status: "fail",
      metadata: reason
    }));
  });
}
</script>
<h2 style="text-align:center; margin-top:50px;">Ожидаем оплату...</h2>
</body>
</html>
""";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оплата')),
      body: Stack(
        children: [
          WebViewWidget(controller: _webViewController),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
