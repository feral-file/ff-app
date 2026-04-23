import 'dart:io';

import 'package:app/domain/models/dp1/dp1_api_responses.dart';
import 'package:app/domain/models/dp1/dp1_playlist.dart';
import 'package:app/domain/models/dp1/dp1_playlist_signature.dart';
import 'package:app/infra/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  group('dp1PlaylistSignaturesFromWire', () {
    test('maps legacy singular signature when signatures missing', () {
      final r = dp1PlaylistSignaturesFromWire({'signature': 'a'});
      expect(r.legacy, 'a');
      expect(r.structured, isEmpty);
    });

    test(
      'ignores string elements in signatures array; falls back to legacy',
      () {
        final r = dp1PlaylistSignaturesFromWire({
          'signature': 'legacy',
          'signatures': ['a', 'b'],
        });
        expect(r.legacy, 'legacy');
        expect(r.structured, isEmpty);
      },
    );

    test('prefers object signatures over legacy signature', () {
      final r = dp1PlaylistSignaturesFromWire({
        'signature': 'legacy',
        'signatures': [
          {'sig': 'x'},
        ],
      });
      expect(r.legacy, 'legacy');
      expect(r.structured.single.sig, 'x');
    });

    test('uses legacy signature when signatures is empty list', () {
      final r = dp1PlaylistSignaturesFromWire({
        'signature': 'legacy',
        'signatures': <dynamic>[],
      });
      expect(r.legacy, 'legacy');
      expect(r.structured, isEmpty);
    });

    test('returns empty when neither field provides values', () {
      final r = dp1PlaylistSignaturesFromWire({});
      expect(r.legacy, isNull);
      expect(r.structured, isEmpty);
      final r2 = dp1PlaylistSignaturesFromWire({'signature': ''});
      expect(r2.legacy, isNull);
      expect(r2.structured, isEmpty);
    });
  });

  group('DP1Playlist JSON', () {
    test('fromJson ignores string-only signatures array', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signatures': ['x', 'y'],
      });
      expect(p.signatures, isEmpty);
    });

    test('fromJson reads signatures array of objects', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signatures': [
          {'sig': 'x'},
          {'sig': 'y'},
        ],
      });
      expect(p.signatures.map((s) => s.sig), ['x', 'y']);
    });

    test('fromJson preserves legacy and structured signatures together', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signature': 'legacy',
        'signatures': [
          {'sig': 'x'},
        ],
      });
      expect(p.legacySignature, 'legacy');
      expect(p.signatures.map((s) => s.sig), ['x']);
    });

    test('fromJson maps legacy signature string to legacySignature', () {
      final p = DP1Playlist.fromJson({
        'dpVersion': '1.0.0',
        'id': 'pl',
        'slug': 's',
        'title': 't',
        'created': '2025-01-01T00:00:00.000Z',
        'items': <dynamic>[],
        'signature': 'only-legacy',
      });
      expect(p.legacySignature, 'only-legacy');
      expect(p.signatures, isEmpty);
    });

    test('toJson emits structured signatures and omits empty legacy', () {
      final p = DP1Playlist(
        dpVersion: '1.0.0',
        id: 'pl',
        slug: 's',
        title: 't',
        created: DateTime.parse('2025-01-01T00:00:00.000Z'),
        items: const [],
        signatures: const [DP1PlaylistSignature(sig: 'a')],
      );
      final map = p.toJson();
      expect(map.containsKey('signature'), isFalse);
      expect(map['signatures'], [
        {'sig': 'a'},
      ]);
    });
  });

  group('DP1PlaylistResponse', () {
    test('normalizes playlist items with legacy signature field', () {
      final r = DP1PlaylistResponse.fromJson({
        'items': [
          {
            'dpVersion': '1.0.0',
            'id': 'pl',
            'slug': 's',
            'title': 't',
            'created': '2025-01-01T00:00:00.000Z',
            'items': <dynamic>[],
            'signature': 'wire',
          },
        ],
        'hasMore': false,
      });
      expect(r.items.single.legacySignature, 'wire');
      expect(r.items.single.signatures, isEmpty);
    });
  });

  group('AppDatabase playlist signature migration', () {
    test('migrates legacy signatures_json on first open', () async {
      final tempDir = await Directory.systemTemp.createTemp('ff_playlist_sig_');
      final dbFile = File(p.join(tempDir.path, 'legacy.sqlite'));
      try {
        _createPlaylistSchemaDatabase(
          file: dbFile,
          userVersion: 3,
          includePreparedColumns: false,
          includeLegacySignaturesJson: true,
          includeItemsEnrichmentStatus: true,
          signatureValue: null,
          signaturesValue: null,
          signaturesJsonValue: '["legacy-signature"]',
        );

        final probeDb = sqlite3.sqlite3.open(dbFile.path);
        try {
          expect(isAppDatabaseSchemaCompatibleForReset(probeDb), isTrue);
        } finally {
          probeDb.dispose();
        }

        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        try {
          final row = await db
              .customSelect(
                "SELECT signature, signatures FROM playlists WHERE id = 'pl'",
              )
              .getSingle();

          expect(row.read<String?>('signature'), 'legacy-signature');
          expect(row.read<String>('signatures'), '[]');
        } finally {
          await db.close();
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('requires the rest of the v3 schema to be intact', () async {
      final tempDir = await Directory.systemTemp.createTemp('ff_playlist_sig_');
      final dbFile = File(p.join(tempDir.path, 'damaged.sqlite'));
      try {
        _createPlaylistSchemaDatabase(
          file: dbFile,
          userVersion: 3,
          includePreparedColumns: false,
          includeLegacySignaturesJson: true,
          includeItemsEnrichmentStatus: false,
          signatureValue: null,
          signaturesValue: null,
          signaturesJsonValue: '["legacy-signature"]',
        );

        final probeDb = sqlite3.sqlite3.open(dbFile.path);
        try {
          expect(isAppDatabaseSchemaCompatibleForReset(probeDb), isFalse);
        } finally {
          probeDb.dispose();
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'accepts user_version 2 without items enrichment_status when v3-shaped',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_sig_v2_no_enrich_',
        );
        final dbFile = File(p.join(tempDir.path, 'v2-no-enrichment.sqlite'));
        try {
          _createPlaylistSchemaDatabase(
            file: dbFile,
            userVersion: 2,
            includePreparedColumns: true,
            includeLegacySignaturesJson: false,
            includeItemsEnrichmentStatus: false,
            signatureValue: 'legacy-preexisting',
            signaturesValue: '[{"sig":"keep"}]',
            signaturesJsonValue: '[]',
          );

          final probeDb = sqlite3.sqlite3.open(dbFile.path);
          try {
            expect(isAppDatabaseSchemaCompatibleForReset(probeDb), isTrue);
            expect(
              shouldSkipDatabaseResetForSchemaConflict(2, probeDb),
              isTrue,
            );
          } finally {
            probeDb.dispose();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'accepts schema-compatible files with migratable user_version',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_sig_',
        );
        final dbFile = File(p.join(tempDir.path, 'version-mismatch.sqlite'));
        try {
          _createPlaylistSchemaDatabase(
            file: dbFile,
            userVersion: 2,
            includePreparedColumns: true,
            includeLegacySignaturesJson: false,
            includeItemsEnrichmentStatus: true,
            signatureValue: 'legacy-preexisting',
            signaturesValue: '[{"sig":"keep"}]',
            signaturesJsonValue: '[]',
          );

          final probeDb = sqlite3.sqlite3.open(dbFile.path);
          try {
            expect(isAppDatabaseSchemaCompatibleForReset(probeDb), isTrue);
            expect(
              shouldSkipDatabaseResetForSchemaConflict(2, probeDb),
              isTrue,
            );
          } finally {
            probeDb.dispose();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test(
      'opens database when user_version is migratable and enrichment column '
      'already exists',
      () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'ff_playlist_sig_',
        );
        final dbFile = File(p.join(tempDir.path, 'migratable-v2.sqlite'));
        try {
          _createPlaylistSchemaDatabase(
            file: dbFile,
            userVersion: 2,
            includePreparedColumns: true,
            includeLegacySignaturesJson: false,
            includeItemsEnrichmentStatus: true,
            signatureValue: 'legacy-preexisting',
            signaturesValue: '[{"sig":"keep"}]',
            signaturesJsonValue: '[]',
          );

          final db = AppDatabase.forTesting(NativeDatabase(dbFile));
          try {
            final playlistRow = await db
                .customSelect(
                  "SELECT signature, signatures FROM playlists WHERE id = 'pl'",
                )
                .getSingle();
            expect(
              playlistRow.read<String?>('signature'),
              'legacy-preexisting',
            );
            expect(playlistRow.read<String>('signatures'), '[{"sig":"keep"}]');

            final itemColumns = await db
                .customSelect("SELECT name FROM pragma_table_info('items')")
                .get();
            final itemColumnNames = itemColumns
                .map((row) => row.read<String>('name'))
                .toSet();
            expect(itemColumnNames.contains('enrichment_status'), isTrue);
          } finally {
            await db.close();
          }
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );

    test('does not clobber prepopulated signatures during rerun', () async {
      final tempDir = await Directory.systemTemp.createTemp('ff_playlist_sig_');
      final dbFile = File(p.join(tempDir.path, 'partial.sqlite'));
      try {
        _createPlaylistSchemaDatabase(
          file: dbFile,
          userVersion: 3,
          includePreparedColumns: true,
          includeLegacySignaturesJson: true,
          includeItemsEnrichmentStatus: true,
          signatureValue: 'legacy-preexisting',
          signaturesValue: '[{"sig":"keep"}]',
          signaturesJsonValue: '["legacy-json"]',
        );

        final db = AppDatabase.forTesting(NativeDatabase(dbFile));
        try {
          final row = await db
              .customSelect(
                "SELECT signature, signatures FROM playlists WHERE id = 'pl'",
              )
              .getSingle();

          expect(row.read<String?>('signature'), 'legacy-preexisting');
          expect(row.read<String>('signatures'), '[{"sig":"keep"}]');
        } finally {
          await db.close();
        }
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

void _createPlaylistSchemaDatabase({
  required File file,
  required int userVersion,
  required bool includePreparedColumns,
  required bool includeLegacySignaturesJson,
  required bool includeItemsEnrichmentStatus,
  required String? signatureValue,
  required String? signaturesValue,
  required String signaturesJsonValue,
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

    void executeStatement(String statement) => db.execute(statement);

    schemaStatements.forEach(executeStatement);

    db.execute('PRAGMA user_version = $userVersion');

    final columns = <String>[
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
    final values = <Object?>[
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
      columns.addAll(['signature', 'signatures']);
      values.addAll([signatureValue, signaturesValue ?? '[]']);
    }
    if (includeLegacySignaturesJson) {
      columns.add('signatures_json');
      values.add(signaturesJsonValue);
    }
    final placeholders = List.filled(columns.length, '?').join(', ');
    db.execute(
      'INSERT INTO playlists (${columns.join(', ')}) VALUES ($placeholders)',
      values,
    );
  } finally {
    db.dispose();
  }
}
