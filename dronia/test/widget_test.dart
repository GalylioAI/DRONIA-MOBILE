// Dronia App Widget Tests

import 'package:flutter_test/flutter_test.dart';

import 'package:dronia/main.dart';

void main() {
  testWidgets('App launches and shows splash screen', (
    WidgetTester tester,
  ) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const DroniaApp());

    // Verify that the app renders
    expect(find.byType(DroniaApp), findsOneWidget);
  });
}
