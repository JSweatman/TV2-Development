import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/saved_collections.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Address Book and Bookmarks keep independent folders and aliases', () async {
    final store = await SavedCollections.open();
    await store.save(
      kind: SavedCollections.bookmarksKind,
      newFolderName: 'Family',
      qualifiedIdentity: '91*529',
      ownerTitle: 'Owner Title',
      alias: 'Story source',
    );
    await store.save(
      kind: SavedCollections.addressBookKind,
      newFolderName: 'Family',
      qualifiedIdentity: '91*529',
      ownerTitle: 'Owner Title',
      alias: 'My sister',
    );

    expect(store.folders(), hasLength(2));
    expect(store.folders(kind: SavedCollections.bookmarksKind).single.label, 'Family');
    expect(store.folders(kind: SavedCollections.addressBookKind).single.label, 'Family');
    expect(store.bookmarks(kind: SavedCollections.bookmarksKind).single.displayTitle, 'Story source');
    expect(store.bookmarks(kind: SavedCollections.addressBookKind).single.displayTitle, 'My sister');

    final reopened = await SavedCollections.open();
    expect(reopened.bookmarks(kind: SavedCollections.addressBookKind).single.qualifiedIdentity, '91*529');
    expect(reopened.bookmarks(kind: SavedCollections.bookmarksKind).single.qualifiedIdentity, '91*529');
  });

  test('removing contact does not remove same listing from Bookmarks', () async {
    final store = await SavedCollections.open();
    await store.save(newFolderName: 'News', qualifiedIdentity: '1*529', ownerTitle: 'Source');
    await store.save(
      kind: SavedCollections.addressBookKind,
      newFolderName: 'Family',
      qualifiedIdentity: '1*529',
      ownerTitle: 'Source',
      alias: 'Contact',
    );
    final contact = store.bookmarks(kind: SavedCollections.addressBookKind).single;
    await store.remove(folderId: contact.folderId, qualifiedIdentity: contact.qualifiedIdentity);
    expect(store.bookmarks(kind: SavedCollections.addressBookKind), isEmpty);
    expect(store.bookmarks(kind: SavedCollections.bookmarksKind).single.displayTitle, 'Source');
  });

  test('cross-collection folder selection is rejected', () async {
    final store = await SavedCollections.open();
    await store.save(
      newFolderName: 'Shared Label',
      qualifiedIdentity: '1*529',
      ownerTitle: 'Source',
    );
    final bookmarkFolder = store.folders(kind: SavedCollections.bookmarksKind).single;
    await expectLater(
      store.save(
        kind: SavedCollections.addressBookKind,
        folderId: bookmarkFolder.id,
        qualifiedIdentity: '1*529',
        ownerTitle: 'Source',
      ),
      throwsArgumentError,
    );
    expect(store.bookmarks(kind: SavedCollections.addressBookKind), isEmpty);
  });

  test('old SAVE data without collection kind remains visible only as Bookmarks', () async {
    SharedPreferences.setMockInitialValues({
      'tv2_saved_collections_v1': jsonEncode({
        'folders': [{'id': 'old', 'label': 'Legacy'}],
        'bookmarks': [{
          'folder_id': 'old',
          'qualified_identity': '*529',
          'owner_title': 'Original Bookmark',
          'alias': null,
        }],
      }),
    });
    final store = await SavedCollections.open();
    expect(store.folders(kind: SavedCollections.bookmarksKind).single.label, 'Legacy');
    expect(store.bookmarks(kind: SavedCollections.bookmarksKind).single.qualifiedIdentity, '*529');
    expect(store.folders(kind: SavedCollections.addressBookKind), isEmpty);
    expect(store.bookmarks(kind: SavedCollections.addressBookKind), isEmpty);

    await store.save(
      kind: SavedCollections.addressBookKind,
      newFolderName: 'Friends',
      qualifiedIdentity: '1*529',
      ownerTitle: 'Friend',
    );
    expect(store.bookmarks(kind: SavedCollections.bookmarksKind).single.qualifiedIdentity, '*529');
  });

  test('Address Book never stores unqualified 529', () async {
    final store = await SavedCollections.open();
    await expectLater(
      store.save(
        kind: SavedCollections.addressBookKind,
        newFolderName: 'Family',
        qualifiedIdentity: '529',
        ownerTitle: 'No namespace',
      ),
      throwsArgumentError,
    );
    expect(store.folders(), isEmpty);
  });
}
