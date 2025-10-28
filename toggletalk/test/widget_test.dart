// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:toggletalk/main.dart';

void main() {
  testWidgets('ToggleTalk app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ToggleTalkApp());

    // Verify that the app bar title is correct.
    expect(find.text('ToggleTalk'), findsOneWidget);

    // Verify that the welcome message is displayed.
    expect(
      find.text(
        'Hello! I\'m your ToggleTalk bot assistant. How can I help you today?',
      ),
      findsOneWidget,
    );

    // Verify that the text field is present.
    expect(find.byType(TextField), findsOneWidget);

    // Verify that the send button is present.
    expect(find.byIcon(Icons.send), findsOneWidget);
  });
}
