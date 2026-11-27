import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/models.dart';
import 'package:tv2/saved_collections.dart';
import 'package:tv2/saved_title_resolver.dart';
import 'home_screen_test.dart' show NamespaceAwareApi;

class PendingApi extends NamespaceAwareApi {
  final pending = <Completer<ResolveResponse>>[];
  @override
  Future<ResolveResponse> resolve(
      {required String input, required String country}) {
    final c = Completer<ResolveResponse>();
    pending.add(c);
    return c.future;
  }
}

ResolveResponse response(String input, String status) => ResolveResponse(
    status: status,
    countryContext: input.startsWith('*') ? null : '1',
    input: input,
    listing: null);
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test(
      'global suffix only; default title removed, identical explicit alias retained',
      () async {
    final store = await SavedCollections.open();
    for (final key in ['*529.12', '*529', '1*529.12', '81*529.12']) {
      await store.save(
          newFolderName: 'Folder',
          qualifiedIdentity: key,
          ownerTitle: 'Old title',
          alias: key == '*529.12' ? 'Old title' : null);
    }
    final delegate = PendingApi();
    final api = SavedTitleResolver(delegate);
    final done = api.resolve(input: '*529.12', country: '1');
    delegate.pending.single.complete(response('*529.12', 'not_found'));
    await done;
    final rows = (await SavedCollections.open()).bookmarks();
    final target = rows.firstWhere((r) => r.qualifiedIdentity == '*529.12');
    expect(target.ownerTitle, '');
    expect(target.alias, 'Old title');
    expect(target.displayTitle, 'Old title');
    expect(
        rows
            .where((r) => r.qualifiedIdentity != '*529.12')
            .map((r) => r.ownerTitle),
        everyElement('Old title'));
  });
  test(
      'late unavailable cannot overwrite newer exact outcome; mismatch ignored',
      () async {
    final store = await SavedCollections.open();
    await store.save(
        newFolderName: 'Folder',
        qualifiedIdentity: '1*529',
        ownerTitle: 'Old title');
    final delegate = PendingApi();
    final api = SavedTitleResolver(delegate);
    final old = api.resolve(input: '529', country: '1');
    final fresh = api.resolve(input: '1*529', country: '81');
    delegate.pending[1].complete(response('1*529', 'resolved'));
    await fresh;
    delegate.pending[0].complete(response('529', 'not_found'));
    await old;
    expect(store.bookmarks().single.ownerTitle, 'Old title');
    final mismatch = api.resolve(input: '529', country: '1');
    delegate.pending.last.complete(response('999', 'not_found'));
    await mismatch;
    expect(store.bookmarks().single.ownerTitle, 'Old title');
    final finalCheck = api.resolve(input: '529', country: '1');
    delegate.pending.last.complete(response('529', 'not_found'));
    await finalCheck;
    expect(store.bookmarks().single.ownerTitle, '');
  });
}
