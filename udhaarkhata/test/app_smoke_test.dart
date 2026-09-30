import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/main.dart';

void main() {
  testWidgets('starter app launches', (tester) async {
    await tester.pumpWidget(const MainApp());
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('Hello World!'), findsOneWidget);
  });
}
