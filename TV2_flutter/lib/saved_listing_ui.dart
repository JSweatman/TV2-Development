import 'package:flutter/material.dart';

import 'models.dart';
import 'saved_collections.dart';

/// This SAVE action belongs to the native TV2 listing preview. External
/// partner-hosted pages will need a separate trusted app link / embed later.
class SaveListingAction extends StatelessWidget {
  const SaveListingAction({super.key, required this.listing});

  final Listing listing;

  Future<void> _save(BuildContext context) async {
    try {
      final store = await SavedCollections.open();
      if (!context.mounted) return;
      final saved = await showDialog<bool>(
        context: context,
        builder: (_) => _SaveListingDialog(store: store, listing: listing),
      );
      if (saved == true && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing saved to your device.')),
        );
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open saved folders on this device.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: 'Save listing',
        icon: const Icon(Icons.bookmark_add_outlined),
        onPressed: () => _save(context),
      );
}

class _SaveListingDialog extends StatefulWidget {
  const _SaveListingDialog({required this.store, required this.listing});

  final SavedCollections store;
  final Listing listing;

  @override
  State<_SaveListingDialog> createState() => _SaveListingDialogState();
}

class _SaveListingDialogState extends State<_SaveListingDialog> {
  final newFolderController = TextEditingController();
  final aliasController = TextEditingController();
  late final List<SavedFolder> existingFolders;
  late bool creatingFolder;
  String? selectedFolderId;
  String? error;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    existingFolders = widget.store.folders();
    creatingFolder = existingFolders.isEmpty;
    selectedFolderId = existingFolders.isEmpty ? null : existingFolders.first.id;
  }

  @override
  void dispose() {
    newFolderController.dispose();
    aliasController.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final folderLabel = newFolderController.text.trim();
    if (creatingFolder && folderLabel.isEmpty) {
      setState(() => error = 'Enter a folder name.');
      return;
    }
    setState(() {
      saving = true;
      error = null;
    });
    try {
      await widget.store.save(
        newFolderName: creatingFolder ? folderLabel : null,
        folderId: creatingFolder ? null : selectedFolderId,
        qualifiedIdentity: widget.listing.qualifiedIdentity,
        ownerTitle: widget.listing.displayName,
        alias: aliasController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (failure) {
      if (!mounted) return;
      setState(() {
        saving = false;
        error = failure is ArgumentError ? failure.message.toString() : 'Unable to save the listing.';
      });
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Save listing'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.listing.displayName, style: Theme.of(context).textTheme.titleMedium),
              Text(widget.listing.qualifiedIdentity),
              const SizedBox(height: 16),
              TextField(
                controller: aliasController,
                maxLength: 120,
                decoration: InputDecoration(
                  labelText: 'Custom listing name (optional)',
                  helperText: 'Leave blank to use the owner\'s title.',
                  border: const OutlineInputBorder(),
                ),
              ),
              if (existingFolders.isNotEmpty)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Create new folder'),
                  value: creatingFolder,
                  onChanged: saving ? null : (value) => setState(() => creatingFolder = value),
                ),
              if (creatingFolder)
                TextField(
                  controller: newFolderController,
                  maxLength: 80,
                  decoration: const InputDecoration(
                    labelText: 'New folder name',
                    border: OutlineInputBorder(),
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  value: selectedFolderId,
                  decoration: const InputDecoration(
                    labelText: 'Existing folder',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final folder in existingFolders)
                      DropdownMenuItem(value: folder.id, child: Text(folder.label)),
                  ],
                  onChanged: saving ? null : (value) => setState(() => selectedFolderId = value),
                ),
              const SizedBox(height: 8),
              Text(
                'Stored on this device. Update alerts and landing-page sync are not yet available.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: saving ? null : _commit,
            child: Text(saving ? 'Saving…' : 'Save'),
          ),
        ],
      );
}

/// First-phase native folders viewer. Final HOME/personal landing-page
/// integration is deferred until authenticated personal pages are available.
class SavedFoldersScreen extends StatefulWidget {
  const SavedFoldersScreen({super.key, required this.onOpen});

  final ValueChanged<SavedBookmark> onOpen;

  @override
  State<SavedFoldersScreen> createState() => _SavedFoldersScreenState();
}

class _SavedFoldersScreenState extends State<SavedFoldersScreen> {
  SavedCollections? store;
  List<SavedFolder> folders = const [];
  List<SavedBookmark> bookmarks = const [];
  String? error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    try {
      final next = await SavedCollections.open();
      final nextFolders = next.folders();
      final nextBookmarks = next.bookmarks();
      if (!mounted) return;
      setState(() {
        store = next;
        folders = nextFolders;
        bookmarks = nextBookmarks;
        error = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => error = 'Saved folders could not be loaded from this device.');
    }
  }

  Future<void> _remove(SavedBookmark entry) async {
    try {
      await store!.remove(
        folderId: entry.folderId,
        qualifiedIdentity: entry.qualifiedIdentity,
      );
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to remove this bookmark.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Saved folders')),
        body: error != null
            ? Center(child: Text(error!))
            : store == null
                ? const Center(child: CircularProgressIndicator())
                : folders.isEmpty
                    ? const Center(child: Text('No saved folders yet. Open a listing and tap Save listing.'))
                    : ListView(
                        children: [
                          for (final folder in folders)
                            ExpansionTile(
                              key: ValueKey(folder.id),
                              title: Text(folder.label),
                              subtitle: Text(
                                '${bookmarks.where((item) => item.folderId == folder.id).length} saved listings',
                              ),
                              children: [
                                for (final item in bookmarks.where(
                                  (record) => record.folderId == folder.id,
                                ))
                                  ListTile(
                                    title: Text(item.displayTitle),
                                    subtitle: Text(item.qualifiedIdentity),
                                    onTap: () => widget.onOpen(item),
                                    trailing: IconButton(
                                      tooltip: 'Remove bookmark',
                                      onPressed: () => _remove(item),
                                      icon: const Icon(Icons.bookmark_remove_outlined),
                                    ),
                                  ),
                              ],
                            ),
                        ],
                      ),
      );
}
