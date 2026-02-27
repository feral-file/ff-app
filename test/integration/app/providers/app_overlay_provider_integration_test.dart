import 'package:app/app/providers/app_overlay_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('overlay IDs are unique across multiple toast insertions', () {
    final container = ProviderContainer.test();
    addTearDown(container.dispose);

    final notifier = container.read(appOverlayProvider.notifier);
    final firstId = notifier.showToast(message: 'One');
    final secondId = notifier.showToast(message: 'Two');

    expect(firstId, isNot(secondId));
    expect(container.read(appOverlayProvider), hasLength(2));
  });
}
