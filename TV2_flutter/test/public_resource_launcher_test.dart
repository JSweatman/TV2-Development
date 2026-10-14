import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/public_resource_launcher.dart';

void main() {
  test('public resource URLs use HTTPS', () {
    expect(safePublicResourceUri('https://example.org')?.host, 'example.org');
    expect(safePublicResourceUri('http://example.org'), isNull);
  });
}
