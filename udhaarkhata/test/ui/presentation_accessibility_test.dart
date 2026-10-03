import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:udhaarkhata/app/app_strings.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/app/ui/financial_panels.dart';

void main() {
  testWidgets('long Hindi identity and full money reflow at 320 and 200%', (tester) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submitted = false;
    await tester.pumpWidget(MaterialApp(theme: clearCounterTheme(), locale: const Locale('hi'), supportedLocales: AppStrings.supportedLocales, localizationsDelegates: const [AppStrings.delegate, ...GlobalMaterialLocalizations.delegates], home: Scaffold(body: MediaQuery(data: const MediaQueryData(size: Size(320, 844), textScaler: TextScaler.linear(2), viewInsets: EdgeInsets.only(bottom: 300)), child: SingleChildScrollView(child: FinancialReview(customerName: 'बहुत लंबा ग्राहक का नाम और दुकान की पहचान', actionLabel: 'जमा करें', amountPaise: 124567890, details: const [Text('फोन पर सुरक्षित है। क्लाउड में बैकअप नहीं है।')], busy: false, onSubmit: () => submitted = true))))));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('₹12,45,678.90'), findsOneWidget);
    await tester.ensureVisible(find.text('जमा करें'));
    await tester.tap(find.text('जमा करें'));
    expect(submitted, isTrue);
  });
  test('actual semantic text colors meet contrast on their panel surfaces', () {
    double contrast(Color a, Color b) { final x = a.computeLuminance(), y = b.computeLuminance(); return (x > y ? (x + .05) / (y + .05) : (y + .05) / (x + .05)); }
    for (final pair in [(AppTokens.primary, AppTokens.tint), (AppTokens.secondary, Colors.white), (AppTokens.pending, AppTokens.pendingSurface), (AppTokens.attention, AppTokens.attentionSurface)]) { expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5)); }
  });
}
