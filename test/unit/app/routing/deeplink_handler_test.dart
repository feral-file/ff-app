import 'dart:async';

import 'package:app/app/routing/deeplink_handler.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeDeeplinkLinkSource implements DeeplinkLinkSource {
  _FakeDeeplinkLinkSource({
    Stream<Uri>? linkStream,
    Uri? initialLink,
  })  : _linkStream = linkStream ?? const Stream<Uri>.empty(),
        _initialLink = initialLink;

  final Stream<Uri> _linkStream;
  Uri? _initialLink;

  /// Optional override: when set, called instead of returning [_initialLink].
  Uri? Function()? onGetInitialLink;

  void setInitialLink(Uri? link) => _initialLink = link;

  @override
  Future<Uri?> getInitialLink() async {
    final override = onGetInitialLink;
    return override != null ? override() : _initialLink;
  }

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

    test('deduplicates same link when delivered twice within dedup window',
        () async {
      final handler = DeeplinkHandler(
        linkSource: _FakeDeeplinkLinkSource(),
      );
      addTearDown(handler.dispose);

      final actions = <DeeplinkNavigationAction>[];
      handler.actions.listen(actions.add);

      const link = 'https://link.feralfile.com/playlists/dup-test-id';

      await handler.handleRawLink(link, source: DeeplinkSource.appLink);
      await handler.handleRawLink(link, source: DeeplinkSource.appLink);

      expect(actions.length, 1);
      expect(actions.first.location, '/playlists/dup-test-id');
    });

    group('checkForResumeLink', () {
      // Use zero poll interval so tests don't wait real time.
      DeeplinkHandler _makeHandler(_FakeDeeplinkLinkSource source) =>
          DeeplinkHandler(
            linkSource: source,
            resumeLinkPollInterval: Duration.zero,
            resumeLinkMaxPolls: 5,
          );

      test('emits action when link is immediately available', () async {
        final source = _FakeDeeplinkLinkSource(
          initialLink: Uri.parse(
            'https://link.feralfile.com/device_connect?token=abc',
          ),
        );
        final handler = _makeHandler(source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();

        expect(actions.length, 1);
        expect(actions.first.type, DeeplinkType.deviceConnect);
        expect(actions.first.source, DeeplinkSource.appLink);
      });

      test('emits action when link appears after initial null polls', () async {
        // Simulates scene(_:continue:) arriving after sceneDidBecomeActive.
        final source = _FakeDeeplinkLinkSource();
        final handler = _makeHandler(source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        var pollCount = 0;
        source.onGetInitialLink = () {
          pollCount++;
          // Return the link only on the third poll to simulate async delivery.
          if (pollCount >= 3) {
            return Uri.parse(
              'https://link.feralfile.com/device_connect?token=delayed',
            );
          }
          return null;
        };

        await handler.checkForResumeLink();

        expect(actions.length, 1);
        expect(actions.first.type, DeeplinkType.deviceConnect);
        expect(pollCount, 3);
      });

      test('does nothing when getInitialLink always returns null', () async {
        final handler = _makeHandler(_FakeDeeplinkLinkSource());
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();
        expect(actions, isEmpty);
      });

      test(
          'skips same link on second resume (manual reopen, no new QR scan)',
          () async {
        const link = 'https://link.feralfile.com/device_connect?token=abc';
        final source = _FakeDeeplinkLinkSource(
          initialLink: Uri.parse(link),
        );
        final handler = _makeHandler(source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        // First resume via QR scan.
        await handler.checkForResumeLink();
        expect(actions.length, 1);

        // Second resume (manual, same link in native buffer) must not navigate.
        await handler.checkForResumeLink();
        expect(actions.length, 1);
      });

      test('processes distinct link on second resume (new QR scan)', () async {
        final source = _FakeDeeplinkLinkSource(
          initialLink: Uri.parse(
            'https://link.feralfile.com/device_connect?token=first',
          ),
        );
        final handler = _makeHandler(source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();
        expect(actions.length, 1);

        // User scans a different QR code → new token in native buffer.
        source.setInitialLink(
          Uri.parse('https://link.feralfile.com/device_connect?token=second'),
        );
        await handler.checkForResumeLink();
        expect(actions.length, 2);
      });

      test('cold-start link processed by start() does not re-navigate on resume',
          () async {
        const link = 'https://link.feralfile.com/device_connect?token=same';
        final source = _FakeDeeplinkLinkSource(initialLink: Uri.parse(link));
        final handler = _makeHandler(source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        // Simulates cold start.
        await handler.start();
        expect(actions.length, 1);

        // Simulates resume shortly after cold start with same link in buffer.
        // The dedup window in _processLink suppresses it.
        await handler.checkForResumeLink();
        expect(actions.length, 1);
      });
    });
  });
}
