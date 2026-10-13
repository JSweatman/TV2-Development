import 'package:flutter_test/flutter_test.dart';
import 'package:tv2/models.dart';

void main() {
  test('country namespace model parses server-driven settings', () {
    final country = CountryNamespace.fromJson({
      'iso2': 'JP',
      'country_name': 'Japan',
      'nid': '81',
      'default_language_tag': 'ja-JP',
    });
    expect(country.countryName, 'Japan');
    expect(country.nid, '81');
  });

  test('listing model parses generic configured resources', () {
    final listing = Listing.fromJson({
      'country_code': '1',
      'list_number': '529',
      'tldx': null,
      'display_name': 'Fixture',
      'entity_type': 'business',
      'template_key': 'basic',
      'resources': [
        {'key': 'call', 'type': 'call', 'uri': null, 'metadata': {}},
        {'key': 'web', 'type': 'web', 'uri': 'https://example.com', 'metadata': {}},
      ],
      'buttons': [
        {'slot': 1, 'label': 'CALL', 'resource_key': 'call'},
      ],
    });
    expect(listing.qualifiedIdentity, '1*529');
    expect(listing.hasType('call'), isTrue);
    expect(listing.resource('web')?.uri, 'https://example.com');
  });
}
