import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class OrderCancelPage extends StatefulWidget {
  static const routeName = '/cancel-order';

  const OrderCancelPage({super.key});

  @override
  State<OrderCancelPage> createState() => _OrderCancelPageState();
}

class _OrderCancelPageState extends State<OrderCancelPage> {
  final String token =
      'Bearer 1|0wDXZiVSSilt7gcs9SkP4G6Nu8NnOKb7a3KtHARs4ac3f8b3';
  final int orderId = 26;
  final int problemReasonId = 2;
  final String? customReason = 'Я передумал';

  bool _isLoading = false;

  Future<void> cancelOrder() async {
    setState(() => _isLoading = true);

    final url = Uri.parse('http://10.0.2.2:8000/api/orders/$orderId/cancel');

    final res = await http.post(
      url,
      headers: {
        'Authorization': token,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: jsonEncode({
        'problem_reason_id': problemReasonId,
        if (customReason != null) 'custom_reason': customReason,
      }),
    );

    final decoded = jsonDecode(utf8.decode(res.bodyBytes));
    print('📥 Ответ: ${res.statusCode}');
    print(decoded);

    setState(() => _isLoading = false);

    if (res.statusCode == 200) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Заказ успешно отменён')),
      );
    } else {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      final error = decoded['message'] ?? 'Ошибка при отмене';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Отмена заказа')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : ElevatedButton(
                onPressed: cancelOrder,
                child: const Text('Отменить заказ'),
              ),
      ),
    );
  }
}
