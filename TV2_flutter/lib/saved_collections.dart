import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Local-only MVP. No account sync, remote landing-page writes or push alerts.
/// A future storage adapter can replace SharedPreferences without changing the
/// resolver or the external landing-page provider.
class SavedFolder {
  const SavedFolder({required this.id, required this.label});

  final String id;
  final String label;

  factory SavedFolder.fromJson(Map<String, dynamic> json) => SavedFolder(
        id: json['id'] as String,
        label: json['label'] as String,
      );

  Map<String, dynamic> toJson() => {'id': id, 'label': label};
}

class SavedBookmark {
  const SavedBookmark({
    required this.folderId,
    required this.qualifiedIdentity,
    required this.ownerTitle,
    this.alias,
  });

  final String folderId;
  final String qualifiedIdentity;
  final String ownerTitle;
  final String? alias;

  String get displayTitle => alias?.trim().isNotEmpty == true ? alias!.trim() : ownerTitle;

  factory SavedBookmark.fromJson(Map<String, dynamic> json) => SavedBookmark(
        folderId: json['folder_id'] as String,
        qualifiedIdentity: json['qualified_identity'] as String,
        ownerTitle: json['owner_title'] as String,
        alias: json['alias'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'folder_id': folderId,
        'qualified_identity': qualifiedIdentity,
        'owner_title': ownerTitle,
        'alias': alias,
      };
}

class SavedCollections {
  SavedCollections._(this._prefs);

  static const _key = 'tv2_saved_collections_v1';
  final SharedPreferences _prefs;

  static Future<SavedCollections> open() async =>
      SavedCollections._(await SharedPreferences.getInstance());

  Map<String, dynamic> _read() {
    final raw = _prefs.getString(_key);
    if (raw == null) {
      return {'folders': <dynamic>[], 'bookmarks': <dynamic>[]};
    }
    // Fail visibly on corrupted storage instead of silently overwriting the
    // user's existing folders and bookmarks.
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic> ||
        decoded['folders'] is! List ||
        decoded['bookmarks'] is! List) {
      throw const FormatException('Saved folder data is invalid.');
    }
    return decoded;
  }

  List<SavedFolder> folders() => [
        for (final item in _read()['folders'] as List<dynamic>)
          SavedFolder.fromJson(Map<String, dynamic>.from(item as Map)),
      ];

  List<SavedBookmark> bookmarks({String? folderId}) => [
        for (final item in _read()['bookmarks'] as List<dynamic>)
          if (folderId == null || item['folder_id'] == folderId)
            SavedBookmark.fromJson(Map<String, dynamic>.from(item as Map)),
      ];

  /// Exactly one of [folderId] and [newFolderName] must be provided.
  /// Re-saving an existing identity in a folder updates its alias/title,
  /// rather than creating a duplicate or an additional alert subscription.
  Future<void> save({
    String? folderId,
    String? newFolderName,
    required String qualifiedIdentity,
    required String ownerTitle,
    String? alias,
  }) async {
    final creating = newFolderName != null;
    if ((folderId == null) == !creating) {
      throw ArgumentError('Choose an existing folder or provide a new folder name.');
    }
    if (qualifiedIdentity.trim().isEmpty ||
        ownerTitle.trim().isEmpty ||
        (!qualifiedIdentity.startsWith('*') && !qualifiedIdentity.contains('*'))) {
      throw ArgumentError('A qualified List Number and owner title are required.');
    }

    final doc = _read();
    final folders = foldersFromDoc(doc);
    final records = bookmarksFromDoc(doc);
    String targetId;
    if (creating) {
      final trimmed = newFolderName!.trim();
      if (trimmed.isEmpty || trimmed.length > 80) {
        throw ArgumentError('Folder names must contain 1 to 80 characters.');
      }
      final existing = folders.where(
        (item) => item.label.toLowerCase() == trimmed.toLowerCase(),
      );
      if (existing.isNotEmpty) {
        targetId = existing.first.id;
      } else {
        targetId = 'folder_${DateTime.now().microsecondsSinceEpoch}_${folders.length}';
        folders.add(SavedFolder(id: targetId, label: trimmed));
      }
    } else {
      targetId = folderId!;
      if (!folders.any((item) => item.id == targetId)) {
        throw ArgumentError('The selected folder no longer exists.');
      }
    }

    final cleanedAlias = alias?.trim();
    if (cleanedAlias != null && cleanedAlias.length > 120) {
      throw ArgumentError('Custom names must be 120 characters or shorter.');
    }
    records.removeWhere(
      (item) => item.folderId == targetId &&
          item.qualifiedIdentity == qualifiedIdentity,
    );
    records.add(SavedBookmark(
      folderId: targetId,
      qualifiedIdentity: qualifiedIdentity,
      ownerTitle: ownerTitle,
      alias: cleanedAlias?.isEmpty == true ? null : cleanedAlias,
    ));
    await _write(folders, records);
  }

  Future<void> remove({required String folderId, required String qualifiedIdentity}) async {
    final doc = _read();
    final folders = foldersFromDoc(doc);
    final records = bookmarksFromDoc(doc)
      ..removeWhere(
        (item) =>
            item.folderId == folderId && item.qualifiedIdentity == qualifiedIdentity,
      );
    await _write(folders, records);
  }

  List<SavedFolder> foldersFromDoc(Map<String, dynamic> doc) => [
        for (final item in doc['folders'] as List<dynamic>)
          SavedFolder.fromJson(Map<String, dynamic>.from(item as Map)),
      ];

  List<SavedBookmark> bookmarksFromDoc(Map<String, dynamic> doc) => [
        for (final item in doc['bookmarks'] as List<dynamic>)
          SavedBookmark.fromJson(Map<String, dynamic>.from(item as Map)),
      ];

  Future<void> _write(List<SavedFolder> folders, List<SavedBookmark> bookmarks) async {
    final ok = await _prefs.setString(_key, jsonEncode({
      'folders': [for (final folder in folders) folder.toJson()],
      'bookmarks': [for (final bookmark in bookmarks) bookmark.toJson()],
    }));
    if (!ok) throw StateError('Unable to save bookmarks on this device.');
  }
}
