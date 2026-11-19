// Read-only synthetic adapter. Never imported by lib/main.dart.
import 'package:tv2/models.dart';
import 'package:tv2/resolver_api.dart';
import 'package:tv2/public_resource_launcher.dart';

bool allowedSampleOrigin(Uri uri) =>
    uri.scheme == 'https' && safePublicResourceUri('${uri.origin}/') != null;

class SampleResolver implements ResolverApi {
  SampleResolver(this.origin) {
    if (!allowedSampleOrigin(origin))
      throw StateError('HTTPS review origin required');
  }
  final Uri origin;

  Listing _listing(String number) {
    final business = number == '700001';
    return Listing(
        countryCode: '1',
        listNumber: number,
        tldx: null,
        displayName: business ? 'Northstar (sample)' : 'Alex (sample)',
        entityType: business ? 'business' : 'person',
        templateKey: 'basic',
        resources: [
          ResourceRecord(
              key: 'theme',
              type: 'landing_theme',
              uri: null,
              metadata: {
                'version': 1,
                'palette': business ? 'graphite' : 'lotus',
                'hero': business ? 'horizon' : 'petals'
              }),
          ResourceRecord(
              key: 'website',
              type: 'web',
              uri: origin.resolve('/sample-website.html').toString(),
              metadata: const {}),
          if (business)
            ResourceRecord(
                key: 'video',
                type: 'listing_video',
                uri: origin.resolve('/media/sample.mp4').toString(),
                metadata: const {
                  'publication': 'published',
                  'content_type': 'video/mp4'
                }),
        ],
        buttons: const [
          ButtonRecord(slot: 1, label: 'WEBSITE', resourceKey: 'website')
        ]);
  }

  String? _local(String input, String country) {
    if (input.startsWith('1*')) return input.substring(2);
    if (input.contains('*') || country != '1') return null;
    return input;
  }

  @override
  Future<List<CountryNamespace>> countries() async => const [
        CountryNamespace(
            iso2: 'US',
            countryName: 'Shared calling-code namespace',
            nid: '1',
            defaultLanguageTag: 'en'),
        CountryNamespace(
            iso2: 'JP',
            countryName: 'Japan',
            nid: '81',
            defaultLanguageTag: 'ja'),
      ];

  @override
  Future<PrefixResponse> prefix(
      {required String input, required String country, int limit = 10}) async {
    final local = _local(input, country);
    final rows = local == null || local.isEmpty
        ? <Listing>[]
        : ['700001', '70002']
            .where((n) => n.startsWith(local))
            .map(_listing)
            .toList();
    return PrefixResponse(
        countryContext: country,
        input: input,
        hasMore: rows.length > limit,
        matches: rows
            .take(limit.clamp(0, 10))
            .map((r) => MatchRecord(
                countryCode: '1',
                listNumber: r.listNumber,
                tldx: null,
                displayName: r.displayName,
                entityType: r.entityType,
                qualifiedInput: r.qualifiedIdentity,
                exact: r.listNumber == local))
            .toList());
  }

  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) async {
    final local = _local(input, country);
    final row = ['700001', '70002'].contains(local) ? _listing(local!) : null;
    return ResolveResponse(
        status: row == null ? 'not_found' : 'resolved',
        countryContext: country,
        input: input,
        listing: row);
  }
}
