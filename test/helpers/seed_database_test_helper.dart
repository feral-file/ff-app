import 'dart:io';

import 'package:sqlite3/sqlite3.dart' as sqlite3;

void createSeedArtifactDatabase({
  required File file,
  int userVersion = 3,
  bool includePreparedColumns = true,
  bool includeLegacySignaturesJson = false,
  bool includeItemsEnrichmentStatus = true,
  String? signatureValue,
  String signaturesValue = '[]',
  String signaturesJsonValue = '[]',
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db.execute('PRAGMA foreign_keys = ON;');
    final schemaStatements = <String>[
      '''
      CREATE TABLE publishers (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        created_at_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE channels (
        id TEXT PRIMARY KEY,
        type INTEGER NOT NULL,
        base_url TEXT,
        slug TEXT,
        publisher_id INTEGER,
        title TEXT NOT NULL,
        curator TEXT,
        summary TEXT,
        cover_image_uri TEXT,
        created_at_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL,
        sort_order INTEGER
      )
      ''',
      '''
      CREATE TABLE items (
        id TEXT PRIMARY KEY,
        kind INTEGER NOT NULL,
        title TEXT,
        thumbnail_uri TEXT,
        duration_sec INTEGER,
        provenance_json TEXT,
        source_uri TEXT,
        ref_uri TEXT,
        license TEXT,
        repro_json TEXT,
        override_json TEXT,
        display_json TEXT,
        list_artist_json TEXT,
        updated_at_us INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE playlist_entries (
        playlist_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        position INTEGER NOT NULL,
        sort_key_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL
      )
      ''',
    ];

    final playlistColumns = <String>[
      'id TEXT PRIMARY KEY',
      'channel_id TEXT',
      'type INTEGER NOT NULL',
      'base_url TEXT',
      'dp_version TEXT',
      'slug TEXT',
      'title TEXT NOT NULL',
      'created_at_us INTEGER NOT NULL',
      'updated_at_us INTEGER NOT NULL',
      'sort_mode INTEGER NOT NULL',
      'item_count INTEGER NOT NULL',
      'defaults_json TEXT',
      'dynamic_queries_json TEXT',
      'owner_address TEXT',
      'owner_chain TEXT',
      'owner_name TEXT',
    ];
    if (includePreparedColumns) {
      playlistColumns.addAll([
        'signature TEXT',
        "signatures TEXT NOT NULL DEFAULT '[]'",
      ]);
    }
    if (includeLegacySignaturesJson) {
      playlistColumns.add("signatures_json TEXT NOT NULL DEFAULT '[]'");
    }
    schemaStatements.add(
      'CREATE TABLE playlists (${playlistColumns.join(', ')})',
    );

    if (includeItemsEnrichmentStatus) {
      schemaStatements.add(
        'ALTER TABLE items ADD COLUMN enrichment_status INTEGER NOT NULL '
        'DEFAULT 0',
      );
    }

    for (final statement in schemaStatements) {
      db.execute(statement);
    }

    db.execute('PRAGMA user_version = $userVersion');

    final playlistInsertColumns = <String>[
      'id',
      'channel_id',
      'type',
      'base_url',
      'dp_version',
      'slug',
      'title',
      'created_at_us',
      'updated_at_us',
      'sort_mode',
      'item_count',
      'defaults_json',
      'dynamic_queries_json',
      'owner_address',
      'owner_chain',
      'owner_name',
    ];
    final playlistInsertValues = <Object?>[
      'pl',
      null,
      0,
      null,
      '1.0.0',
      'slug',
      'Playlist',
      1,
      1,
      0,
      0,
      null,
      null,
      null,
      null,
      null,
    ];
    if (includePreparedColumns) {
      playlistInsertColumns.addAll(['signature', 'signatures']);
      playlistInsertValues.addAll([signatureValue, signaturesValue]);
    }
    if (includeLegacySignaturesJson) {
      playlistInsertColumns.add('signatures_json');
      playlistInsertValues.add(signaturesJsonValue);
    }
    final placeholders = List.filled(playlistInsertColumns.length, '?').join(
      ', ',
    );
    db.execute(
      'INSERT INTO playlists (${playlistInsertColumns.join(', ')}) '
      'VALUES ($placeholders)',
      playlistInsertValues,
    );
  } finally {
    db.dispose();
  }
}
