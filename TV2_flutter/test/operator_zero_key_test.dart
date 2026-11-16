import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/home_screen.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('zero shows OPER and enters numeric zero at text scale $scale',
        (tester) async {
      final entered = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Keypad(
                onKey: entered.add,
                onCall: () {},
                onHome: () {},
                onBack: () {},
                onEnter: () {},
                callEnabled: false,
                enterEnabled: false,
              ),
            ),
          ),
        ),
      );

      final zero = find.byKey(const Key('tv2-zero-operator-key'));
      expect(find.descendant(of: zero, matching: find.text('0')), findsOneWidget);
      expect(find.descendant(of: zero, matching: find.text('OPER')), findsOneWidget);
      expect(find.descendant(of: zero, matching: find.text('+')), findsNothing);

      await tester.tap(zero);
      await tester.pump();
      expect(entered, ['0']);
      expect(tester.takeException(), isNull);
    });
  }
}
