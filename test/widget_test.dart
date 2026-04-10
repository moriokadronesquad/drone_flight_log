import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drone_flight_log/app.dart';

void main() {
  testWidgets('アプリが起動できる', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: DroneFlightLogApp()),
    );
    await tester.pump();

    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
