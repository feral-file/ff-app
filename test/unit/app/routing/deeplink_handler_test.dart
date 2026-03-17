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

  void setInitialLink(Uri? link) => _initialLink = link;

  @override
  Future<Uri?> getInitialLink() async => _initialLink;

  @override
  Stream<Uri> get linkStream => _linkStream;

  @override
  Future<void> dispose() async {}
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

    group('checkForResumeLink (fallback path via getInitialLink)', () {
      test('emits action when getInitialLink returns a link', () async {
        final source = _FakeDeeplinkLinkSource(
          initialLink: Uri.parse(
            'https://link.feralfile.com/device_connect?token=abc',
          ),
        );
        final handler = DeeplinkHandler(linkSource: source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();

        expect(actions.length, 1);
        expect(actions.first.type, DeeplinkType.deviceConnect);
        expect(actions.first.source, DeeplinkSource.appLink);
      });

      test('does nothing when getInitialLink returns null', () async {
        final handler = DeeplinkHandler(
          linkSource: _FakeDeeplinkLinkSource(),
        );
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();
        expect(actions, isEmpty);
      });

      test('deduplicates link already in buffer from cold-start start()',
          () async {
        const link = 'https://link.feralfile.com/device_connect?token=same';
        final source = _FakeDeeplinkLinkSource(initialLink: Uri.parse(link));
        final handler = DeeplinkHandler(linkSource: source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        // Simulates cold start: start() reads and processes the link.
        await handler.start();
        expect(actions.length, 1);

        // Simulates resume shortly after: dedup window suppresses replay.
        await handler.checkForResumeLink();
        expect(actions.length, 1);
      });

      test('processes a distinct new link on next call', () async {
        final source = _FakeDeeplinkLinkSource(
          initialLink: Uri.parse(
            'https://link.feralfile.com/device_connect?token=first',
          ),
        );
        final handler = DeeplinkHandler(linkSource: source);
        addTearDown(handler.dispose);

        final actions = <DeeplinkNavigationAction>[];
        handler.actions.listen(actions.add);

        await handler.checkForResumeLink();
        expect(actions.length, 1);

        // New QR code scanned → different token in native buffer.
        source.setInitialLink(
          Uri.parse('https://link.feralfile.com/device_connect?token=second'),
        );
        await handler.checkForResumeLink();
        expect(actions.length, 2);
      });
    });

    group('native channel delivery via linkStream (primary path)', () {
      test('emits action when linkStream fires (simulates SceneDelegate path)',
          () async {
        final streamController = StreamController<Uri>();
        final source = _FakeDeeplinkLinkSource(
          linkStream: streamController.stream,
        );
        final handler = DeeplinkHandler(linkSource: source);
        addTearDown(() async {
          await handler.dispose();
          await streamController.close();
        });

        await handler.start();

        // Collect the next action before emitting so we don't miss it.
        final nextAction = handler.actions.first;

        // Simulates SceneDelegate forwarding a Universal Link via MethodChannel
        // → AppLinksDeeplinkSource emits it to the combined linkStream.
        streamController.add(
          Uri.parse('https://link.feralfile.com/device_connect?token=native'),
        );

        final action = await nextAction;
        expect(action.type, DeeplinkType.deviceConnect);
        expect(action.source, DeeplinkSource.appLink);
      });

      test('deduplicates link if both linkStream and checkForResumeLink fire',
          () async {
        // Simulates the real iOS race:
        // 1. sceneDidBecomeActive → resumed → checkForResumeLink: getInitialLink = null
        // 2. scene(_:continue:) → SceneDelegate → MethodChannel → linkStream fires
        // 3. app_links also stores link in buffer → getInitialLink now returns it
        // 4. Dedup window must prevent double navigation.
        const link = 'https://link.feralfile.com/device_connect?token=both';
        final streamController = StreamController<Uri>();
        // getInitialLink returns null during start() — buffer not populated yet.
        final source = _FakeDeeplinkLinkSource(
          linkStream: streamController.stream,
        );
        final handler = DeeplinkHandler(linkSource: source);
        addTearDown(() async {
          await handler.dispose();
          await streamController.close();
        });

        await handler.start();

        final nextAction = handler.actions.first;

        // Native channel fires (primary path) — link arrives via linkStream.
        streamController.add(Uri.parse(link));
        await nextAction;

        // app_links now stores the link in its initial buffer too.
        source.setInitialLink(Uri.parse(link));

        // checkForResumeLink runs as fallback — dedup window suppresses it.
        final extraActions = <DeeplinkNavigationAction>[];
        handler.actions.listen(extraActions.add);
        await handler.checkForResumeLink();
        expect(extraActions, isEmpty);
      });
    });
  });
}
