import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/resolver_config.dart';

void main() {
  test('normal entrypoint defaults to one canonical resolver', () {
    expect(configuredResolverOrigin().toString(), canonicalResolverOrigin);
    expect(resolverOrigin().toString(), canonicalResolverOrigin);
  });
  test('ordinary builds reject independent endpoints including loopback', () {
    for (final origin in [
      'https://independent.example',
      'http://127.0.0.1:8000',
      '$canonicalResolverOrigin/',
      '$canonicalResolverOrigin?x=1',
      '',
    ]) {
      expect(() => resolverOrigin(configured: origin), throwsFormatException);
    }
  });
  test('deliberate fixture builds accept only loopback origins', () {
    for (final origin in [
      'http://127.0.0.1:54335',
      'http://localhost:8000',
      'http://[::1]:8000'
    ]) {
      expect(resolverOrigin(configured: origin, localFixture: true).toString(),
          origin);
    }
    for (final origin in [
      canonicalResolverOrigin,
      'https://independent.example',
      'http://localhost.evil.example',
      'http://user@localhost',
      'http://localhost/path',
      'http://localhost?query=1',
      'http://localhost#fragment'
    ]) {
      expect(() => resolverOrigin(configured: origin, localFixture: true),
          throwsFormatException);
    }
  });
}
