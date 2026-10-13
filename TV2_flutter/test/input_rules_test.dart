import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/input_rules.dart';

void main() {
  test('STAR is namespace-only', () {
    expect(InputRules.canAppend('', '*'), isTrue);
    expect(InputRules.canAppend('91', '*'), isTrue);
    expect(InputRules.canAppend('91*5', '*'), isFalse);
  });

  test('base enforces 15 characters without counting country or TLDx', () {
    const base = '123456789012345';
    expect(InputRules.canAppend(base, '6'), isFalse);
    expect(InputRules.canAppend('91*$base.', '4'), isTrue);
  });

  test('adjacent symbols are blocked', () {
    expect(InputRules.canAppend('529@', '#'), isFalse);
    expect(InputRules.canAppend('529.', '4'), isTrue);
  });
}
