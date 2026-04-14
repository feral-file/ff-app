import 'dart:io';

import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:app/infra/services/bootstrap_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('playlist read resilience', () {
    test('bootstrap survives malformed favorite row from issue #354', () async {
      await _withDatabaseFile('favorite-null-title.sqlite', (dbFile) async {
        _createPlaylistDatabase(
          file: dbFile,
          playlistRows: [
            _RawPlaylistRow(
              id: Playlist.favoriteId,
              channelId: Channel.myCollectionId,
              type: PlaylistType.favorite.value,
              title: null,
              createdAtUs: 1,
              updatedAtUs: 1,
              signatures: '[]',
              sortMode: PlaylistSortMode.provenance.index,
              itemCount: 0,
            ),
          ],
        );

        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        final service = DatabaseService(db);

        try {
          await BootstrapService(databaseService: service).bootstrap();

          final favorite = await service.getPlaylistById(Playlist.favoriteId);
          expect(favorite, isNotNull);
          expect(favorite!.type, PlaylistType.favorite);
          expect(favorite.channelId, Channel.myCollectionId);
          expect(favorite.sortMode, PlaylistSortMode.provenance);
          expect(favorite.name, 'Favorites');
        } finally {
          await db.close();
        }
      });
    });

    test(
      'bootstrap preserves favorite entries when metadata is repaired',
      () async {
        await _withDatabaseFile('favorite-wrong-type.sqlite', (dbFile) async {
          _createPlaylistDatabase(
            file: dbFile,
            playlistRows: [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                type: PlaylistType.dp1.value,
                title: 'Favorites',
                createdAtUs: 1,
                updatedAtUs: 1,
                signatures: '[]',
                sortMode: PlaylistSortMode.position.index,
                itemCount: 1,
              ),
            ],
            itemRows: const [
              _RawItemRow(id: 'item_1', title: 'Saved work'),
            ],
            entryRows: const [
              _RawEntryRow(
                playlistId: Playlist.favoriteId,
                itemId: 'item_1',
                sortKeyUs: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            await BootstrapService(databaseService: service).bootstrap();

            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            final items = await service.getPlaylistItems(Playlist.favoriteId);

            expect(favorite, isNotNull);
            expect(favorite!.type, PlaylistType.favorite);
            expect(favorite.name, 'Favorites');
            expect(favorite.sortMode, PlaylistSortMode.provenance);
            expect(favorite.itemCount, 1);
            expect(items, hasLength(1));
            expect(items.single.id, 'item_1');
          } finally {
            await db.close();
          }
        });
      },
    );

    test(
      'bootstrap repairs favorite title when row is otherwise readable',
      () async {
        await _withDatabaseFile('favorite-wrong-title.sqlite', (dbFile) async {
          _createPlaylistDatabase(
            file: dbFile,
            playlistRows: [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                type: PlaylistType.favorite.value,
                title: 'Saved',
                createdAtUs: 1,
                updatedAtUs: 1,
                signatures: '[]',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 0,
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
            expect(favorite.channelId, Channel.myCollectionId);
          } finally {
            await db.close();
          }
        });
      },
    );

    test(
      'favorite snapshot preserves entries when canonical metadata is '
      'malformed',
      () async {
        await _withDatabaseFile(
          'favorite-snapshot-metadata.sqlite',
          (dbFile) async {
            _createPlaylistDatabase(
              file: dbFile,
              playlistRows: [
                _RawPlaylistRow(
                  id: Playlist.favoriteId,
                  channelId: Channel.myCollectionId,
                  type: PlaylistType.dp1.value,
                  title: 'Favorites',
                  createdAtUs: 1,
                  updatedAtUs: 1,
                  signatures: '[]',
                  sortMode: PlaylistSortMode.position.index,
                  itemCount: 1,
                ),
              ],
              itemRows: const [
                _RawItemRow(id: 'item_1', title: 'Saved work'),
              ],
              entryRows: const [
                _RawEntryRow(
                  playlistId: Playlist.favoriteId,
                  itemId: 'item_1',
                  sortKeyUs: 1,
                ),
              ],
            );

            final db = AppDatabase.forTesting(NativeDatabase(dbFile));
            final service = DatabaseService(db);

            try {
              final snapshots = await service.getFavoritePlaylistsSnapshot();

              expect(snapshots, hasLength(1));
              expect(snapshots.single.playlist.id, Playlist.favoriteId);
              expect(snapshots.single.playlist.type, PlaylistType.favorite);
              expect(
                snapshots.single.playlist.sortMode,
                PlaylistSortMode.provenance,
              );
              expect(snapshots.single.items, hasLength(1));
              expect(snapshots.single.items.single.id, 'item_1');
            } finally {
              await db.close();
            }
          },
        );
      },
    );

    test('getAllPlaylists skips malformed rows instead of crashing', () async {
      await _withDatabaseFile('playlist-read-skip.sqlite', (dbFile) async {
        _createPlaylistDatabase(
          file: dbFile,
          playlistRows: [
            _RawPlaylistRow(
              id: 'broken_playlist',
              channelId: 'channel_dp1',
              type: null,
              title: 'Broken',
              createdAtUs: 1,
              updatedAtUs: 1,
              signatures: '[]',
              sortMode: PlaylistSortMode.position.index,
              itemCount: 0,
            ),
            _RawPlaylistRow(
              id: 'healthy_playlist',
              channelId: 'channel_dp1',
              type: PlaylistType.dp1.value,
              title: 'Healthy',
              createdAtUs: 2,
              updatedAtUs: 2,
              signatures: '[]',
              sortMode: PlaylistSortMode.position.index,
              itemCount: 0,
            ),
          ],
        );

        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        final service = DatabaseService(db);

        try {
          final playlists = await service.getAllPlaylists();

          expect(playlists, hasLength(1));
          expect(playlists.single.id, 'healthy_playlist');
        } finally {
          await db.close();
        }
      });
    });

    test(
      'watchPlaylists emits healthy rows when malformed rows exist',
      () async {
        await _withDatabaseFile('playlist-watch-skip.sqlite', (dbFile) async {
          _createPlaylistDatabase(
            file: dbFile,
            playlistRows: [
              _RawPlaylistRow(
                id: 'broken_playlist',
                channelId: 'channel_dp1',
                type: PlaylistType.dp1.value,
                title: 'Broken',
                createdAtUs: null,
                updatedAtUs: 1,
                signatures: '[]',
                sortMode: PlaylistSortMode.position.index,
                itemCount: 0,
              ),
              _RawPlaylistRow(
                id: 'healthy_playlist',
                channelId: 'channel_dp1',
                type: PlaylistType.dp1.value,
                title: 'Healthy',
                createdAtUs: 2,
                updatedAtUs: 2,
                signatures: '[]',
                sortMode: PlaylistSortMode.position.index,
                itemCount: 0,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.watchPlaylists().first.timeout(
              const Duration(seconds: 2),
            );

            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'healthy_playlist');
          } finally {
            await db.close();
          }
        });
      },
    );

    test(
      'searchPlaylists skips malformed matching rows instead of crashing',
      () async {
        await _withDatabaseFile('playlist-search-skip.sqlite', (dbFile) async {
          final bootstrapDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          await bootstrapDb.getAllChannels();
          await bootstrapDb.close();

          _insertRawPlaylistRow(
            file: dbFile,
            row: _RawPlaylistRow(
              id: 'broken_search_playlist',
              channelId: 'channel_dp1',
              type: 99,
              title: 'Searchable Broken Playlist',
              createdAtUs: 1,
              updatedAtUs: 1,
              signatures: '[]',
              sortMode: PlaylistSortMode.position.index,
              itemCount: 0,
            ),
          );
          _insertRawPlaylistRow(
            file: dbFile,
            row: _RawPlaylistRow(
              id: 'healthy_search_playlist',
              channelId: 'channel_dp1',
              type: PlaylistType.dp1.value,
              title: 'Searchable Healthy Playlist',
              createdAtUs: 2,
              updatedAtUs: 2,
              signatures: '[]',
              sortMode: PlaylistSortMode.position.index,
              itemCount: 0,
            ),
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.searchPlaylists('Searchable');

            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'healthy_search_playlist');
          } finally {
            await db.close();
          }
        });
      },
    );
  });
}

Future<void> _withDatabaseFile(
  String fileName,
  Future<void> Function(File dbFile) body,
) async {
  final tempDir = await Directory.systemTemp.createTemp('ff_issue_354_');
  final dbFile = File(p.join(tempDir.path, fileName));

  try {
    await body(dbFile);
  } finally {
    await tempDir.delete(recursive: true);
  }
}

void _createPlaylistDatabase({
  required File file,
  required List<_RawPlaylistRow> playlistRows,
  List<_RawItemRow> itemRows = const [],
  List<_RawEntryRow> entryRows = const [],
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db
      ..execute('PRAGMA foreign_keys = OFF;')
      ..execute('PRAGMA user_version = 3;')
      ..execute('''
      CREATE TABLE publishers (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        created_at_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL
      )
    ''')
      ..execute('''
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
    ''')
      ..execute('''
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
    ''')
      ..execute('''
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
    ''')
      ..execute('''
      CREATE TABLE playlist_entries (
        playlist_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        position INTEGER,
        sort_key_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, item_id)
      )
    ''');

    final nowUs = DateTime.now().microsecondsSinceEpoch;
    db
      ..execute(
        '''
        INSERT INTO channels (
          id, type, title, created_at_us, updated_at_us, sort_order
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          Channel.myCollectionId,
          ChannelType.localVirtual.index,
          'My Collection',
          nowUs,
          nowUs,
          0,
        ],
      )
      ..execute(
        '''
        INSERT INTO channels (
          id, type, title, created_at_us, updated_at_us, sort_order
        ) VALUES (?, ?, ?, ?, ?, ?)
        ''',
        <Object?>[
          'channel_dp1',
          ChannelType.dp1.index,
          'Channel',
          nowUs,
          nowUs,
          1,
        ],
      );

    for (final row in playlistRows) {
      db.execute(
        '''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signature, signatures, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode,
          item_count
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        row.toSqlValues(),
      );
    }

    for (final row in itemRows) {
      db.execute(
        '''
        INSERT INTO items (
          id, kind, title, thumbnail_uri, duration_sec, provenance_json,
          source_uri, ref_uri, license, repro_json, override_json,
          display_json, list_artist_json, enrichment_status, updated_at_us
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        row.toSqlValues(),
      );
    }

    for (final row in entryRows) {
      db.execute(
        '''
        INSERT INTO playlist_entries (
          playlist_id, item_id, position, sort_key_us, updated_at_us
        ) VALUES (?, ?, ?, ?, ?)
        ''',
        row.toSqlValues(),
      );
    }
  } finally {
    db.dispose();
  }
}

void _insertRawPlaylistRow({
  required File file,
  required _RawPlaylistRow row,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db.execute(
      '''
      INSERT INTO playlists (
        id, channel_id, type, base_url, dp_version, slug, title,
        created_at_us, updated_at_us, signature, signatures, defaults_json,
        dynamic_queries_json, owner_address, owner_chain, sort_mode,
        item_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      row.toSqlValues(),
    );
  } finally {
    db.dispose();
  }
}

class _RawPlaylistRow {
  const _RawPlaylistRow({
    required this.id,
    required this.channelId,
    required this.type,
    required this.title,
    required this.createdAtUs,
    required this.updatedAtUs,
    required this.signatures,
    required this.sortMode,
    required this.itemCount,
  });

  final String id;
  final String? channelId;
  final int? type;
  final String? title;
  final int? createdAtUs;
  final int? updatedAtUs;
  final String? signatures;
  final int? sortMode;
  final int? itemCount;

  List<Object?> toSqlValues() {
    return <Object?>[
      id,
      channelId,
      type,
      null,
      null,
      null,
      title,
      createdAtUs,
      updatedAtUs,
      null,
      signatures,
      null,
      null,
      null,
      null,
      sortMode,
      itemCount,
    ];
  }
}

class _RawItemRow {
  const _RawItemRow({
    required this.id,
    required this.title,
  });

  final String id;
  final String title;

  List<Object?> toSqlValues() {
    final nowUs = DateTime.now().microsecondsSinceEpoch;
    return <Object?>[
      id,
      PlaylistItemKind.indexerToken.index,
      title,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      null,
      0,
      nowUs,
    ];
  }
}

class _RawEntryRow {
  const _RawEntryRow({
    required this.playlistId,
    required this.itemId,
    required this.sortKeyUs,
  });

  final String playlistId;
  final String itemId;
  final int sortKeyUs;

  List<Object?> toSqlValues() {
    return <Object?>[
      playlistId,
      itemId,
      null,
      sortKeyUs,
      sortKeyUs,
    ];
  }
}
