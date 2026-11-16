import 'package:flutter/material.dart';

import 'saved_collections.dart';
import 'saved_listing_ui.dart';

/// Guest navigation over the existing on-device collections, not a profile.
class HomeNavigationScreen extends StatelessWidget {
  const HomeNavigationScreen({super.key});

  Future<void> _openCollection(BuildContext context, String kind) async {
    final selected = await Navigator.of(context).push<SavedBookmark>(
      MaterialPageRoute(
        builder: (collectionContext) => SavedFoldersScreen(
          kind: kind,
          onOpen: (saved) => Navigator.of(collectionContext).pop(saved),
        ),
      ),
    );
    // Back from a collection stays on Home. Choosing an entry returns that
    // canonical identity through Home to the existing dialer resolver.
    if (selected != null && context.mounted) {
      Navigator.of(context).pop(selected);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Home')),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text('Saved on this device. No account needed.'),
              ),
              ListTile(
                leading: const Icon(Icons.bookmarks_outlined),
                title: const Text('Bookmarks'),
                subtitle: const Text('Your saved listings and folders'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openCollection(context, SavedCollections.bookmarksKind),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.contact_page_outlined),
                title: const Text('Address Book'),
                subtitle: const Text('Contacts you saved in TV2'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    _openCollection(context, SavedCollections.addressBookKind),
              ),
            ],
          ),
        ),
      );
}
