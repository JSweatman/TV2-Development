import 'package:flutter_test/flutter_test.dart';
import '../tool/portable/sample_resolver.dart';

void main() {
  test('same-origin two-record adapter has no contact or owner resources',
      () async {
    final api = SampleResolver(Uri.parse('https://review.example.org'));
    for (final n in ['700001', '70002']) {
      final row = (await api.resolve(input: '1*$n', country: '81')).listing!;
      expect(row.qualifiedIdentity, '1*$n');
      expect(row.buttons.single.label, 'WEBSITE');
      expect(row.resource('website')!.uri,
          'https://review.example.org${n == '700001' ? '/sample-website.html' : '/alex.html'}');
      expect(row.hasType('listing_video'), n == '700001');
      for (final r in row.resources) {
        expect(['call', 'text', 'email', 'owner'].contains(r.type), false);
        if (r.uri != null)
          expect(Uri.parse(r.uri!).origin, 'https://review.example.org');
      }
    }
    expect((await api.resolve(input: '700001', country: '81')).listing, isNull);
    expect((await api.resolve(input: '999999', country: '1')).listing, isNull);
    expect(
        (await api.resolve(input: '1*700001.2', country: '1')).listing, isNull);
    expect((await api.prefix(input: '7', country: '1')).matches.length, 2);
    expect(
        (await api.prefix(input: '1*700001', country: '81'))
            .matches
            .single
            .exact,
        true);
  });
  test('portable HTTPS guard rejects insecure/local/file origins', () {
    for (final raw in [
      'http://review.example.org',
      'http://localhost',
      'https://127.0.0.1',
      'file:///app/index.html'
    ]) {
      expect(allowedSampleOrigin(Uri.parse(raw)), false);
    }
    expect(allowedSampleOrigin(Uri.parse('https://review.example.org/app/')),
        true);
    expect(allowedSampleOrigin(Uri.parse('https://second.example.org/app/')),
        true);
  });
}
