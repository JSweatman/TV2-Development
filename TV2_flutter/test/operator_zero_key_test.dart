import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/home_screen.dart';

void main() {
  testWidgets('zero key shows OPER legend but still enters numeric zero',
      (tester) async {
    final entered = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
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
    );

    expect(find.text('0'), findsOneWidget);
    expect(find.text('OPER'), findsOneWidget);
    expect(find.text('+'), findsNothing);

    await tester.tap(find.byKey(const Key('tv2-zero-operator-key')));
    await tester.pump();
    expect(entered, ['0']);
  });
}
