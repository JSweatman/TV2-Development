import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/web_default_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native entry does not load web-only fonts', () async {
    await loadWebDefaultFont();
  });
  for (final failed in [null, 'Medium', 'Bold']) {
    test('registered Regular survives optional failure: $failed', () async {
      final attempts = <String>[];
      final registered = <String>[];
      await loadRobotoWeights((weight) async {
        attempts.add(weight);
        if (weight == failed) throw Exception('synthetic 404');
        registered.add(weight);
      });
      expect(attempts, ['Regular', 'Medium', 'Bold']);
      expect(registered, ['Regular', 'Medium', 'Bold']..remove(failed));
    });
  }
  test('required Regular failure remains explicit', () async {
    final attempts = <String>[];
    await expectLater(loadRobotoWeights((weight) async {
      attempts.add(weight);
      throw Exception('synthetic required font loss');
    }), throwsException);
    expect(attempts, ['Regular']);
  });
}
