import 'package:app/domain/models/channel.dart';
import 'package:app/domain/models/dp1/dp1_manifest.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_item.dart';
import 'package:app/domain/models/playlist.dart';
import 'package:app/domain/models/playlist_item.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:app/infra/database/database_service.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatabaseService', () {
    late AppDatabase db;
    late DatabaseService service;

    setUp(() {
      // Create an in-memory database for testing
      db = AppDatabase.forTesting(NativeDatabase.memory());
      service = DatabaseService(db);
    });

    tearDown(() async {
      await db.close();
    });

    group('Channel operations', () {
      test('ingestChannel inserts channel', () async {
        final channel = Channel(
          id: 'ch_test',
          name: 'Test Channel',
          type: ChannelType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.ingestChannel(channel);

        final retrieved = await service.getChannelById('ch_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'ch_test');
        expect(retrieved.name, 'Test Channel');
      });

      test(
        'watchPlayableChannelsByPublisherId lists only dp1 channels with '
        'playlist entries',
        () async {
          final now = DateTime.now();
          final channels = [
            Channel(
              id: 'ch_with',
              name: 'With',
              type: ChannelType.dp1,
              publisherId: 1,
              createdAt: now,
              updatedAt: now,
            ),
            Channel(
              id: 'ch_without',
              name: 'Without',
              type: ChannelType.dp1,
              publisherId: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ];
          await service.ingestChannels(channels);

          await service.ingestPlaylist(
            Playlist(
              id: 'pl_1',
              name: 'P',
              type: PlaylistType.dp1,
              channelId: 'ch_with',
              createdAt: now,
              updatedAt: now,
            ),
          );
          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'it_1',
              kind: PlaylistItemKind.indexerToken,
              title: 'I',
              updatedAt: now,
            ),
          );
          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          await db.upsertPlaylistEntries(
            [
              PlaylistEntriesCompanion.insert(
                playlistId: 'pl_1',
                itemId: 'it_1',
                position: const Value(0),
                sortKeyUs: BigInt.zero,
                updatedAtUs: nowUs,
              ),
            ],
          );

          final list = await service
              .watchPlayableChannelsByPublisherId(1, type: ChannelType.dp1)
              .first;

          expect(list.map((channel) => channel.id), ['ch_with']);
        },
      );

      test(
        'watchPlayableChannelsByPublisherId re-emits empty when last '
        'playlist entry is removed',
        () async {
          final now = DateTime.now();
          await service.ingestChannels([
            Channel(
              id: 'ch_react',
              name: 'React',
              type: ChannelType.dp1,
              publisherId: 1,
              createdAt: now,
              updatedAt: now,
            ),
          ]);
          await service.ingestPlaylist(
            Playlist(
              id: 'pl_react',
              name: 'P',
              type: PlaylistType.dp1,
              channelId: 'ch_react',
              createdAt: now,
              updatedAt: now,
            ),
          );
          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'it_react',
              kind: PlaylistItemKind.indexerToken,
              title: 'I',
              updatedAt: now,
            ),
          );
          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          await db.upsertPlaylistEntries(
            [
              PlaylistEntriesCompanion.insert(
                playlistId: 'pl_react',
                itemId: 'it_react',
                position: const Value(0),
                sortKeyUs: BigInt.zero,
                updatedAtUs: nowUs,
              ),
            ],
          );

          final emissions = <List<Channel>>[];
          final subscription = service
              .watchPlayableChannelsByPublisherId(1, type: ChannelType.dp1)
              .listen(emissions.add);
          addTearDown(subscription.cancel);

          await Future<void>.delayed(const Duration(milliseconds: 400));
          expect(emissions.last.map((channel) => channel.id), ['ch_react']);

          await service.removePlaylistEntry(
            playlistId: 'pl_react',
            itemId: 'it_react',
          );
          await Future<void>.delayed(const Duration(milliseconds: 400));
          expect(emissions.last, isEmpty);
        },
      );

      test('ingestChannels batch inserts channels', () async {
        final channels = [
          Channel(
            id: 'ch_1',
            name: 'Channel 1',
            type: ChannelType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Channel(
            id: 'ch_2',
            name: 'Channel 2',
            type: ChannelType.localVirtual,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestChannels(channels);

        final retrieved = await service.getChannels();
        expect(retrieved.length, 2);
        expect(retrieved[0].id, 'ch_1');
        expect(retrieved[1].id, 'ch_2');
      });
    });

    group('Playlist operations', () {
      test('ingestPlaylist inserts playlist', () async {
        final playlist = Playlist(
          id: 'pl_test',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        await service.ingestPlaylist(playlist);

        final retrieved = await service.getPlaylistById('pl_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'pl_test');
        expect(retrieved.name, 'Test Playlist');
      });

      test('getPlaylistsByChannel returns correct playlists', () async {
        final playlists = [
          Playlist(
            id: 'pl_1',
            name: 'Playlist 1',
            type: PlaylistType.dp1,
            channelId: 'ch_test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_2',
            name: 'Playlist 2',
            type: PlaylistType.dp1,
            channelId: 'ch_test',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_3',
            name: 'Playlist 3',
            type: PlaylistType.dp1,
            channelId: 'ch_other',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestPlaylists(playlists);

        final retrieved = await service.getPlaylistsByChannel('ch_test');
        expect(retrieved.length, 2);
        expect(retrieved[0].channelId, 'ch_test');
        expect(retrieved[1].channelId, 'ch_test');
      });

      test(
        'getAddressPlaylists returns only address-based playlists',
        () async {
          final playlists = [
            Playlist(
              id: 'pl_dp1',
              name: 'DP1 Playlist',
              type: PlaylistType.dp1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
            Playlist(
              id: 'pl_addr',
              name: 'Address Playlist',
              type: PlaylistType.addressBased,
              ownerAddress: '0xABCD',
              sortMode: PlaylistSortMode.provenance,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ];

          await service.ingestPlaylists(playlists);

          final retrieved = await service.getAddressPlaylists();
          expect(retrieved.length, 1);
          expect(retrieved[0].type, PlaylistType.addressBased);
          expect(retrieved[0].ownerAddress, '0xABCD');
        },
      );

      test(
        'deleteItemsOfAddresses removes entries only, keeps items in DB',
        () async {
          const address = '0xabc123';
          final playlist = Playlist(
            id: 'pl_addr',
            name: 'Address Playlist',
            type: PlaylistType.addressBased,
            ownerAddress: address,
            sortMode: PlaylistSortMode.provenance,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          await service.ingestPlaylists([playlist]);

          final items = [
            PlaylistItem(
              id: 'item_1',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 1',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'item_2',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 2',
              updatedAt: DateTime.now(),
            ),
          ];
          await service.ingestPlaylistItems(items);

          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          await db.upsertPlaylistEntries([
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_addr',
              itemId: 'item_1',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_addr',
              itemId: 'item_2',
              position: const Value(1),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
          ]);
          await db.updatePlaylistItemCount('pl_addr');

          expect(await service.getPlaylistItems('pl_addr'), hasLength(2));

          await service.deleteItemsOfAddresses([address]);

          expect(await service.getPlaylistItems('pl_addr'), isEmpty);
          // Items are kept in DB (only playlist_entries deleted)
          expect(await service.getPlaylistItemById('item_1'), isNotNull);
          expect(await service.getPlaylistItemById('item_2'), isNotNull);
          expect(await service.getPlaylistById('pl_addr'), isNotNull);
        },
      );

      test('getAllPlaylists returns all playlists when type is null', () async {
        final playlists = [
          Playlist(
            id: 'pl_dp1',
            name: 'DP1 Playlist',
            type: PlaylistType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_addr',
            name: 'Address Playlist',
            type: PlaylistType.addressBased,
            ownerAddress: '0xABCD',
            sortMode: PlaylistSortMode.provenance,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestPlaylists(playlists);

        final retrieved = await service.getAllPlaylists();
        expect(
          retrieved.map((p) => p.id).toSet(),
          equals({'pl_dp1', 'pl_addr'}),
        );
      });

      test('getAllPlaylists filters playlists by type', () async {
        final playlists = [
          Playlist(
            id: 'pl_dp1',
            name: 'DP1 Playlist',
            type: PlaylistType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
          Playlist(
            id: 'pl_addr',
            name: 'Address Playlist',
            type: PlaylistType.addressBased,
            ownerAddress: '0xABCD',
            sortMode: PlaylistSortMode.provenance,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        ];

        await service.ingestPlaylists(playlists);

        final dp1 = await service.getAllPlaylists(type: PlaylistType.dp1);
        expect(dp1, hasLength(1));
        expect(dp1.single.id, equals('pl_dp1'));
        expect(dp1.single.type, equals(PlaylistType.dp1));

        final addressBased = await service.getAllPlaylists(
          type: PlaylistType.addressBased,
        );
        expect(addressBased, hasLength(1));
        expect(addressBased.single.id, equals('pl_addr'));
        expect(
          addressBased.single.type,
          equals(PlaylistType.addressBased),
        );
      });

      test(
        'getAllPlaylists orders by publisher ID then playlist created_at ASC',
        () async {
          final t2024 = DateTime.parse('2024-01-01T00:00:00Z');
          final t2025 = DateTime.parse('2025-01-01T00:00:00Z');
          final t2026 = DateTime.parse('2026-01-01T00:00:00Z');

          // Ingest publishers
          await service.ingestPublisher(id: 10, name: 'Publisher 10');
          await service.ingestPublisher(id: 20, name: 'Publisher 20');

          // Ingest channels
          await service.ingestChannels([
            Channel(
              id: 'ch_pub20_a',
              name: 'Channel pub20 A',
              type: ChannelType.dp1,
              publisherId: 20,
              createdAt: t2024,
              updatedAt: t2024,
            ),
            Channel(
              id: 'ch_pub20_b',
              name: 'Channel pub20 B',
              type: ChannelType.dp1,
              publisherId: 20,
              createdAt: t2025,
              updatedAt: t2025,
            ),
            Channel(
              id: 'ch_pub10',
              name: 'Channel pub10',
              type: ChannelType.dp1,
              publisherId: 10,
              createdAt: t2026,
              updatedAt: t2026,
            ),
          ]);

          // Ingest playlists with mixed creation times
          await service.ingestPlaylists([
            // Publisher 20, channel A, newer playlist
            Playlist(
              id: 'pl_pub20_a_new',
              name: 'Playlist pub20 A new',
              type: PlaylistType.dp1,
              channelId: 'ch_pub20_a',
              createdAt: t2024.add(const Duration(minutes: 2)),
              updatedAt: t2024.add(const Duration(minutes: 2)),
            ),
            // Publisher 20, channel A, older playlist
            Playlist(
              id: 'pl_pub20_a_old',
              name: 'Playlist pub20 A old',
              type: PlaylistType.dp1,
              channelId: 'ch_pub20_a',
              createdAt: t2024.add(const Duration(minutes: 1)),
              updatedAt: t2024.add(const Duration(minutes: 1)),
            ),
            // Publisher 20, channel B, playlist
            Playlist(
              id: 'pl_pub20_b',
              name: 'Playlist pub20 B',
              type: PlaylistType.dp1,
              channelId: 'ch_pub20_b',
              createdAt: t2025.add(const Duration(minutes: 1)),
              updatedAt: t2025.add(const Duration(minutes: 1)),
            ),
            // Publisher 10, newer playlist
            Playlist(
              id: 'pl_pub10',
              name: 'Playlist pub10',
              type: PlaylistType.dp1,
              channelId: 'ch_pub10',
              createdAt: t2026.add(const Duration(minutes: 1)),
              updatedAt: t2026.add(const Duration(minutes: 1)),
            ),
          ]);

          final retrieved = await service.getAllPlaylists();

          // Verify ordering: publisher 10 first, then 20
          // Within each publisher, ordered by playlist created_at ASC
          expect(
            retrieved.map((p) => p.id),
            equals([
              'pl_pub10', // Publisher 10
              'pl_pub20_a_old', // Publisher 20, created earlier
              'pl_pub20_a_new', // Publisher 20, created later
              'pl_pub20_b', // Publisher 20, created latest
            ]),
          );
        },
      );
    });

    group('PlaylistItem operations', () {
      test('ingestPlaylistItem inserts item', () async {
        final item = PlaylistItem(
          id: 'item_test',
          kind: PlaylistItemKind.indexerToken,
          title: 'Test Item',
          updatedAt: DateTime.now(),
        );

        await service.ingestPlaylistItem(item);

        final retrieved = await service.getPlaylistItemById('item_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.id, 'item_test');
        expect(retrieved.title, 'Test Item');
      });

      test(
        'watchItemsRevisionSignal emits count updates on item changes',
        () async {
          final firstUpdate = service.watchItemsRevisionSignal().firstWhere(
            (count) => count == 1,
          );

          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'item_a',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item A',
              updatedAt: DateTime.now(),
            ),
          );

          expect(await firstUpdate, 1);

          final secondUpdate = service.watchItemsRevisionSignal().firstWhere(
            (count) => count == 2,
          );
          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'item_b',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item B',
              updatedAt: DateTime.now(),
            ),
          );

          expect(await secondUpdate, 2);
        },
      );

      test('getPlaylistItems returns items in order', () async {
        // Create playlist
        final playlist = Playlist(
          id: 'pl_test',
          name: 'Test Playlist',
          type: PlaylistType.dp1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
        await service.ingestPlaylist(playlist);

        // Create items
        final items = [
          PlaylistItem(
            id: 'item_1',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 1',
            updatedAt: DateTime.now(),
          ),
          PlaylistItem(
            id: 'item_2',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 2',
            updatedAt: DateTime.now(),
          ),
          PlaylistItem(
            id: 'item_3',
            kind: PlaylistItemKind.indexerToken,
            title: 'Item 3',
            updatedAt: DateTime.now(),
          ),
        ];
        await service.ingestPlaylistItems(items);

        // Create entries with positions
        final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
        await db.upsertPlaylistEntries([
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_2',
            position: const Value(0),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_1',
            position: const Value(1),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
          PlaylistEntriesCompanion.insert(
            playlistId: 'pl_test',
            itemId: 'item_3',
            position: const Value(2),
            sortKeyUs: BigInt.zero,
            updatedAtUs: nowUs,
          ),
        ]);

        await db.updatePlaylistItemCount('pl_test');

        final retrieved = await service.getPlaylistItems('pl_test');
        expect(retrieved.length, 3);
        expect(retrieved[0].id, 'item_2');
        expect(retrieved[1].id, 'item_1');
        expect(retrieved[2].id, 'item_3');
      });

      test(
        'getItems and getItemIds order works by publisher, '
        'channel createdAt, then playlist createdAt',
        () async {
          final t2024 = DateTime.parse('2024-01-01T00:00:00Z');
          final t2025 = DateTime.parse('2025-01-01T00:00:00Z');
          final t2026 = DateTime.parse('2026-01-01T00:00:00Z');

          await service.ingestPublisher(id: 10, name: 'Publisher 10');
          await service.ingestPublisher(id: 20, name: 'Publisher 20');

          await service.ingestChannels([
            Channel(
              id: 'ch_pub20_old',
              name: 'Channel pub20 old',
              type: ChannelType.dp1,
              publisherId: 20,
              createdAt: t2024,
              updatedAt: t2024,
            ),
            Channel(
              id: 'ch_pub20_new',
              name: 'Channel pub20 new',
              type: ChannelType.dp1,
              publisherId: 20,
              createdAt: t2025,
              updatedAt: t2025,
            ),
            Channel(
              id: 'ch_pub10',
              name: 'Channel pub10',
              type: ChannelType.dp1,
              publisherId: 10,
              createdAt: t2026,
              updatedAt: t2026,
            ),
          ]);

          await service.ingestPlaylists([
            Playlist(
              id: 'pl_pub20_old',
              name: 'Playlist pub20 old',
              type: PlaylistType.dp1,
              channelId: 'ch_pub20_old',
              createdAt: t2024.add(const Duration(minutes: 1)),
              updatedAt: t2024.add(const Duration(minutes: 1)),
            ),
            Playlist(
              id: 'pl_pub20_new',
              name: 'Playlist pub20 new',
              type: PlaylistType.dp1,
              channelId: 'ch_pub20_new',
              createdAt: t2025.add(const Duration(minutes: 1)),
              updatedAt: t2025.add(const Duration(minutes: 1)),
            ),
            Playlist(
              id: 'pl_pub10',
              name: 'Playlist pub10',
              type: PlaylistType.dp1,
              channelId: 'ch_pub10',
              createdAt: t2026.add(const Duration(minutes: 1)),
              updatedAt: t2026.add(const Duration(minutes: 1)),
            ),
          ]);

          await service.ingestPlaylistItems([
            PlaylistItem(
              id: 'wk_pub20_old',
              kind: PlaylistItemKind.indexerToken,
              title: 'wk_pub20_old',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'wk_pub20_new',
              kind: PlaylistItemKind.indexerToken,
              title: 'wk_pub20_new',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'wk_pub10',
              kind: PlaylistItemKind.indexerToken,
              title: 'wk_pub10',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'wk_orphan',
              kind: PlaylistItemKind.indexerToken,
              title: 'wk_orphan',
              updatedAt: DateTime.now(),
            ),
          ]);

          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          await db.upsertPlaylistEntries([
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_pub20_old',
              itemId: 'wk_pub20_old',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_pub20_new',
              itemId: 'wk_pub20_new',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_pub10',
              itemId: 'wk_pub10',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
          ]);

          final orderedItems = await service.getItems();
          expect(
            orderedItems.map((item) => item.id),
            [
              'wk_pub10',
              'wk_pub20_old',
              'wk_pub20_new',
              'wk_orphan',
            ],
          );

          final orderedIds = await service.getItemIds();
          expect(
            orderedIds,
            [
              'wk_pub10',
              'wk_pub20_old',
              'wk_pub20_new',
              'wk_orphan',
            ],
          );
        },
      );

      test(
        'getPlaylistItemsByChannel returns items from all playlists in channel',
        () async {
          // Channel and two playlists in it
          await service.ingestChannel(
            Channel(
              id: 'ch_test',
              name: 'Test Channel',
              type: ChannelType.dp1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await service.ingestPlaylist(
            Playlist(
              id: 'pl_a',
              name: 'Playlist A',
              type: PlaylistType.dp1,
              channelId: 'ch_test',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          await service.ingestPlaylist(
            Playlist(
              id: 'pl_b',
              name: 'Playlist B',
              type: PlaylistType.dp1,
              channelId: 'ch_test',
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
          // Items and entries: pl_a has item_1, item_2; pl_b has item_3, item_4
          final items = [
            PlaylistItem(
              id: 'item_1',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 1',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'item_2',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 2',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'item_3',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 3',
              updatedAt: DateTime.now(),
            ),
            PlaylistItem(
              id: 'item_4',
              kind: PlaylistItemKind.indexerToken,
              title: 'Item 4',
              updatedAt: DateTime.now(),
            ),
          ];
          await service.ingestPlaylistItems(items);
          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          await db.upsertPlaylistEntries([
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_a',
              itemId: 'item_1',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_a',
              itemId: 'item_2',
              position: const Value(1),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_b',
              itemId: 'item_3',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_b',
              itemId: 'item_4',
              position: const Value(1),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
          ]);

          final all = await service.getPlaylistItemsByChannel('ch_test');
          expect(all.length, 4);

          final page1 = await service.getPlaylistItemsByChannel(
            'ch_test',
            limit: 2,
            offset: 0,
          );
          expect(page1.length, 2);

          final page2 = await service.getPlaylistItemsByChannel(
            'ch_test',
            limit: 2,
            offset: 2,
          );
          expect(page2.length, 2);

          final empty = await service.getPlaylistItemsByChannel('ch_other');
          expect(empty, isEmpty);
        },
      );

      test('deletePlaylistItem removes item and entries', () async {
        final item = PlaylistItem(
          id: 'item_test',
          kind: PlaylistItemKind.indexerToken,
          title: 'Test Item',
          updatedAt: DateTime.now(),
        );
        await service.ingestPlaylistItem(item);

        await service.deletePlaylistItem('item_test');

        final retrieved = await service.getPlaylistItemById('item_test');
        expect(retrieved, isNull);
      });
    });

    group('DP1 Playlist ingestion', () {
      test('ingestDP1Playlist creates playlist with items', () async {
        final dp1Playlist = DP1Playlist(
          dpVersion: '1.0.0',
          id: 'pl_test',
          slug: 'test',
          title: 'Test Playlist',
          created: DateTime.now(),
          items: [
            const DP1PlaylistItem(id: 'item_1', duration: 0, title: 'Item 1'),
            const DP1PlaylistItem(id: 'item_2', duration: 0, title: 'Item 2'),
          ],
        );

        await service.ingestDP1Playlist(
          playlist: dp1Playlist,
          baseUrl: 'https://example.com',
        );

        final retrievedPlaylist = await service.getPlaylistById('pl_test');
        expect(retrievedPlaylist, isNotNull);
        expect(retrievedPlaylist!.itemCount, 2);

        final retrievedItems = await service.getPlaylistItems('pl_test');
        expect(retrievedItems.length, 2);
        expect(retrievedItems[0].id, 'item_1');
        expect(retrievedItems[1].id, 'item_2');
      });
    });

    group('Enrichment priority queries', () {
      test(
        'loadHighPriorityBareItems orders newest-playlist-first '
        'within each batch',
        () async {
          final older = DateTime.now().subtract(const Duration(hours: 1));
          final newer = DateTime.now();

          await service.ingestPlaylists([
            Playlist(
              id: 'pl_old',
              name: 'Old',
              type: PlaylistType.dp1,
              baseUrl: 'https://b.example',
              createdAt: older,
              updatedAt: older,
            ),
            Playlist(
              id: 'pl_new',
              name: 'New',
              type: PlaylistType.dp1,
              baseUrl: 'https://a.example',
              createdAt: newer,
              updatedAt: newer,
            ),
          ]);

          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);

          final itemCompanions = <ItemsCompanion>[];
          final entryCompanions = <PlaylistEntriesCompanion>[];
          for (var i = 0; i < 12; i++) {
            final oldId = 'old_$i';
            final newId = 'new_$i';
            final oldProvenance =
                '{"type":"onChain","contract":{"chain":"evm",'
                '"standard":"erc721","address":"0xold","tokenId":"$i"}}';
            final newProvenance =
                '{"type":"onChain","contract":{"chain":"evm",'
                '"standard":"erc721","address":"0xnew","tokenId":"$i"}}';

            itemCompanions.addAll([
              ItemsCompanion(
                id: Value(oldId),
                kind: const Value(0),
                title: Value('Old $i'),
                provenanceJson: Value(oldProvenance),
                updatedAtUs: Value(nowUs),
              ),
              ItemsCompanion(
                id: Value(newId),
                kind: const Value(0),
                title: Value('New $i'),
                provenanceJson: Value(newProvenance),
                updatedAtUs: Value(nowUs),
              ),
            ]);

            entryCompanions.addAll([
              PlaylistEntriesCompanion.insert(
                playlistId: 'pl_old',
                itemId: oldId,
                position: Value(i),
                sortKeyUs: BigInt.zero,
                updatedAtUs: nowUs,
              ),
              PlaylistEntriesCompanion.insert(
                playlistId: 'pl_new',
                itemId: newId,
                position: Value(i),
                sortKeyUs: BigInt.zero,
                updatedAtUs: nowUs,
              ),
            ]);
          }

          await db.upsertItems(itemCompanions);
          await db.upsertPlaylistEntries(entryCompanions);

          // Two playlists, both fit within the maxItems=48 cap.
          // High-priority = first 8 items per playlist.
          // Expected order: all 8 from pl_new (newest) then all 8 from pl_old.
          final high = await service.loadHighPriorityBareItems(
            maxPerPlaylist: 8,
            maxItems: 48,
          );
          expect(high, hasLength(16));
          for (var i = 0; i < 8; i++) {
            expect(high[i].$3, equals('pl_new'), reason: 'row $i playlist');
            expect(high[i].$1, equals('new_$i'), reason: 'row $i item');
          }
          for (var i = 0; i < 8; i++) {
            expect(
              high[8 + i].$3,
              equals('pl_old'),
              reason: 'row ${8 + i} playlist',
            );
            expect(
              high[8 + i].$1,
              equals('old_$i'),
              reason: 'row ${8 + i} item',
            );
          }

          // Low-priority = items 9-11 per playlist, newest-playlist-first.
          final low = await service.loadLowPriorityBareItems(
            maxPerPlaylist: 8,
            maxTotal: 50,
          );
          expect(low, hasLength(8));
          for (var i = 0; i < 4; i++) {
            expect(low[i].$3, equals('pl_new'), reason: 'low row $i playlist');
            expect(
              low[i].$1,
              equals('new_${i + 8}'),
              reason: 'low row $i item',
            );
          }
          for (var i = 0; i < 4; i++) {
            expect(
              low[4 + i].$3,
              equals('pl_old'),
              reason: 'low row ${4 + i} playlist',
            );
            expect(
              low[4 + i].$1,
              equals('old_${i + 8}'),
              reason: 'low row ${4 + i} item',
            );
          }
        },
      );

      test(
        'loadHighPriorityBareItems: newest playlist first (UI order)',
        () async {
          // Two playlists from the same feed server (same base_url → same
          // publisher partition). The UI renders the newer playlist first
          // (created_at_us DESC); enrichment must follow the same order.
          final older = DateTime.now().subtract(const Duration(hours: 2));
          final newer = DateTime.now();

          await service.ingestPlaylists([
            Playlist(
              id: 'pl_older',
              name: 'Older',
              type: PlaylistType.dp1,
              baseUrl: 'https://same.example',
              createdAt: older,
              updatedAt: older,
            ),
            Playlist(
              id: 'pl_newer',
              name: 'Newer',
              type: PlaylistType.dp1,
              baseUrl: 'https://same.example',
              createdAt: newer,
              updatedAt: newer,
            ),
          ]);

          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          const provenance =
              '{"type":"onChain","contract":{"chain":"evm",'
              '"standard":"erc721","address":"0xabc","tokenId":"1"}}';

          await db.upsertItems([
            ItemsCompanion(
              id: const Value('item_from_older'),
              kind: const Value(0),
              title: const Value('Old item'),
              provenanceJson: const Value(provenance),
              updatedAtUs: Value(nowUs),
            ),
            ItemsCompanion(
              id: const Value('item_from_newer'),
              kind: const Value(0),
              title: const Value('New item'),
              provenanceJson: const Value(provenance),
              updatedAtUs: Value(nowUs),
            ),
          ]);

          await db.upsertPlaylistEntries([
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_older',
              itemId: 'item_from_older',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
            PlaylistEntriesCompanion.insert(
              playlistId: 'pl_newer',
              itemId: 'item_from_newer',
              position: const Value(0),
              sortKeyUs: BigInt.zero,
              updatedAtUs: nowUs,
            ),
          ]);

          final high = await service.loadHighPriorityBareItems(
            maxPerPlaylist: 8,
            maxItems: 48,
          );

          expect(high, hasLength(2));
          // Newer playlist item must come before older playlist item.
          expect(high[0].$3, equals('pl_newer'));
          expect(high[1].$3, equals('pl_older'));
        },
      );

      test(
        'loadHighPriorityBareItems ranks items by playlist_entries.position',
        () async {
          final now = DateTime.now();
          await service.ingestPlaylist(
            Playlist(
              id: 'pl_prov',
              name: 'Prov',
              type: PlaylistType.dp1,
              sortMode: PlaylistSortMode.provenance,
              createdAt: now,
              updatedAt: now,
            ),
          );

          final nowUs = BigInt.from(DateTime.now().microsecondsSinceEpoch);
          const itemIds = ['p0', 'p1', 'p2'];
          const positions = [2, 0, 1];
          final itemCompanions = <ItemsCompanion>[
            for (final id in itemIds)
              ItemsCompanion(
                id: Value(id),
                kind: const Value(0),
                title: Value(id),
                provenanceJson: const Value(
                  '{"type":"onChain","contract":{"chain":"evm",'
                  '"standard":"erc721","address":"0xprov","tokenId":"1"}}',
                ),
                updatedAtUs: Value(nowUs),
              ),
          ];

          final entryCompanions = <PlaylistEntriesCompanion>[
            for (var i = 0; i < itemIds.length; i++)
              PlaylistEntriesCompanion.insert(
                playlistId: 'pl_prov',
                itemId: itemIds[i],
                position: Value(positions[i]),
                sortKeyUs: BigInt.from(i),
                updatedAtUs: nowUs,
              ),
          ];

          await db.upsertItems(itemCompanions);
          await db.upsertPlaylistEntries(entryCompanions);

          final high = await service.loadHighPriorityBareItems(
            maxPerPlaylist: 2,
            maxItems: 48,
          );

          expect(high, hasLength(2));
          expect(high[0].$1, equals('p1')); // position 0
          expect(high[1].$1, equals('p2')); // position 1
        },
      );
    });

    group('FTS search', () {
      test('searches channel, playlist, and item titles locally', () async {
        final now = DateTime.now();

        await service.ingestChannel(
          Channel(
            id: 'ch_fts_1',
            name: 'Moon Channel',
            type: ChannelType.dp1,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await service.ingestChannel(
          Channel(
            id: 'ch_fts_2',
            name: 'Sun Channel',
            type: ChannelType.dp1,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await service.ingestPlaylist(
          Playlist(
            id: 'pl_fts_1',
            name: 'Moonlight Playlist',
            type: PlaylistType.dp1,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await service.ingestPlaylistItem(
          PlaylistItem(
            id: 'wk_fts_1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Moon Work',
            updatedAt: now,
          ),
        );

        final channels = await service.searchChannels('moon');
        final playlists = await service.searchPlaylists('moon');
        final works = await service.searchItems('moon');

        expect(channels.map((c) => c.id), contains('ch_fts_1'));
        expect(channels.map((c) => c.id), isNot(contains('ch_fts_2')));
        expect(playlists.map((p) => p.id), contains('pl_fts_1'));
        expect(works.map((w) => w.id), contains('wk_fts_1'));
      });

      test('searches artist names and returns matching works', () async {
        final now = DateTime.now();

        await service.ingestPlaylistItem(
          PlaylistItem(
            id: 'wk_artist_1',
            kind: PlaylistItemKind.dp1Item,
            title: 'Untitled Work',
            artists: const [
              DP1Artist(name: 'Yayoi Kusama', id: 'artist_1'),
            ],
            updatedAt: now,
          ),
        );

        await service.ingestPlaylistItem(
          PlaylistItem(
            id: 'wk_artist_2',
            kind: PlaylistItemKind.dp1Item,
            title: 'Different Work',
            artists: const [
              DP1Artist(name: 'Takashi Murakami', id: 'artist_2'),
            ],
            updatedAt: now,
          ),
        );

        await service.ingestPlaylistItem(
          PlaylistItem(
            id: 'wk_artist_3',
            kind: PlaylistItemKind.dp1Item,
            title: 'Diacritic Work',
            artists: const [
              DP1Artist(name: 'Björk', id: 'artist_3'),
            ],
            updatedAt: now,
          ),
        );

        final works = await service.searchItems('kusama');
        final diacriticWorks = await service.searchItems('bjork');
        final diacriticInputWorks = await service.searchItems('björk');

        expect(works.map((w) => w.id), contains('wk_artist_1'));
        expect(works.map((w) => w.id), isNot(contains('wk_artist_2')));
        expect(diacriticWorks.map((w) => w.id), contains('wk_artist_3'));
        expect(diacriticInputWorks.map((w) => w.id), contains('wk_artist_3'));
      });

      test('searches channel metadata and playlist owner fields', () async {
        final now = DateTime.now();

        await service.ingestChannel(
          Channel(
            id: 'ch_meta_1',
            name: 'Quiet Channel',
            type: ChannelType.dp1,
            curator: 'Casey Reas',
            description: 'Generative experiments',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await service.ingestChannel(
          Channel(
            id: 'ch_meta_2',
            name: 'Other Channel',
            type: ChannelType.dp1,
            curator: 'Another Curator',
            createdAt: now,
            updatedAt: now,
          ),
        );

        await service.ingestPlaylist(
          Playlist(
            id: 'pl_meta_1',
            name: 'Address Playlist',
            type: PlaylistType.addressBased,
            slug: 'collector-spotlight',
            ownerAddress: '0XABC123',
            createdAt: now,
            updatedAt: now,
          ),
        );

        final curatorChannels = await service.searchChannels('reas');
        final punctuatedCuratorChannels = await service.searchChannels(
          'casey, reas',
        );
        final mismatchedCuratorChannels = await service.searchChannels(
          'casey zzz',
        );
        final summaryChannels = await service.searchChannels(
          'generative',
        );
        final ownerPlaylists = await service.searchPlaylists('abc123');
        final spacedOwnerPlaylists = await service.searchPlaylists('abc 123');
        final slugPlaylists = await service.searchPlaylists(
          'collector',
        );
        final tokenizedSlugPlaylists = await service.searchPlaylists(
          'collector spotlight',
        );

        expect(curatorChannels.map((c) => c.id), contains('ch_meta_1'));
        expect(curatorChannels.map((c) => c.id), isNot(contains('ch_meta_2')));
        expect(
          punctuatedCuratorChannels.map((c) => c.id),
          contains('ch_meta_1'),
        );
        expect(
          mismatchedCuratorChannels.map((c) => c.id),
          isNot(contains('ch_meta_1')),
        );
        expect(summaryChannels.map((c) => c.id), contains('ch_meta_1'));
        expect(ownerPlaylists.map((p) => p.id), contains('pl_meta_1'));
        expect(spacedOwnerPlaylists.map((p) => p.id), contains('pl_meta_1'));
        expect(slugPlaylists.map((p) => p.id), contains('pl_meta_1'));
        expect(tokenizedSlugPlaylists.map((p) => p.id), contains('pl_meta_1'));
      });

      test(
        'searches artist-matched item ids with punctuation and diacritics',
        () async {
          final now = DateTime.now();

          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'wk_artist_ids_1',
              kind: PlaylistItemKind.dp1Item,
              title: 'Dots',
              artists: const [
                DP1Artist(name: 'Yayoi Kusama', id: 'artist_ids_1'),
              ],
              updatedAt: now,
            ),
          );

          await service.ingestPlaylistItem(
            PlaylistItem(
              id: 'wk_artist_ids_2',
              kind: PlaylistItemKind.dp1Item,
              title: 'Vespertine',
              artists: const [
                DP1Artist(name: 'Björk', id: 'artist_ids_2'),
              ],
              updatedAt: now,
            ),
          );

          final punctuationIds = await service.searchArtistMatchedItemIds(
            'kusama,',
          );
          final diacriticIds = await service.searchArtistMatchedItemIds(
            'bjork',
          );
          final diacriticInputIds = await service.searchArtistMatchedItemIds(
            'björk',
          );
          final candidateOnlyIds = await service.searchArtistMatchedItemIds(
            'kusama',
            candidateIds: {'wk_artist_ids_2', 'wk_artist_ids_1'},
          );

          expect(punctuationIds, contains('wk_artist_ids_1'));
          expect(diacriticIds, contains('wk_artist_ids_2'));
          expect(diacriticInputIds, contains('wk_artist_ids_2'));
          expect(candidateOnlyIds, {'wk_artist_ids_1'});
        },
      );
    });

    group('Favorite playlist snapshot and restore', () {
      test(
        'getFavoritePlaylistsSnapshot returns empty when no favorites',
        () async {
          final snapshots = await service.getFavoritePlaylistsSnapshot();
          expect(snapshots, isEmpty);
        },
      );

      test(
        'getFavoritePlaylistsSnapshot and restoreFavoritePlaylistsSnapshot',
        () async {
          final playlist = Playlist.favorite();
          await service.ingestPlaylist(playlist);

          final item = PlaylistItem(
            id: 'fav_item_1',
            kind: PlaylistItemKind.indexerToken,
            title: 'Favorite Work',
            updatedAt: DateTime.now(),
          );
          await service.ingestPlaylistItem(item);

          final nowUs = DateTime.now().microsecondsSinceEpoch;
          await db.upsertPlaylistEntries([
            PlaylistEntriesCompanion.insert(
              playlistId: Playlist.favoriteId,
              itemId: 'fav_item_1',
              sortKeyUs: BigInt.from(nowUs),
              updatedAtUs: BigInt.from(nowUs),
            ),
          ]);
          await db.updatePlaylistItemCount(Playlist.favoriteId);

          final snapshots = await service.getFavoritePlaylistsSnapshot();
          expect(snapshots, hasLength(1));
          expect(snapshots.single.playlist.id, Playlist.favoriteId);
          expect(snapshots.single.items, hasLength(1));
          expect(snapshots.single.items.single.id, 'fav_item_1');

          await db.deletePlaylistEntries(Playlist.favoriteId);
          await db.updatePlaylistItemCount(Playlist.favoriteId);
          expect(await service.getPlaylistItems(Playlist.favoriteId), isEmpty);

          await service.restoreFavoritePlaylistsSnapshot(snapshots);
          final restored = await service.getPlaylistItems(Playlist.favoriteId);
          expect(restored, hasLength(1));
          expect(restored.single.id, 'fav_item_1');
        },
      );
    });

    group('clearAll', () {
      test('removes all data', () async {
        // Insert some data
        await service.ingestChannel(
          Channel(
            id: 'ch_test',
            name: 'Test',
            type: ChannelType.dp1,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        await service.clearAll();

        final channels = await service.getChannels();
        expect(channels, isEmpty);
      });
    });
  });
}
