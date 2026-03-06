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
        classifyDeeplink('feralfile://playlist/playlist-001'),
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
        resolveAppLocationFromDeeplink('feralfile://playlist/playlist-123'),
        '/playlist/playlist-123',
      );
    });

    test('resolves location from link host path', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/playlist/playlist-456',
        ),
        '/playlist/playlist-456',
      );
    });

    test('keeps deeplink query string', () {
      expect(
        resolveAppLocationFromDeeplink(
          'https://link.feralfile.com/playlist?id=playlist-789',
        ),
        '/playlist?id=playlist-789',
      );
    });

    test('returns null for unsupported host', () {
      expect(
        resolveAppLocationFromDeeplink('https://example.com/playlist/abc'),
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
        'feralfile://playlist/playlist-action-id',
        source: DeeplinkSource.scan,
      );

      final action = await nextActionFuture;
      expect(action.type, DeeplinkType.appRoute);
      expect(action.location, '/playlist/playlist-action-id');
      expect(action.source, DeeplinkSource.scan);
    });
  });
}
