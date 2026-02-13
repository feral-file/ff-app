import 'dart:io';

import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('Old App Data Compatibility', () {
    late AppDatabase db;
    late DatabaseService service;
    late String dbPath;

    setUp(() async {
      final tempDir = Directory.systemTemp.createTempSync('drift_test');
      dbPath = p.join(tempDir.path, 'playlist_cache.sqlite');

      final executor = NativeDatabase(
        File(dbPath),
        setup: (rawDb) {
          rawDb.execute('PRAGMA journal_mode = WAL');
          rawDb.execute('PRAGMA busy_timeout = 5000');
        },
      );

      db = AppDatabase.forTesting(executor);
      service = DatabaseService(db);
    });

    tearDown(() async {
      await db.close();
      try {
        File(dbPath).deleteSync();
      } catch (_) {
        // Ignore cleanup errors
      }
    });

    test('can read channel data written in old app format', () async {
      // Simulate old app writing data using raw SQL
      await db.customStatement('''
        INSERT INTO channels (
          id, type, base_url, slug, title, curator, summary, 
          cover_image_uri, created_at_us, updated_at_us, sort_order
        ) VALUES (
          'ch_old_test',
          0,
          'https://old-feed.com',
          'old-channel',
          'Old Channel',
          'Old Curator',
          'Old summary',
          'https://old-feed.com/cover.jpg',
          1704067200000000,
          1704153600000000,
          1
        )
      ''');

      // Read using new app's service
      final channel = await service.getChannelById('ch_old_test');

      expect(channel, isNotNull);
      expect(channel!.id, equals('ch_old_test'));
      expect(channel.type, equals(ChannelType.dp1));
      expect(channel.name, equals('Old Channel'));
      expect(channel.baseUrl, equals('https://old-feed.com'));
      expect(channel.slug, equals('old-channel'));
      expect(channel.curator, equals('Old Curator'));
      expect(channel.description, equals('Old summary'));
      expect(channel.coverImageUrl, equals('https://old-feed.com/cover.jpg'));
      expect(channel.sortOrder, equals(1));
    });

    test('can read playlist data written in old app format', () async {
      // Simulate old app writing playlist
      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode, 
          item_count
        ) VALUES (
          'pl_old_test',
          'ch_old',
          0,
          'https://old-feed.com',
          '1.0',
          'old-playlist',
          'Old Playlist',
          1704067200000000,
          1704153600000000,
          '["sig1", "sig2"]',
          '{"key": "value"}',
          NULL,
          NULL,
          NULL,
          0,
          5
        )
      ''');

      final playlist = await service.getPlaylistById('pl_old_test');

      expect(playlist, isNotNull);
      expect(playlist!.id, equals('pl_old_test'));
      expect(playlist.type, equals(PlaylistType.dp1));
      expect(playlist.name, equals('Old Playlist'));
      expect(playlist.channelId, equals('ch_old'));
      expect(playlist.baseUrl, equals('https://old-feed.com'));
      expect(playlist.dpVersion, equals('1.0'));
      expect(playlist.slug, equals('old-playlist'));
      expect(playlist.sortMode, equals(PlaylistSortMode.position));
      expect(playlist.itemCount, equals(5));
      expect(playlist.signatures, equals(['sig1', 'sig2']));
      expect(playlist.defaults, equals({'key': 'value'}));
    });

    test('can read address-based playlist from old app', () async {
      // Simulate old app address playlist
      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode,
          item_count
        ) VALUES (
          'addr:ETH:0XABCD1234',
          'my_collection',
          1,
          NULL,
          NULL,
          NULL,
          'ETH: 0xABCD...1234',
          1704067200000000,
          1704153600000000,
          '[]',
          NULL,
          '{"endpoint": "https://indexer.com/graphql"}',
          '0XABCD1234',
          'ETH',
          1,
          10
        )
      ''');

      final playlist = await service.getPlaylistById('addr:ETH:0XABCD1234');

      expect(playlist, isNotNull);
      expect(playlist!.type, equals(PlaylistType.addressBased));
      expect(playlist.ownerAddress, equals('0XABCD1234'));
      expect(playlist.ownerChain, equals('ETH'));
      expect(playlist.sortMode, equals(PlaylistSortMode.provenance));
      expect(playlist.itemCount, equals(10));
    });

    test('can read item (DP1) from old app format', () async {
      // Simulate old app writing a DP1 item
      await db.customStatement('''
        INSERT INTO items (
          id, kind, title, subtitle, thumbnail_uri, duration_sec,
          provenance_json, source_uri, ref_uri, license, repro_json,
          override_json, display_json, token_data_json, updated_at_us
        ) VALUES (
          'item_dp1_old',
          0,
          'Old DP1 Item',
          'Old Artist',
          'https://old.com/thumb.jpg',
          120,
          NULL,
          'https://source.com/item',
          'https://ref.com/item',
          'open',
          NULL,
          NULL,
          NULL,
          NULL,
          1704067200000000
        )
      ''');

      final item = await service.getPlaylistItemById('item_dp1_old');

      expect(item, isNotNull);
      expect(item!.id, equals('item_dp1_old'));
      expect(item.kind, equals(PlaylistItemKind.dp1Item));
      expect(item.title, equals('Old DP1 Item'));
      expect(item.subtitle, equals('Old Artist'));
      expect(item.thumbnailUrl, equals('https://old.com/thumb.jpg'));
      expect(item.duration, equals(120));
      expect(item.source, equals('https://source.com/item'));
      expect(item.license?.value, equals('open'));
    });

    test('can read item (indexer token) from old app format', () async {
      // Simulate old app writing an indexer token
      await db.customStatement('''
        INSERT INTO items (
          id, kind, title, subtitle, thumbnail_uri, duration_sec,
          provenance_json, source_uri, ref_uri, license, repro_json,
          override_json, display_json, token_data_json, updated_at_us
        ) VALUES (
          'cid_old_token',
          1,
          'Old Token',
          'Token Artist',
          'https://old.com/token.jpg',
          NULL,
          '{"sortKeyUs": 1704067200000000}',
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          '{"id": "cid_old_token", "title": "Old Token", "blockchain": "ETH"}',
          1704067200000000
        )
      ''');

      final item = await service.getPlaylistItemById('cid_old_token');

      expect(item, isNotNull);
      expect(item!.id, equals('cid_old_token'));
      expect(item.kind, equals(PlaylistItemKind.indexerToken));
      expect(item.title, equals('Old Token'));
      expect(item.subtitle, equals('Token Artist'));
      expect(item.tokenData, isNotNull);
      expect(item.tokenData!['blockchain'], equals('ETH'));
    });

    test('can read playlist entries from old app format', () async {
      // Insert playlist
      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode,
          item_count
        ) VALUES (
          'pl_with_items',
          'ch_test',
          0,
          NULL,
          NULL,
          NULL,
          'Test Playlist',
          1704067200000000,
          1704153600000000,
          '[]',
          NULL,
          NULL,
          NULL,
          NULL,
          0,
          2
        )
      ''');

      // Insert items
      await db.customStatement('''
        INSERT INTO items (
          id, kind, title, subtitle, thumbnail_uri, duration_sec,
          provenance_json, source_uri, ref_uri, license, repro_json,
          override_json, display_json, token_data_json, updated_at_us
        ) VALUES 
        (
          'item_1',
          1,
          'Item 1',
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          1704067200000000
        ),
        (
          'item_2',
          1,
          'Item 2',
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          1704067200000000
        )
      ''');

      // Insert playlist entries with positions
      await db.customStatement('''
        INSERT INTO playlist_entries (
          playlist_id, item_id, position, sort_key_us, updated_at_us
        ) VALUES 
        ('pl_with_items', 'item_1', 0, 0, 1704067200000000),
        ('pl_with_items', 'item_2', 1, 0, 1704067200000000)
      ''');

      final items = await service.getPlaylistItems('pl_with_items');

      expect(items.length, equals(2));
      expect(items[0].id, equals('item_1'));
      expect(items[1].id, equals('item_2'));
    });

    test('can write data readable by old app format', () async {
      // Write using new app's service
      final channel = Channel(
        id: 'ch_new_test',
        name: 'New Channel',
        type: ChannelType.dp1,
        baseUrl: 'https://new-feed.com',
        slug: 'new-channel',
        curator: 'New Curator',
        description: 'New summary',
        createdAt: DateTime.fromMicrosecondsSinceEpoch(1704067200000000),
        updatedAt: DateTime.fromMicrosecondsSinceEpoch(1704153600000000),
        sortOrder: 2,
      );

      await service.ingestChannel(channel);

      // Read using raw SQL (as old app would)
      final result = await db
          .customSelect(
            'SELECT * FROM channels WHERE id = ?',
            variables: [Variable.withString('ch_new_test')],
          )
          .getSingle();

      expect(result.data['id'], equals('ch_new_test'));
      expect(result.data['type'], equals(0)); // DP1
      expect(result.data['title'], equals('New Channel'));
      expect(result.data['base_url'], equals('https://new-feed.com'));
      expect(result.data['slug'], equals('new-channel'));
      expect(result.data['curator'], equals('New Curator'));
      expect(result.data['summary'], equals('New summary'));
      expect(result.data['sort_order'], equals(2));

      // Verify timestamps are stored as INTEGER (microseconds)
      expect(result.data['created_at_us'], isA<int>());
      expect(result.data['updated_at_us'], isA<int>());
    });

    test('timestamp values are compatible', () async {
      // Old app stored timestamps as INTEGER (microseconds since epoch)
      // New app uses Int64Column which also stores as INTEGER in SQLite

      final testTimestamp = DateTime(2024, 1, 1).microsecondsSinceEpoch;

      // Write using new app
      await db.customStatement('''
        INSERT INTO channels (
          id, type, base_url, slug, title, curator, summary,
          cover_image_uri, created_at_us, updated_at_us, sort_order
        ) VALUES (
          'ch_timestamp_test',
          0,
          NULL,
          NULL,
          'Test',
          NULL,
          NULL,
          NULL,
          $testTimestamp,
          $testTimestamp,
          NULL
        )
      ''');

      final channel = await service.getChannelById('ch_timestamp_test');

      expect(channel, isNotNull);
      expect(
        channel!.createdAt?.microsecondsSinceEpoch,
        equals(testTimestamp),
      );
      expect(
        channel.updatedAt?.microsecondsSinceEpoch,
        equals(testTimestamp),
      );
    });

    test('composite primary key in playlist_entries works', () async {
      // Old app uses (playlist_id, item_id) as composite primary key

      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode,
          item_count
        ) VALUES (
          'pl_pk_test',
          NULL,
          0,
          NULL,
          NULL,
          NULL,
          'Test',
          1704067200000000,
          1704153600000000,
          '[]',
          NULL,
          NULL,
          NULL,
          NULL,
          0,
          0
        )
      ''');

      await db.customStatement('''
        INSERT INTO items (
          id, kind, title, subtitle, thumbnail_uri, duration_sec,
          provenance_json, source_uri, ref_uri, license, repro_json,
          override_json, display_json, token_data_json, updated_at_us
        ) VALUES (
          'item_pk_test',
          1,
          'Test Item',
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          1704067200000000
        )
      ''');

      // Insert entry
      await db.customStatement('''
        INSERT INTO playlist_entries (
          playlist_id, item_id, position, sort_key_us, updated_at_us
        ) VALUES (
          'pl_pk_test',
          'item_pk_test',
          0,
          1704067200000000,
          1704153600000000
        )
      ''');

      // Try to insert duplicate (should fail with constraint violation)
      try {
        await db.customStatement('''
          INSERT INTO playlist_entries (
            playlist_id, item_id, position, sort_key_us, updated_at_us
          ) VALUES (
            'pl_pk_test',
            'item_pk_test',
            1,
            1704067200000000,
            1704153600000000
          )
        ''');
        fail('Should have thrown constraint violation');
      } catch (e) {
        expect(e.toString(), contains('UNIQUE constraint'));
      }
    });

    test('JSON fields are compatible', () async {
      // Old app stored JSON as TEXT
      // Verify we can read and parse correctly

      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode,
          item_count
        ) VALUES (
          'pl_json_test',
          NULL,
          0,
          NULL,
          NULL,
          NULL,
          'Test',
          1704067200000000,
          1704153600000000,
          '["sig1", "sig2", "sig3"]',
          '{"color": "red", "size": 100}',
          '[{"endpoint": "https://indexer.com/graphql", "params": {"owners": "0xabc"}}]',
          NULL,
          NULL,
          0,
          0
        )
      ''');

      final playlist = await service.getPlaylistById('pl_json_test');

      expect(playlist, isNotNull);
      expect(playlist!.signatures, equals(['sig1', 'sig2', 'sig3']));
      expect(playlist.defaults?['color'], equals('red'));
      expect(playlist.defaults?['size'], equals(100));
      expect(
        playlist.dynamicQueries?.first.endpoint,
        equals('https://indexer.com/graphql'),
      );
    });

    test('nullable fields work correctly', () async {
      // Test that nullable fields from old app are handled
      await db.customStatement('''
        INSERT INTO items (
          id, kind, title, subtitle, thumbnail_uri, duration_sec,
          provenance_json, source_uri, ref_uri, license, repro_json,
          override_json, display_json, token_data_json, updated_at_us
        ) VALUES (
          'item_nulls_test',
          0,
          'Minimal Item',
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          NULL,
          1704067200000000
        )
      ''');

      final item = await service.getPlaylistItemById('item_nulls_test');

      expect(item, isNotNull);
      expect(item!.title, equals('Minimal Item'));
      expect(item.subtitle, isNull);
      expect(item.thumbnailUrl, isNull);
      expect(item.duration, equals(0));
      expect(item.provenance, isNull);
      expect(item.tokenData, isNull);
    });

    test('default value for item_count works', () async {
      // Old app used default value of 0 for item_count
      await db.customStatement('''
        INSERT INTO playlists (
          id, channel_id, type, base_url, dp_version, slug, title,
          created_at_us, updated_at_us, signatures_json, defaults_json,
          dynamic_queries_json, owner_address, owner_chain, sort_mode
        ) VALUES (
          'pl_default_test',
          NULL,
          0,
          NULL,
          NULL,
          NULL,
          'Test',
          1704067200000000,
          1704153600000000,
          '[]',
          NULL,
          NULL,
          NULL,
          NULL,
          0
        )
      ''');

      final playlist = await service.getPlaylistById('pl_default_test');

      expect(playlist, isNotNull);
      expect(playlist!.itemCount, equals(0));
    });
  });
}
