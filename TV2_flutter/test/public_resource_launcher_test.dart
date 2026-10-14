import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/public_resource_launcher.dart';

void main() {
  test('allows normal HTTPS public domains', () {
    expect(safePublicResourceUri('https://example.org')?.host, 'example.org');
    expect(safePublicResourceUri('https://www.example.org/page?q=1')?.scheme, 'https');
    expect(safePublicResourceUri('https://example.org:443/page'), isNotNull);
  });

  test('rejects unsupported protocols and invalid URLs', () {
    expect(safePublicResourceUri(null), isNull);
    expect(safePublicResourceUri(''), isNull);
    expect(safePublicResourceUri('http://example.org'), isNull);
    expect(safePublicResourceUri('file:///tmp/test'), isNull);
    expect(safePublicResourceUri('not a URL'), isNull);
    expect(safePublicResourceUri('https://example.org:8443'), isNull);
  });

  test('rejects internal and malformed hostnames', () {
    expect(safePublicResourceUri('https://localhost'), isNull);
    expect(safePublicResourceUri('https://app.local'), isNull);
    expect(safePublicResourceUri('https://app.internal'), isNull);
    expect(safePublicResourceUri('https://app.test'), isNull);
    expect(safePublicResourceUri('https://127.0.0.1'), isNull);
    expect(safePublicResourceUri('https://foo..org'), isNull);
  });

  test('launcher refuses rejected URLs without invoking platform', () async {
    var calls = 0;
    final launcher = PublicResourceLauncher(open: (uri) async {
      calls++;
      return true;
    });
    expect(await launcher.open('http://example.org'), isFalse);
    expect(calls, 0);
    expect(await launcher.open('https://example.org'), isTrue);
    expect(calls, 1);
  });

  test('launcher handles platform failure without crashing', () async {
    final launcher = PublicResourceLauncher(open: (uri) async {
      throw StateError('unavailable');
    });
    expect(await launcher.open('https://example.org'), isFalse);
  });
}
