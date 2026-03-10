import 'dart:async';

import 'package:app/app/routing/deeplink_handler.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDeeplinkLinkSource implements DeeplinkLinkSource {
  _FakeDeeplinkLinkSource({
    Stream<Uri>? linkStream,
  }) : _linkStream = linkStream ?? const Stream<Uri>.empty();

  final Stream<Uri> _linkStream;

  @override
  Future<Uri?> getInitialLink() async => null;

  @override
  Stream<Uri> get linkStream => _linkStream;
}

void main() {
  group('classifyDeeplink', () {
    test('classifies device connect deeplink', () {
      expect(
        classifyDeeplink('feralfile://device_connect?foo=bar'),
        DeeplinkType.deviceConnect,
      );
    });

    test('classifies playlist deeplink', () {
      expect(
        classifyDeeplink('feralfile://playlists/playlist-001'),
        DeeplinkType.appRoute,
      );
    });

    test('classifies channel deeplink', () {
      expect(
        classifyDeeplink('feralfile://channels/channel-001'),
        DeeplinkType.appRoute,
      );
    });

    test('classifies work deeplink', () {
      expect(
        classifyDeeplink('feralfile://works/work-001'),
        DeeplinkType.appRoute,
      );
    });

    test('returns unknown for unsupported deeplink', () {
      expect(
        classifyDeeplink('https://example.com/path'),
        DeeplinkType.unknown,
      );
    });
  });

  group('resolveAppLocationFromDeeplink', () {
    test('resolves location from feralfile scheme path', () {
      expect(
        resolveAppLocationFromDeeplink('feralfile://playlists/playlist-123'),
        '/playlists/playlist-123',
      );
    });

    test('resolves location from link host path', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/playlists/playlist-456',
        ),
        '/playlists/playlist-456',
      );
    });

    test('resolves playlists index location', () {
      expect(
        resolveAppLocationFromDeeplink('https://link.feralfile.com/playlists'),
        '/playlists',
      );
    });

    test('returns null for unsupported host', () {
      expect(
        resolveAppLocationFromDeeplink('https://example.com/playlist/abc'),
        isNull,
      );
    });

    test('returns null for non-canonical playlist route', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/playlist/playlist-123',
        ),
        isNull,
      );
    });

    test('resolves channel location from feralfile scheme', () {
      expect(
        resolveAppLocationFromDeeplink(
          'feralfile://channels/abc-123',
        ),
        '/channels/abc-123',
      );
    });

    test('resolves channel location from link host', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/channels/channel-456',
        ),
        '/channels/channel-456',
      );
    });

    test('resolves channels index location', () {
      expect(
        resolveAppLocationFromDeeplink('https://link.feralfile.com/channels'),
        '/channels',
      );
    });

    test('resolves channels all location', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/channels/all',
        ),
        '/channels/all',
      );
    });

    test('resolves work location from feralfile scheme', () {
      expect(
        resolveAppLocationFromDeeplink('feralfile://works/work-789'),
        '/works/work-789',
      );
    });

    test('resolves work location from link host', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/works/xyz-456',
        ),
        '/works/xyz-456',
      );
    });

    test('resolves items alias to works location', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/items/item-abc',
        ),
        '/works/item-abc',
      );
    });

    test('returns null for channel with invalid path segment', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/channels//',
        ),
        isNull,
      );
    });

    test('returns null for non-canonical channel route', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/channel/channel-123',
        ),
        isNull,
      );
    });
  });

  group('DeeplinkHandler', () {
    test('emits app route action with resolved location', () async {
      final handler = DeeplinkHandler(
        linkSource: _FakeDeeplinkLinkSource(),
      );
      addTearDown(handler.dispose);

      final nextActionFuture = handler.actions.first;
      await handler.handleRawLink(
        'feralfile://playlists/playlist-action-id',
        source: DeeplinkSource.scan,
      );

      final action = await nextActionFuture;
      expect(action.type, DeeplinkType.appRoute);
      expect(action.location, '/playlists/playlist-action-id');
      expect(action.source, DeeplinkSource.scan);
    });

    test('emits app route action for channel deeplink', () async {
      final handler = DeeplinkHandler(
        linkSource: _FakeDeeplinkLinkSource(),
      );
      addTearDown(handler.dispose);

      final nextActionFuture = handler.actions.first;
      await handler.handleRawLink(
        'https://link.feralfile.com/channels/channel-123',
        source: DeeplinkSource.appLink,
      );

      final action = await nextActionFuture;
      expect(action.type, DeeplinkType.appRoute);
      expect(action.location, '/channels/channel-123');
      expect(action.source, DeeplinkSource.appLink);
    });

    test('emits app route action for work deeplink', () async {
      final handler = DeeplinkHandler(
        linkSource: _FakeDeeplinkLinkSource(),
      );
      addTearDown(handler.dispose);

      final nextActionFuture = handler.actions.first;
      await handler.handleRawLink(
        'https://link.feralfile.com/items/work-456',
        source: DeeplinkSource.appLink,
      );

      final action = await nextActionFuture;
      expect(action.type, DeeplinkType.appRoute);
      expect(action.location, '/works/work-456');
      expect(action.source, DeeplinkSource.appLink);
    });
  });
}
