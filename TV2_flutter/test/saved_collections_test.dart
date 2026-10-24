import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv2/saved_collections.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('creates named folder, preserves user alias and canonical identity on reopen', () async {
    final local = await SavedCollections.open();
    await local.save(
      newFolderName: 'Family & News',
      qualifiedIdentity: '91*529',
      ownerTitle: 'Fixture India',
      alias: 'My India Contact',
    );

    final reopened = await SavedCollections.open();
    expect(reopened.folders().single.label, 'Family & News');
    final entry = reopened.bookmarks().single;
    expect(entry.qualifiedIdentity, '91*529');
    expect(entry.ownerTitle, 'Fixture India');
    expect(entry.displayTitle, 'My India Contact');
  });

  test('saving to existing folder respects owner title and avoids duplicates', () async {
    final saved = await SavedCollections.open();
    await saved.save(
      newFolderName: 'Sports',
      qualifiedIdentity: '1*529',
      ownerTitle: 'Team Alpha',
    );
    final id = saved.folders().single.id;
    await saved.save(
      folderId: id,
      qualifiedIdentity: '1*529',
      ownerTitle: 'Team Alpha Revised',
    );
    expect(saved.folders(), hasLength(1));
    expect(saved.bookmarks(folderId: id), hasLength(1));
    expect(saved.bookmarks().single.displayTitle, 'Team Alpha Revised');
  });

  test('different qualified NIDs and Global Code stay distinct in same folder', () async {
    final saved = await SavedCollections.open();
    await saved.save(
      newFolderName: 'Sources',
      qualifiedIdentity: '1*529',
      ownerTitle: 'US Source',
    );
    final folder = saved.folders().single;
    await saved.save(
      folderId: folder.id,
      qualifiedIdentity: '91*529',
      ownerTitle: 'India Source',
    );
    await saved.save(
      folderId: folder.id,
      qualifiedIdentity: '*529',
      ownerTitle: 'Global Source',
    );
    expect(
      saved.bookmarks().map((item) => item.qualifiedIdentity).toSet(),
      {'1*529', '91*529', '*529'},
    );
  });

  test('existing folder is reused by label and removal affects one entry only', () async {
    final saved = await SavedCollections.open();
    await saved.save(
      newFolderName: 'News',
      qualifiedIdentity: '1*529',
      ownerTitle: 'US Source',
    );
    await saved.save(
      newFolderName: 'news',
      qualifiedIdentity: '91*529',
      ownerTitle: 'India Source',
    );
    expect(saved.folders(), hasLength(1));
    final folder = saved.folders().single;
    expect(saved.bookmarks(), hasLength(2));
    await saved.remove(folderId: folder.id, qualifiedIdentity: '1*529');
    expect(saved.bookmarks().single.qualifiedIdentity, '91*529');
  });

  test('never converts bare input into a saved unqualified identity', () async {
    final saved = await SavedCollections.open();
    await expectLater(
      saved.save(
        newFolderName: 'Contacts',
        qualifiedIdentity: '529',
        ownerTitle: 'Unqualified',
      ),
      throwsArgumentError,
    );
    expect(saved.folders(), isEmpty);
  });

  test('corrupted existing bookmarks are reported rather than overwritten', () async {
    SharedPreferences.setMockInitialValues({
      'tv2_saved_collections_v1': '{not-json}',
    });
    final saved = await SavedCollections.open();
    await expectLater(
      saved.save(
        newFolderName: 'Contacts',
        qualifiedIdentity: '1*529',
        ownerTitle: 'Valid',
      ),
      throwsFormatException,
    );
  });
}
