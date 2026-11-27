import 'models.dart';
import 'resolver_api.dart';
import 'saved_collections.dart';

/// Observes existing exact requests only. No polling or additional lookup.
class SavedTitleResolver implements ResolverApi {
  SavedTitleResolver(this.delegate);
  final ResolverApi delegate;
  final _latest = <String, int>{};
  int _sequence = 0;

  @override
  Future<List<CountryNamespace>> countries() => delegate.countries();

  @override
  Future<PrefixResponse> prefix(
          {required String input, required String country, int limit = 10}) =>
      delegate.prefix(input: input, country: country, limit: limit);

  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) async {
    final value = input.trim();
    final identity = value.contains('*') ? value : '$country*$value';
    final namespace = identity.substring(0, identity.indexOf('*'));
    final expectedCountry = namespace.isEmpty ? null : namespace;
    final ticket = ++_sequence;
    _latest[identity] = ticket;
    try {
      final response = await delegate.resolve(input: input, country: country);
      if (_latest[identity] == ticket &&
          response.status == 'not_found' &&
          response.listing == null &&
          response.countryContext == expectedCountry &&
          response.input.trim() == value) {
        // Invalid input and transport errors never reach this path. Match only
        // a full saved key, including explicit global namespace and suffix.
        final store = await SavedCollections.open();
        if (_latest[identity] == ticket) {
          try {
            await store.forgetPublisherTitle(identity,
                isCurrent: () => _latest[identity] == ticket);
          } catch (_) {
            throw const ResolverApiException(
                'Listing unavailable. Unable to update saved titles on this device.');
          }
        }
      }
      return response;
    } finally {
      if (_latest[identity] == ticket) _latest.remove(identity);
    }
  }
}
