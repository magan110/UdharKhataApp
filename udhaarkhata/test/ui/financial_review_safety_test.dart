import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:udhaarkhata/app/ui/app_tokens.dart';
import 'package:udhaarkhata/core/network/contracts.dart';
import 'package:udhaarkhata/features/ledger/credit_form.dart';
import 'package:udhaarkhata/features/ledger/ledger_repository.dart';
import 'package:udhaarkhata/features/qr/owner_link_repository.dart';
import '../auth_session_test.dart' show MemorySecureStorage;
import '../credit_repository_test.dart' show CreditAuth;
import '../owner_link_test.dart' show LinkAuth;
void main() {
  testWidgets('grouped credit review retry preserves original body and one in flight request', (tester) async {
    final auth=CreditAuth(), storage=MemorySecureStorage();
    await tester.pumpWidget(ProviderScope(overrides:[ledgerRepositoryProvider.overrideWithValue(CloudLedgerRepository(auth,OpaqueId.fromJson('owner'),storage)),ownerLinkRepositoryProvider.overrideWithValue(CloudOwnerLinkRepository(LinkAuth(),OpaqueId.fromJson('owner'),MemorySecureStorage()))],child:MaterialApp(theme:clearCounterTheme(),home:CreditPage(shopId:OpaqueId.fromJson('shop'),linkId:OpaqueId.fromJson('link')))));
    await tester.pumpAndSettle(); await tester.enterText(find.widgetWithText(TextFormField,'Amount (₹)'),'12450'); await tester.tap(find.text('Review credit')); await tester.pumpAndSettle();
    expect(find.textContaining('₹12,450.00'),findsWidgets); expect(auth.requests,isEmpty);
    await tester.tap(find.text('Confirm credit')); await tester.pumpAndSettle();
    expect(auth.requests.length,1); final original=Map<String,Object?>.of(auth.requests.single);
    final done=Completer<void>(); auth.wait=done.future; auth.loseResponse=false;
    await tester.tap(find.text('Check same credit')); await tester.pumpAndSettle();
    expect(auth.requests.length,2); expect(auth.requests.last,original);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'Checking credit…')).onPressed,isNull);
    done.complete(); await tester.pumpAndSettle(); expect(auth.requests.length,2); expect(find.text('Credit acknowledged by server'),findsOneWidget);
  });
}
