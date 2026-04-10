import 'package:app/nft_rendering/nft_rendering_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LifecycleAwarePlaybackMixin', () {
    late _FakeRenderer renderer;

    setUp(() {
      renderer = _FakeRenderer();
    });

    test('pauses when app moves to background and isPlaying is true', () {
      renderer.simulatePlaying(true);
      renderer.simulateLifecycle(AppLifecycleState.paused);

      expect(renderer.pauseCount, 1);
      expect(renderer.isBackgroundPaused, isTrue);
    });

    test('does not pause when app moves to background and isPlaying is false', () {
      renderer.simulatePlaying(false);
      renderer.simulateLifecycle(AppLifecycleState.paused);

      expect(renderer.pauseCount, 0);
      expect(renderer.isBackgroundPaused, isFalse);
    });

    test('resumes on foreground if it paused for background', () {
      renderer.simulatePlaying(true);
      renderer.simulateLifecycle(AppLifecycleState.paused);
      renderer.simulateLifecycle(AppLifecycleState.resumed);

      expect(renderer.resumeCount, 1);
      expect(renderer.isBackgroundPaused, isFalse);
    });

    test('does not resume on foreground if it did not pause for background', () {
      renderer.simulatePlaying(false);
      renderer.simulateLifecycle(AppLifecycleState.paused);
      renderer.simulateLifecycle(AppLifecycleState.resumed);

      expect(renderer.resumeCount, 0);
    });

    test('manually paused content stays paused after background/foreground', () {
      // User pauses manually → isPlaying becomes false.
      renderer.simulatePlaying(false);

      renderer.simulateLifecycle(AppLifecycleState.paused);
      renderer.simulateLifecycle(AppLifecycleState.resumed);

      // pause() was never called by the mixin; resume() was never called.
      expect(renderer.pauseCount, 0);
      expect(renderer.resumeCount, 0);
    });

    test('inactive state does not trigger pause', () {
      renderer.simulatePlaying(true);
      renderer.simulateLifecycle(AppLifecycleState.inactive);

      expect(renderer.pauseCount, 0);
      expect(renderer.isBackgroundPaused, isFalse);
    });

    test('isBackgroundPaused is false initially', () {
      expect(renderer.isBackgroundPaused, isFalse);
    });

    test('isBackgroundPaused is cleared after resume', () {
      renderer.simulatePlaying(true);
      renderer.simulateLifecycle(AppLifecycleState.paused);
      expect(renderer.isBackgroundPaused, isTrue);

      renderer.simulateLifecycle(AppLifecycleState.resumed);
      expect(renderer.isBackgroundPaused, isFalse);
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal stub that exercises the mixin without a real widget tree.
// ---------------------------------------------------------------------------

class _FakeNFTWidget extends NFTRenderingWidget {
  const _FakeNFTWidget();

  @override
  State<_FakeNFTWidget> createState() => _FakeRenderer();
}

class _FakeRenderer extends NFTRenderingWidgetState<_FakeNFTWidget>
    with WidgetsBindingObserver, LifecycleAwarePlaybackMixin {
  int pauseCount = 0;
  int resumeCount = 0;
  bool _playing = false;

  @override
  bool get isPlaying => _playing;

  void simulatePlaying(bool value) => _playing = value;

  void simulateLifecycle(AppLifecycleState state) =>
      didChangeAppLifecycleState(state);

  @override
  void pause() => pauseCount++;

  @override
  void resume() => resumeCount++;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
