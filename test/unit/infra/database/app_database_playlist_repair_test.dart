import 'dart:io';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('AppDatabase malformed playlist repair', () {
    test('repairs malformed favorite row before bootstrap reads it', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'ff_playlist_repair_',
      );
      final dbFile = File(p.join(tempDir.path, 'favorite-malformed.sqlite'));

      try {
        _createMalformedPlaylistDatabase(
          file: dbFile,
          rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                type: 0,
              ),
          ],
        );

        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        final service = DatabaseService(db);

        try {
          await BootstrapService(databaseService: service).bootstrap();

          final favorite = await service.getPlaylistById(Playlist.favoriteId);
          expect(favorite, isNotNull);
          expect(favorite!.name, 'Favorites');
          expect(favorite.type, PlaylistType.favorite);
          expect(favorite.sortMode, PlaylistSortMode.provenance);
          expect(favorite.itemCount, 0);
          expect(favorite.channelId, Channel.myCollectionId);
        } finally {
          await db.close();
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'repairs malformed address playlists before list queries map rows',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(p.join(tempDir.path, 'address-malformed.sqlite'));

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr',
                ownerAddress: '0xABCDEF',
                type: 9,
                updatedAtUs: 55,
                signatures: '',
                sortMode: 99,
                itemCount: -4,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_addr');
            expect(playlists.single.name, '0xABCDEF');
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
            expect(playlists.single.itemCount, 0);
            expect(playlists.single.createdAt!.microsecondsSinceEpoch, 55);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );
  });
}

class _RawPlaylistRow {
  const _RawPlaylistRow({
    required this.id,
    this.type,
    this.updatedAtUs,
    this.signatures,
    this.ownerAddress,
    this.sortMode,
    this.itemCount,
  });

  final String id;
  final int? type;
  final int? updatedAtUs;
  final String? signatures;
  final String? ownerAddress;
  final int? sortMode;
  final int? itemCount;
}

void _createMalformedPlaylistDatabase({
  required File file,
  required List<_RawPlaylistRow> rows,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    final setupStatements = <String>[
      'PRAGMA foreign_keys = ON;',
      'PRAGMA user_version = 3;',
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
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        channel_id TEXT,
        type INTEGER,
        base_url TEXT,
        dp_version TEXT,
        slug TEXT,
        title TEXT,
        created_at_us INTEGER,
        updated_at_us INTEGER,
        signature TEXT,
        signatures TEXT,
        defaults_json TEXT,
        dynamic_queries_json TEXT,
        owner_address TEXT,
        owner_chain TEXT,
        sort_mode INTEGER,
        item_count INTEGER
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
        enrichment_status INTEGER NOT NULL DEFAULT 0,
        updated_at_us INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE playlist_entries (
        playlist_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        position INTEGER,
        sort_key_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL
      )
      ''',
    ];
    void executeStatement(String statement) => db.execute(statement);
    setupStatements.forEach(executeStatement);

    for (final row in rows) {
      db.execute(
        '''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signature, signatures,
          defaults_json, dynamic_queries_json, owner_address, owner_chain,
          sort_mode, item_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          row.id,
          null,
          row.type,
          null,
          null,
          null,
          null,
          null,
          row.updatedAtUs,
          null,
          row.signatures,
          null,
          null,
          row.ownerAddress,
          null,
          row.sortMode,
          row.itemCount,
        ],
      );
    }
  } finally {
    db.dispose();
  }
}
