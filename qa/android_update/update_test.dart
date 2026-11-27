// Test-only on-emulator driver. Never a distributed app entrypoint.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tv2/main.dart' as app;
void main() {
 IntegrationTestWidgetsFlutterBinding.ensureInitialized();
 const phase=String.fromEnvironment('UPDATE_PHASE');
 testWidgets('preview in-place update $phase', (t) async {
  Future<void> wait(Finder f) async {for(var i=0;i<150 && f.evaluate().isEmpty;i++){await t.pump(const Duration(milliseconds:200));} expect(f, findsWidgets);}
  Future<void> tap(Finder f) async {await wait(f); await t.ensureVisible(f.first); await t.tap(f.first); await t.pumpAndSettle();}
  app.main();await t.pumpAndSettle();
  if(phase=='A') {
   await tap(find.textContaining('Japan'));
   for(final d in ['5','2','9']) {await tap(find.widgetWithText(FilledButton,d));}
   await tap(find.byTooltip('ENTER'));await wait(find.text('Sample Update'));
   for(final row in [['Save listing','Workshop','Study'],['Add to Address Book','Contact','People']]) {
    await tap(find.byTooltip(row[0]));await wait(find.byType(TextField));
    await t.enterText(find.byType(TextField).at(0),row[1]);
    await t.enterText(find.byType(TextField).at(1),row[2]);
    await tap(find.widgetWithText(FilledButton,'Save'));
   }
   print('TV2_UPDATE_A_UI_PASS');
  } else {
   await wait(find.textContaining('+81'));
   for(final row in [['Saved folders','Study','Workshop'],['Address Book','People','Contact']]) {
    await tap(find.byTooltip(row[0]));await tap(find.text(row[1]));await wait(find.text(row[2]));
    await wait(find.text('81*529'));await tap(find.text(row[2]));await wait(find.text('81*529'));
    await tap(find.byTooltip('ENTER'));await wait(find.text('Sample Update'));
    await tap(find.byTooltip('Back'));
   }
   print('TV2_UPDATE_B_UI_PASS');
  }
 });
}
