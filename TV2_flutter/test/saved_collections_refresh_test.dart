import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:tv2/saved_listing_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Test the persistent platform independently of SharedPreferences' local cache.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:tv2/saved_collections.dart';

const key = 'flutter.tv2_saved_collections_v1';
Future<Map<String, dynamic>> persisted() async => jsonDecode(
    (await SharedPreferencesStorePlatform.instance.getAll())[key] as String);
Future<void> externalRecord() async {
  final doc = await persisted();
  (doc['bookmarks'] as List).add({
    'folder_id': (doc['folders'] as List).first['id'],
    'kind': 'bookmarks',
    'qualified_identity': '81*530',
    'owner_title': 'Other publisher',
    'alias': 'Other private name',
  });
  await SharedPreferencesStorePlatform.instance
      .setValue('String', key, jsonEncode(doc));
}

class DelayedStore extends InMemorySharedPreferencesStore {
  DelayedStore(Map<String, Object> data) : super.withData(data);
  Completer<Map<String, Object>>? next;
  @override
  Future<Map<String, Object>> getAll() {
    final held = next;
    next = null;
    return held?.future ?? super.getAll();
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  for (final operation in ['save', 'remove', 'forget', 'open']) {
    test(
        '$operation refreshes completed external changes, preserving unrelated records',
        () async {
      final store = await SavedCollections.open();
      await store.save(
          newFolderName: 'Samples',
          qualifiedIdentity: '1*529',
          ownerTitle: 'Publisher',
          alias: 'Private alias');
      final folder = store.folders().single.id;
      await externalRecord(); // A completed write in another tab, not a race.
      switch (operation) {
        case 'save':
          await store.save(
              folderId: folder,
              qualifiedIdentity: '*531',
              ownerTitle: 'Global');
        case 'remove':
          await store.remove(folderId: folder, qualifiedIdentity: '1*529');
        case 'forget':
          await store.forgetPublisherTitle('1*529');
        case 'open':
          expect((await SavedCollections.open()).bookmarks(), hasLength(2));
      }
      final doc = await persisted();
      final other = (doc['bookmarks'] as List)
          .where((r) => r['qualified_identity'] == '81*530')
          .single;
      expect(other['alias'], 'Other private name');
      expect(other['owner_title'], 'Other publisher');
      expect(other['folder_id'], folder);
      if (operation == 'forget') {
        final seed = (doc['bookmarks'] as List)
            .where((r) => r['qualified_identity'] == '1*529')
            .single;
        expect(seed['owner_title'], '');
        expect(seed['alias'], 'Private alias');
        expect(seed['folder_id'], folder);
      }
    });
  }
  test('superseded title evidence is checked after persisted reload', () async {
    final store = await SavedCollections.open();
    await store.save(
        newFolderName: 'Samples',
        qualifiedIdentity: '1*529',
        ownerTitle: 'Publisher');
    final backend =
        DelayedStore(await SharedPreferencesStorePlatform.instance.getAll());
    SharedPreferencesStorePlatform.instance = backend;
    final snapshot = await backend.getAll();
    final held = Completer<Map<String, Object>>();
    backend.next = held;
    var current = true;
    final done = store.forgetPublisherTitle('1*529', isCurrent: () => current);
    current = false;
    held.complete(snapshot);
    await done;
    expect((await persisted())['bookmarks'].single['owner_title'], 'Publisher');
  });

  testWidgets('older collection refresh cannot repaint newer rows', (t) async {
    final store = await SavedCollections.open();
    await store.save(
        newFolderName: 'Samples',
        qualifiedIdentity: '1*529',
        ownerTitle: 'Old publisher');
    final old = await SharedPreferencesStorePlatform.instance.getAll();
    final backend = DelayedStore(old);
    SharedPreferencesStorePlatform.instance = backend;
    await t.pumpWidget(MaterialApp(home: SavedFoldersScreen(onOpen: (_) {})));
    await t.pumpAndSettle();
    await t.tap(find.text('Samples'));
    await t.pumpAndSettle();
    expect(find.text('Old publisher'), findsOneWidget);
    final held = Completer<Map<String, Object>>();
    backend.next = held;
    SavedCollections.changes.notifyListeners();
    await t.pump();
    final doc = jsonDecode(old[key] as String);
    doc['bookmarks'][0]['owner_title'] = 'Current publisher';
    await backend.setValue('String', key, jsonEncode(doc));
    SavedCollections.changes.notifyListeners();
    await t.pumpAndSettle();
    expect(find.text('Current publisher'), findsOneWidget);
    held.complete(old);
    await t.pumpAndSettle();
    expect(find.text('Current publisher'), findsOneWidget);
    expect(find.text('Old publisher'), findsNothing);
  });
}
