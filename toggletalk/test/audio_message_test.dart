import 'package:flutter_test/flutter_test.dart';
import 'package:toggletalk/main.dart';

void main() {
  group('Audio Message Tests', () {
    test('Message creation with audio flag', () {
      final message = Message(
        id: 1,
        text: 'Hello World',
        isUser: true,
        timestamp: DateTime.now(),
        isAudio: true,
      );

      expect(message.id, 1);
      expect(message.text, 'Hello World');
      expect(message.isUser, true);
      expect(message.isAudio, true);
    });

    test('Default message creation', () {
      final message = Message(
        id: 2,
        text: 'Test message',
        isUser: false,
        timestamp: DateTime.now(),
      );

      expect(message.id, 2);
      expect(message.text, 'Test message');
      expect(message.isUser, false);
      expect(message.isAudio, false); // Default value
    });
  });
}