import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/home_screen.dart';
import 'package:tv2/main.dart';

import 'home_screen_test.dart' show NamespaceAwareApi, OfflineResolverApi;

void main() {
  testWidgets('4x4 keys retain touch targets, legends and input callbacks', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    final pressed = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            child: Keypad(
              onKey: pressed.add,
              onCall: () {},
              onHome: () {},
              onBack: () {},
              onEnter: () {},
              callEnabled: true,
              enterEnabled: true,
            ),
          ),
        ),
      ),
    );
    for (final row in Keypad.layout) {
      for (final value in row) {
        final key = find.ancestor(
          of: find.text(value),
          matching: find.byType(FilledButton),
        );
        expect(tester.getSize(key).width, greaterThanOrEqualTo(48));
        expect(tester.getSize(key).height, greaterThanOrEqualTo(48));
        await tester.tap(key);
      }
    }
    expect(pressed, Keypad.layout.expand((row) => row).toList());
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    for (final legend in [
      'ABC',
      'DEF',
      'GHI',
      'JKL',
      'MNO',
      'PQRS',
      'TUV',
      'WXYZ',
      'OPER',
    ]) {
      expect(find.text(legend), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  for (final scale in [1.0, 2.0, 3.0]) {
    testWidgets('compact home resolves and clears with text scale $scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        TV2App(api: NamespaceAwareApi(), initialCountry: '1'),
      );
      await tester.pumpAndSettle();
      expect(find.text('ENTER LIST NUMBER'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      for (final value in ['5', '2', '9']) {
        final key = find.ancestor(
          of: find.text(value),
          matching: find.byType(FilledButton),
        );
        await tester.ensureVisible(key);
        await tester.tap(key);
      }
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byTooltip('ENTER'));
      await tester.tap(find.byTooltip('ENTER'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Save listing'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byTooltip('Clear'));
      await tester.tap(find.byTooltip('Clear'));
      await tester.pumpAndSettle();
      expect(find.text('529'), findsNothing);
      expect(find.text('+1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('compact enlarged offline guidance does not overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(
      TV2App(api: OfflineResolverApi(), initialCountry: '1'),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('5'));
    await tester.tap(find.text('5'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Check your internet connection'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
