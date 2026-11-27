import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/web_default_font.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('native entry does not load web-only fonts', () async {
    await loadWebDefaultFont();
  });
}
