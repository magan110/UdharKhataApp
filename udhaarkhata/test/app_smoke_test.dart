import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/main.dart';

void main() {
  testWidgets('signed-out user starts in the safe welcome shell', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MainApp()));
    await tester.pumpAndSettle();
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Udhaar Khata'), findsWidgets);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Hello World!'), findsNothing);
  });
}
