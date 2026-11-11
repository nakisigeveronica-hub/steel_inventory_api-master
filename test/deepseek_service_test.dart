import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:steel_inventory_api/services/deepseek_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('sends the saved API key as a bearer token', () async {
    FlutterSecureStorage.setMockInitialValues({
      'deepseek_api_key': 'test-api-key',
    });

    final client = MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-api-key');
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'message': {'content': 'There are 4 items.'},
            },
          ],
        }),
        200,
      );
    });
    final service = DeepSeekService(client: client);

    final answer = await service.reply(
      messages: const [
        {'role': 'user', 'content': 'How many items?'},
      ],
      inventoryContext: const {'total_products': 4},
    );

    expect(answer, 'There are 4 items.');
    service.close();
  });

}
