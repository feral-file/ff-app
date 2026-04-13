import 'dart:io';

import 'package:app/domain/extensions/playlist_ext.dart';
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
    final canonicalAddressPlaylistId = PlaylistExt.addressPlaylistId(
      '0xABCDEF',
    );

    test(
      'repairs favorite rows when sort mode is the only wrong field',
      () async {
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
                channelId: Channel.myCollectionId,
                type: 2,
                sortMode: 0,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            await BootstrapService(databaseService: service).bootstrap();

            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.id, Playlist.favoriteId);
            expect(favorite.type, PlaylistType.favorite);
            expect(favorite.channelId, Channel.myCollectionId);
            expect(favorite.sortMode, PlaylistSortMode.provenance);
            expect(favorite.itemCount, 0);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'clears stray owner address from canonical favorite rows',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-stray-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 2,
                sortMode: 1,
                itemCount: 0,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.type, PlaylistType.favorite);
            expect(favorite.ownerAddress, isNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'restores personal playlists when type drifted to address '
      'but channel drifted to a dp1 channel',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-address-type-with-stray-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_address_type_stray_owner',
                channelId: 'channel_dp1',
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(
              playlists.single.id,
              PlaylistExt.addressPlaylistId('0xABCDEF'),
            );
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'restores the canonical favorite title '
      'even when a wrong title is present',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-wrong-title.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                type: 2,
                title: 'My Playlist',
                sortMode: 1,
                itemCount: 0,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.name, 'Favorites');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'deletes non-canonical favorite rows',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'non-canonical-favorite.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_fake_favorite',
                channelId: Channel.myCollectionId,
                type: 2,
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, isEmpty);
            final deleted = await service.getPlaylistById(
              'playlist_fake_favorite',
            );
            expect(deleted, isNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when type is the only wrong field',
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
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 0,
                sortMode: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
            expect(playlists.single.itemCount, 0);
            expect(playlists.single.createdAt, isNotNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when owner address '
      'is the only surviving signal',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-owner-only-signal.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_owner_only',
                ownerAddress: '0xABCDEF',
                title: null,
                createdAtUs: null,
                updatedAtUs: null,
                signatures: null,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when owner address is present '
      'and the stored type drifted to favorite',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(
            tempDir.path,
            'address-owner-favorite-type-null-channel.sqlite',
          ),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_owner_favorite_type',
                ownerAddress: '0xABCDEF',
                type: 2,
                title: null,
                createdAtUs: null,
                updatedAtUs: null,
                signatures: null,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when owner address is present '
      'and the stored type drifted to dp1 with no channel',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-owner-dp1-type-null-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_owner_dp1_type',
                ownerAddress: '0xABCDEF',
                type: 0,
                title: null,
                createdAtUs: null,
                updatedAtUs: null,
                signatures: null,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when channel id is blank whitespace',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-owner-blank-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_blank_channel',
                channelId: '   ',
                ownerAddress: '0xABCDEF',
                type: 0,
                title: null,
                createdAtUs: null,
                updatedAtUs: null,
                signatures: null,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when the stored type drifted to favorite',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-typed-as-favorite.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_favorite_type',
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 2,
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs address playlists when channel is the only wrong field',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-wrong-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr',
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs normal channel playlists when stored type drifted to address',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-typed-as-address.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_address_type',
                channelId: 'channel_dp1',
                type: 1,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_dp1_address_type');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, 'channel_dp1');
            expect(playlists.single.sortMode, PlaylistSortMode.position);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'restores owner-bearing dp1 playlists back to the personal collection',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-with-stray-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_stray_owner',
                channelId: 'channel_dp1',
                ownerAddress: '0xABCDEF',
                type: 0,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'clears whitespace-only owner addresses from otherwise valid '
      'dp1 playlists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-control-whitespace-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_whitespace_owner',
                channelId: 'channel_dp1',
                ownerAddress: '\t',
                type: 0,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_dp1_whitespace_owner');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, 'channel_dp1');
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'keeps healthy address playlists intact',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'healthy-address-playlist.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: canonicalAddressPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 1,
                title: 'My Collection',
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAddressPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'restores canonical address playlists when only channel id drifted',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'canonical-address-channel-drift.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: canonicalAddressPlaylistId,
                channelId: 'channel_dp1',
                ownerAddress: '0xABCDEF',
                type: 0,
                title: 'My Collection',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAddressPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.type, PlaylistType.addressBased);
            expect(playlists.single.channelId, Channel.myCollectionId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.sortMode, PlaylistSortMode.provenance);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'deletes blank-owner address playlists from my collection',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-blank-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr',
                channelId: Channel.myCollectionId,
                type: 1,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, isEmpty);
            final deleted = await service.getPlaylistById('playlist_addr');
            expect(deleted, isNull);
            final items = await service.getItems();
            expect(items, isEmpty);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'deletes blank-owner my-collection playlists with invalid type',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-invalid-type-blank-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_invalid_type',
                channelId: Channel.myCollectionId,
                type: 9,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, isEmpty);
            final deleted = await service.getPlaylistById(
              'playlist_invalid_type',
            );
            expect(deleted, isNull);
            final items = await service.getItems();
            expect(items, isEmpty);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'deletes blank-owner my-collection playlists with dp1 type',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-dp1-type-blank-owner.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_my_collection',
                channelId: Channel.myCollectionId,
                type: 0,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, isEmpty);
            final deleted = await service.getPlaylistById(
              'playlist_dp1_my_collection',
            );
            expect(deleted, isNull);
            final items = await service.getItems();
            expect(items, isEmpty);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'recomputes item count from playlist entries '
      'when stored count is invalid',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-invalid-count.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                type: 2,
                sortMode: 1,
                itemCount: -1,
                entryCount: 2,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.itemCount, 2);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'recomputes stale favorite item counts from playlist entries',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-stale-positive-count.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                channelId: Channel.myCollectionId,
                type: 2,
                sortMode: 1,
                itemCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.itemCount, 0);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'recomputes stale positive item counts for address playlists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-stale-positive-count.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_addr_stale_count',
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 1,
                itemCount: 5,
                entryCount: 2,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlist = await service.getPlaylistById(
              canonicalAddressPlaylistId,
            );
            expect(playlist, isNotNull);
            expect(playlist!.type, PlaylistType.addressBased);
            expect(playlist.itemCount, 2);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'merges repaired address playlists into the canonical wallet playlist id',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-duplicate-canonicalization.sqlite'),
        );
        final canonicalId = canonicalAddressPlaylistId;

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: canonicalId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
                itemIds: const ['shared_item'],
              ),
              const _RawPlaylistRow(
                id: 'playlist_addr_duplicate',
                channelId: 'channel_dp1',
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 0,
                itemCount: 1,
                entryCount: 2,
                itemIds: ['shared_item', 'unique_item'],
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAddressPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.itemCount, 2);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'canonicalizes address playlists even when id is the only wrong field',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-non-canonical-id-only.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'legacy_address_playlist',
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAddressPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'replaces malformed canonical address rows with recoverable duplicates',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-malformed-canonical-replaced.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: canonicalAddressPlaylistId,
                channelId: Channel.myCollectionId,
                type: 1,
                sortMode: 1,
                itemCount: 1,
                entryCount: 1,
                itemIds: const ['stale_item'],
              ),
              const _RawPlaylistRow(
                id: 'playlist_addr_recoverable_duplicate',
                channelId: 'channel_dp1',
                ownerAddress: '0xABCDEF',
                type: 1,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
                itemIds: ['good_item'],
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAddressPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, canonicalAddressPlaylistId);
            expect(playlists.single.ownerAddress, '0xABCDEF');
            expect(playlists.single.itemCount, 1);
            final items = await service.getItems();
            expect(items.map((item) => item.id), ['good_item']);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs non-canonical favorite-typed rows without personal signals '
      'instead of deleting them',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-typed-null-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_favorite_drifted',
                channelId: '   ',
                type: 2,
                title: 'Recovered Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_favorite_drifted');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs blank-owner address-typed rows without my-collection signal '
      'back to dp1 instead of deleting them',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'address-typed-blank-owner-null-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_address_drifted',
                channelId: '   ',
                type: 1,
                title: 'Recovered DP1 Playlist',
                defaultsJson: '{"layout":"wallet"}',
                dynamicQueriesJson: '[{"field":"ownerAddress"}]',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_address_drifted');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
            final repaired = await service.getPlaylistById(
              'playlist_address_drifted',
            );
            expect(repaired, isNotNull);
            expect(repaired!.defaults, isNull);
            expect(repaired.dynamicQueries, isNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'clears stale personal json from already-dp1 rows left by prior repairs',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-stale-personal-json.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_stale_personal_json',
                type: 0,
                title: 'Recovered DP1 Playlist',
                defaultsJson: '{"layout":"wallet"}',
                dynamicQueriesJson: '[{"field":"ownerAddress"}]',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_dp1_stale_personal_json');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.ownerAddress, isNull);
            final repaired = await service.getPlaylistById(
              'playlist_dp1_stale_personal_json',
            );
            expect(repaired, isNotNull);
            expect(repaired!.defaults, isNull);
            expect(repaired.dynamicQueries, isNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs dp1 playlists when channel id drifted to whitespace only',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-whitespace-channel-only-drift.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_whitespace_channel',
                channelId: '   ',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_dp1_whitespace_channel');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, isNull);
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs dp1 playlists when a real channel id has surrounding whitespace',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-surrounding-whitespace-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_trimmed_channel',
                channelId: ' channel_dp1 ',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(playlists.single.id, 'playlist_dp1_trimmed_channel');
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, 'channel_dp1');
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs dp1 playlists when a real channel id has tab and newline drift',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-control-whitespace-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_control_whitespace_channel',
                channelId: '\tchannel_dp1\n',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(
              playlists.single.id,
              'playlist_dp1_control_whitespace_channel',
            );
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, 'channel_dp1');
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs dp1 playlists when a real channel id has '
      'unicode whitespace drift',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'dp1-unicode-whitespace-channel.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_dp1_unicode_whitespace_channel',
                channelId: '\u00A0channel_dp1\u00A0',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, hasLength(1));
            expect(
              playlists.single.id,
              'playlist_dp1_unicode_whitespace_channel',
            );
            expect(playlists.single.type, PlaylistType.dp1);
            expect(playlists.single.channelId, 'channel_dp1');
            expect(playlists.single.ownerAddress, isNull);
            expect(playlists.single.itemCount, 1);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'deletes blank-owner my-collection playlists when owner has '
      'control whitespace',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(
            tempDir.path,
            'my-collection-control-whitespace-owner.sqlite',
          ),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_my_collection_control_owner',
                channelId: '\u00A0my_collection\u00A0',
                ownerAddress: '\t',
                type: 0,
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final playlists = await service.getAllPlaylists();
            expect(playlists, isEmpty);
            final deleted = await service.getPlaylistById(
              'playlist_my_collection_control_owner',
            );
            expect(deleted, isNull);
            final items = await service.getItems();
            expect(items, isEmpty);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'repairs null required fields before bootstrap reads favorite rows',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'favorite-null-required-fields.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: Playlist.favoriteId,
                title: null,
                createdAtUs: null,
                updatedAtUs: null,
                signatures: null,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            await BootstrapService(databaseService: service).bootstrap();

            final favorite = await service.getPlaylistById(Playlist.favoriteId);
            expect(favorite, isNotNull);
            expect(favorite!.id, Playlist.favoriteId);
            expect(favorite.type, PlaylistType.favorite);
            expect(favorite.name, 'Favorites');
            expect(favorite.channelId, Channel.myCollectionId);
            expect(favorite.sortMode, PlaylistSortMode.provenance);
            expect(favorite.itemCount, 0);
            expect(favorite.createdAt, isNotNull);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'skips playlist repair safely when legacy db is missing json columns',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-missing-json-columns.sqlite'),
        );

        try {
          _createPlaylistDatabaseWithoutJsonColumns(file: dbFile);

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);

          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          expect(_hasPlaylistRepairMarker(file: dbFile), isTrue);

          final secondOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'writes the playlist repair marker after first successful open',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-repair-marker.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_marker_target',
                channelId: 'channel_dp1',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            await service.getAllPlaylists();
          } finally {
            await db.close();
          }

          expect(_hasPlaylistRepairMarker(file: dbFile), isTrue);
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'reuses the playlist repair sidecar on an untouched reopen',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-repair-sidecar-reuse.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_marker_sidecar_reuse',
                channelId: 'channel_dp1',
                type: 0,
                title: 'Recovered DP1 Playlist',
                sortMode: 0,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          final sidecarFile = File('${dbFile.path}.playlist_repair_state.json');
          final firstModifiedAtUs = sidecarFile
              .statSync()
              .modified
              .microsecondsSinceEpoch;
          var hashFallbackCount = 0;
          await Future<void>.delayed(const Duration(milliseconds: 10));

          final secondOpenDb = AppDatabase.forTesting(
            NativeDatabase(dbFile),
            onPlaylistRepairHashFallback: () => hashFallbackCount++,
          );
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            hashFallbackCount,
            0,
            reason:
                'untouched reopens should stay on the metadata-only fast path',
          );
          expect(
            sidecarFile.statSync().modified.microsecondsSinceEpoch,
            firstModifiedAtUs,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'reruns repair on later opens when a marked db becomes malformed again',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-repair-marker-reopen.sqlite'),
        );
        final personalPlaylistId = canonicalAddressPlaylistId;

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: personalPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: PlaylistType.addressBased.value,
                title: 'Recovered Personal Playlist',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );
          _insertChannelRow(file: dbFile, id: 'channel_dp1');

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }
          expect(_hasPlaylistRepairMarker(file: dbFile), isTrue);

          _updatePlaylistIdentity(
            file: dbFile,
            playlistId: personalPlaylistId,
            updatedPlaylistId: 'playlist_marker_reopen_noncanonical',
            channelId: 'channel_dp1',
            title: 'Recovered Personal Playlist',
            bumpUpdatedAtUs: false,
          );

          final secondOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            _readPlaylistChannelId(
              file: dbFile,
              playlistId: personalPlaylistId,
            ),
            Channel.myCollectionId,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'reruns repair for copied malformed snapshots even when marker '
      'generation still looks current',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final originalDbFile = File(
          p.join(tempDir.path, 'playlist-repair-marker-original.sqlite'),
        );
        final copiedDbFile = File(
          p.join(tempDir.path, 'playlist-repair-marker-copied.sqlite'),
        );
        final personalPlaylistId = canonicalAddressPlaylistId;

        try {
          _createMalformedPlaylistDatabase(
            file: originalDbFile,
            rows: [
              _RawPlaylistRow(
                id: personalPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: PlaylistType.addressBased.value,
                title: 'Recovered Personal Playlist',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final firstOpenDb = AppDatabase.forTesting(
            NativeDatabase(originalDbFile),
          );
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          await originalDbFile.copy(copiedDbFile.path);
          _copyPlaylistRepairSidecar(
            originalFile: originalDbFile,
            copiedFile: copiedDbFile,
          );
          _updatePlaylistIdentity(
            file: copiedDbFile,
            playlistId: personalPlaylistId,
            updatedPlaylistId: 'playlist_marker_copied_noncanonical',
            channelId: 'channel_dp1',
            title: 'Recovered Personal Playlist',
            bumpUpdatedAtUs: false,
          );
          _forgePlaylistRepairMarkersAsCurrent(file: copiedDbFile);

          final secondOpenDb = AppDatabase.forTesting(
            NativeDatabase(copiedDbFile),
          );
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            _readPlaylistChannelId(
              file: copiedDbFile,
              playlistId: personalPlaylistId,
            ),
            Channel.myCollectionId,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'falls back to repair when the playlist repair sidecar is corrupted',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-repair-sidecar-corrupted.sqlite'),
        );
        final personalPlaylistId = canonicalAddressPlaylistId;

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: personalPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: PlaylistType.addressBased.value,
                title: 'Recovered Personal Playlist',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          File('${dbFile.path}.playlist_repair_state.json').writeAsStringSync(
            '{not-json',
          );
          _updatePlaylistIdentity(
            file: dbFile,
            playlistId: personalPlaylistId,
            updatedPlaylistId: 'playlist_marker_sidecar_corrupted',
            channelId: 'channel_dp1',
            title: 'Recovered Personal Playlist',
            bumpUpdatedAtUs: false,
          );

          final secondOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            _readPlaylistChannelId(
              file: dbFile,
              playlistId: personalPlaylistId,
            ),
            Channel.myCollectionId,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'falls back to repair when writing the playlist repair sidecar fails',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'playlist-repair-sidecar-write-fails.sqlite'),
        );
        final personalPlaylistId = canonicalAddressPlaylistId;
        final tempSidecarDir = Directory(
          '${dbFile.path}.playlist_repair_state.json.tmp',
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: personalPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: PlaylistType.addressBased.value,
                title: 'Recovered Personal Playlist',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          await File('${dbFile.path}.playlist_repair_state.json').delete();
          await tempSidecarDir.create();
          _updatePlaylistIdentity(
            file: dbFile,
            playlistId: personalPlaylistId,
            updatedPlaylistId: 'playlist_marker_sidecar_write_fails',
            channelId: 'channel_dp1',
            title: 'Recovered Personal Playlist',
            bumpUpdatedAtUs: false,
          );

          final secondOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            _readPlaylistChannelId(
              file: dbFile,
              playlistId: personalPlaylistId,
            ),
            Channel.myCollectionId,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'falls back to repair when sidecar fingerprint collection fails',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(
            tempDir.path,
            'playlist-repair-sidecar-fingerprint-fails.sqlite',
          ),
        );
        final personalPlaylistId = canonicalAddressPlaylistId;
        final shmDir = Directory('${dbFile.path}-shm');

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: [
              _RawPlaylistRow(
                id: personalPlaylistId,
                channelId: Channel.myCollectionId,
                ownerAddress: '0xABCDEF',
                type: PlaylistType.addressBased.value,
                title: 'Recovered Personal Playlist',
                sortMode: PlaylistSortMode.provenance.index,
                itemCount: 1,
                entryCount: 1,
              ),
            ],
          );

          final firstOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final firstOpenService = DatabaseService(firstOpenDb);
          try {
            await firstOpenService.getAllPlaylists();
          } finally {
            await firstOpenDb.close();
          }

          await File('${dbFile.path}.playlist_repair_state.json').delete();
          _updatePlaylistIdentity(
            file: dbFile,
            playlistId: personalPlaylistId,
            updatedPlaylistId: 'playlist_marker_sidecar_fingerprint_fails',
            channelId: 'channel_dp1',
            title: 'Recovered Personal Playlist',
            bumpUpdatedAtUs: false,
          );
          await shmDir.create();

          final secondOpenDb = AppDatabase.forTesting(NativeDatabase(dbFile));
          final secondOpenService = DatabaseService(secondOpenDb);
          try {
            await secondOpenService.getAllPlaylists();
          } finally {
            await secondOpenDb.close();
          }

          expect(
            _readPlaylistChannelId(
              file: dbFile,
              playlistId: personalPlaylistId,
            ),
            Channel.myCollectionId,
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'rebuilds playlist search when an existing database '
      'is missing fts tables',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(tempDir.path, 'missing-fts-searchable-playlist.sqlite'),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_searchable',
                channelId: 'channel_dp1',
                type: 0,
                title: 'Searchable Playlist',
                sortMode: 0,
                itemCount: 0,
              ),
            ],
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final results = await service.searchPlaylists('Searchable');
            expect(
              results.map((playlist) => playlist.id),
              contains('playlist_searchable'),
            );
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'rebuilds playlist search when fts tables exist '
      'but triggers are missing',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_repair_',
        );
        final dbFile = File(
          p.join(
            tempDir.path,
            'missing-fts-triggers-searchable-playlist.sqlite',
          ),
        );

        try {
          _createMalformedPlaylistDatabase(
            file: dbFile,
            rows: const [
              _RawPlaylistRow(
                id: 'playlist_searchable_triggerless',
                channelId: 'channel_dp1',
                type: 0,
                title: 'Triggerless Playlist',
                sortMode: 0,
                itemCount: 0,
              ),
            ],
          );
          _createFtsTablesWithoutTriggers(file: dbFile);

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          final service = DatabaseService(db);

          try {
            final results = await service.searchPlaylists('Triggerless');
            expect(
              results.map((playlist) => playlist.id),
              contains('playlist_searchable_triggerless'),
            );
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
    this.channelId,
    this.type,
    this.title = 'Playlist',
    this.createdAtUs = 1,
    this.updatedAtUs = 1,
    this.signatures = '[]',
    this.defaultsJson,
    this.dynamicQueriesJson,
    this.ownerAddress,
    this.sortMode,
    this.itemCount,
    this.entryCount = 0,
    this.itemIds,
  });

  final String id;
  final String? channelId;
  final int? type;
  final String? title;
  final int? createdAtUs;
  final int? updatedAtUs;
  final String? signatures;
  final String? defaultsJson;
  final String? dynamicQueriesJson;
  final String? ownerAddress;
  final int? sortMode;
  final int? itemCount;
  final int entryCount;
  final List<String>? itemIds;
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
        updated_at_us INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, item_id)
      )
      ''',
    ];
    void executeStatement(
      String statement, [
      List<Object?> params = const [],
    ]) => db.execute(statement, params);
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
          row.channelId,
          row.type,
          null,
          null,
          null,
          row.title,
          row.createdAtUs,
          row.updatedAtUs,
          null,
          row.signatures,
          row.defaultsJson,
          row.dynamicQueriesJson,
          row.ownerAddress,
          null,
          row.sortMode,
          row.itemCount,
        ],
      );

      final itemIds =
          row.itemIds ??
          List<String>.generate(
            row.entryCount,
            (i) => '${row.id}_item_$i',
          );
      for (var i = 0; i < itemIds.length; i++) {
        final itemId = itemIds[i];
        executeStatement(
          '''
          INSERT OR IGNORE INTO items (
            id, kind, updated_at_us, enrichment_status
          )
          VALUES (?, ?, ?, ?)
          ''',
          <Object?>[itemId, 0, 1, 0],
        );
        executeStatement(
          '''
          INSERT INTO playlist_entries (
            playlist_id, item_id, position, sort_key_us, updated_at_us
          ) VALUES (?, ?, ?, ?, ?)
          ''',
          <Object?>[row.id, itemId, i, i, 1],
        );
      }
    }
  } finally {
    db.dispose();
  }
}

void _createFtsTablesWithoutTriggers({required File file}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    void executeStatement(String statement) => db.execute(statement);
    executeStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS channels_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    executeStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS playlists_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    executeStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS items_fts
      USING fts5(
        id UNINDEXED,
        title,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
    executeStatement('''
      CREATE VIRTUAL TABLE IF NOT EXISTS item_artists_fts
      USING fts5(
        id UNINDEXED,
        artist_name,
        tokenize = 'unicode61 remove_diacritics 2'
      )
    ''');
  } finally {
    db.dispose();
  }
}

void _insertChannelRow({
  required File file,
  required String id,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    db.execute(
      '''
      INSERT INTO channels (
        id, type, title, created_at_us, updated_at_us
      ) VALUES (?, ?, ?, ?, ?)
      ''',
      <Object?>[id, 0, 'Channel', 1, 1],
    );
  } finally {
    db.dispose();
  }
}

void _createPlaylistDatabaseWithoutJsonColumns({required File file}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    void executeStatement(
      String statement, [
      List<Object?> params = const [],
    ]) => db.execute(statement, params);

    executeStatement('PRAGMA foreign_keys = ON;');
    executeStatement('PRAGMA user_version = 3;');
    executeStatement('''
      CREATE TABLE publishers (
        id INTEGER PRIMARY KEY,
        title TEXT NOT NULL,
        created_at_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL
      )
    ''');
    executeStatement('''
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
    ''');
    executeStatement('''
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
        owner_address TEXT,
        owner_chain TEXT,
        sort_mode INTEGER,
        item_count INTEGER
      )
    ''');
    executeStatement('''
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
    ''');
    executeStatement('''
      CREATE TABLE playlist_entries (
        playlist_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        position INTEGER,
        sort_key_us INTEGER NOT NULL,
        updated_at_us INTEGER NOT NULL,
        PRIMARY KEY (playlist_id, item_id)
      )
    ''');
    executeStatement(
      '''
      INSERT INTO playlists (
        id, channel_id, type, title, created_at_us, updated_at_us, signatures,
        owner_address, sort_mode, item_count
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      <Object?>[
        Playlist.favoriteId,
        Channel.myCollectionId,
        PlaylistType.favorite.value,
        'Favorites',
        1,
        1,
        '[]',
        null,
        PlaylistSortMode.provenance.index,
        0,
      ],
    );
  } finally {
    db.dispose();
  }
}

bool _hasPlaylistRepairMarker({required File file}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    final rows = db.select(
      '''
      SELECT 1
      FROM internal_repair_markers
      WHERE key = 'playlist_repair_v1_completed'
      LIMIT 1
      ''',
    );
    return rows.isNotEmpty;
  } finally {
    db.dispose();
  }
}

void _updatePlaylistIdentity({
  required File file,
  required String playlistId,
  String? updatedPlaylistId,
  String? ownerAddress,
  String? channelId,
  String? title,
  bool bumpUpdatedAtUs = true,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    final updatedAtUs = DateTime.now().microsecondsSinceEpoch;
    final bumpUpdatedAtUsFlag = bumpUpdatedAtUs ? 1 : 0;
    db.execute(
      '''
      UPDATE playlists
      SET id = COALESCE(?, id),
          owner_address = COALESCE(?, owner_address),
          channel_id = COALESCE(?, channel_id),
          title = COALESCE(?, title),
          updated_at_us = CASE
            WHEN ? THEN ?
            ELSE updated_at_us
          END
      WHERE id = ?
      ''',
      <Object?>[
        updatedPlaylistId,
        ownerAddress,
        channelId,
        title,
        bumpUpdatedAtUsFlag,
        updatedAtUs,
        playlistId,
      ],
    );
    if (updatedPlaylistId != null && updatedPlaylistId != playlistId) {
      db.execute(
        '''
        UPDATE playlist_entries
        SET playlist_id = ?,
            updated_at_us = CASE
              WHEN ? THEN ?
              ELSE updated_at_us
            END
        WHERE playlist_id = ?
        ''',
        <Object?>[
          updatedPlaylistId,
          bumpUpdatedAtUsFlag,
          updatedAtUs,
          playlistId,
        ],
      );
    }
  } finally {
    db.dispose();
  }
}

String? _readPlaylistChannelId({
  required File file,
  required String playlistId,
}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    final rows = db.select(
      'SELECT channel_id FROM playlists WHERE id = ?',
      <Object?>[playlistId],
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first.columnAt(0) as String?;
  } finally {
    db.dispose();
  }
}

void _forgePlaylistRepairMarkersAsCurrent({required File file}) {
  final db = sqlite3.sqlite3.open(file.path);
  try {
    void execute(String statement, [List<Object?> params = const []]) =>
        db.execute(statement, params);
    final generationRows = db.select(
      '''
      SELECT completed_at_us
      FROM internal_repair_markers
      WHERE key = 'playlist_repair_v1_generation'
      LIMIT 1
      ''',
    );
    final generation = generationRows.isEmpty
        ? 0
        : generationRows.first.columnAt(0) as int;
    execute(
      '''
      INSERT OR REPLACE INTO internal_repair_markers (key, completed_at_us)
      VALUES ('playlist_repair_v1_completed_generation', ?)
      ''',
      <Object?>[generation],
    );
    execute(
      '''
      INSERT OR REPLACE INTO internal_repair_markers (key, completed_at_us)
      VALUES ('playlist_repair_v1_completed', ?)
      ''',
      <Object?>[generation],
    );
    execute(
      '''
      INSERT OR REPLACE INTO internal_repair_markers (key, completed_at_us)
      VALUES ('playlist_repair_v1_completed_at_us', ?)
      ''',
      <Object?>[1],
    );
  } finally {
    db.dispose();
  }
}

void _copyPlaylistRepairSidecar({
  required File originalFile,
  required File copiedFile,
}) {
  final originalSidecar = File(
    '${originalFile.path}.playlist_repair_state.json',
  );
  if (!originalSidecar.existsSync()) {
    return;
  }
  originalSidecar.copySync('${copiedFile.path}.playlist_repair_state.json');
}
