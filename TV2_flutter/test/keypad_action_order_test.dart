import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/home_screen.dart';

void main() {
  testWidgets('TV2 keypad actions follow CALL HOME ENTER BACK order',
      (tester) async {
    final actions = <String>[];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Keypad(
            onKey: (_) {},
            onCall: () => actions.add('CALL'),
            onHome: () => actions.add('HOME'),
            onEnter: () => actions.add('ENTER'),
            onBack: () => actions.add('BACK'),
            callEnabled: true,
            enterEnabled: true,
          ),
        ),
      ),
    );

    final buttons = [
      find.byTooltip('CALL'),
      find.byTooltip('HOME'),
      find.byTooltip('ENTER'),
      find.byTooltip('BACK'),
    ];

    for (final button in buttons) {
      expect(button, findsOneWidget);
    }
    for (var index = 1; index < buttons.length; index++) {
      expect(
        tester.getTopLeft(buttons[index - 1]).dx,
        lessThan(tester.getTopLeft(buttons[index]).dx),
        reason: 'Actions must follow the approved left-to-right order',
      );
    }

    await tester.tap(find.byTooltip('ENTER'));
    await tester.pump();
    await tester.tap(find.byTooltip('BACK'));
    await tester.pump();
    expect(actions, ['ENTER', 'BACK']);
  });
}
