import 'package:flutter_test/flutter_test.dart';
import 'package:toggletalk/main.dart';

void main() {
  group('Message Model Tests', () {
    test('Message creation', () {
      final message = Message(
        id: 1,
        text: 'Hello World',
        isUser: true,
        timestamp: DateTime.now(),
      );

      expect(message.id, 1);
      expect(message.text, 'Hello World');
      expect(message.isUser, true);
    });

    test('Message from JSON', () {
      final json = {
        'message_id': 123,
        'text': 'Test message',
        'date': 1609459200, // Jan 1, 2021 00:00:00 UTC
      };

      final message = Message.fromJson(json);

      expect(message.id, 123);
      expect(message.text, 'Test message');
      expect(message.isUser, false); // Messages from API are bot responses
    });
  });
}