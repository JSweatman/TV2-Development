import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tv2/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android plugin dispatch is blocked by native instrumentation',
    (t) async {
      const native = MethodChannel('qa/native-intents');
      Future<Map> state() async => (await native.invokeMethod('state')) as Map;
      Future<void> wait(Finder f) async {
        for (var i = 0; i < 150 && f.evaluate().isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 200));
        }
        expect(f, findsWidgets);
      }

      Future<void> tap(Finder f) async {
        await wait(f);
        await t.ensureVisible(f.first);
        await t.tap(f.first);
        await t.pumpAndSettle();
      }

      app.main();
      await t.pumpAndSettle();
      expect((await state())['armed'], true);
      await tap(find.textContaining('Japan'));
      print('TV2_CONTACT_COUNTRY_UI_81');
      for (final d in ['5', '2', '9']) {
        await tap(find.widgetWithText(FilledButton, d));
      }
      await tap(find.byTooltip('ENTER'));
      await wait(find.byTooltip('Back'));
      await wait(find.text('Sample Native Contacts'));
      print('TV2_CONTACT_LISTING_VISIBLE');
      final cases = [
        ['CALL', 'Open device app', 'tel:+12025550101'],
        ['TEXT', 'Open device app', 'sms:+12025550102'],
      ];
      var count = 0;
      for (final c in cases) {
        print('TV2_CONTACT_START_${c[0]}');
        await tap(find.text(c[0]));
        await tap(find.text('Continue'));
        await tap(find.text('Cancel'));
        expect(((await state())['events'] as List).length, count);
        print('TV2_CONTACT_CANCEL_${c[0]}_COUNT_$count');
        print('TV2_CONTACT_START_${c[0]}');
        await tap(find.text(c[0]));
        await tap(find.text('Continue'));
        await tap(find.text(c[1]));
        final events = (await state())['events'] as List;
        expect(events.length, ++count);
        expect(events.last['uri'], c[2]);
        expect(events.last['action'], 'android.intent.action.VIEW');
        expect(find.text('Sample Native Contacts'), findsOneWidget);
        print('TV2_CONTACT_CONFIRM_${c[0]}_COUNT_$count ${events.last}');
      }
      print('TV2_CONTACT_UI_PASS');
      await native.invokeMethod('done');
    },
  );
}
