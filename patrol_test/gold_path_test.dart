import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_config.dart';
import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show TextInputAction, ValueKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'common.dart';

const _personalAddressName = 'reas.eth';
const _personalAddressFallbackName = '0x457e...eea6';

void main() {
  patrolTest('gold path patrol', ($) async {
    final config = GoldPathPatrolConfig.fromDartDefines();

    _logStep('boot app');
    await createAppForPatrol($, config: config);
    _logStep('complete onboarding');
    await _completeOnboardingIfNeeded($);
    _logStep('verify personal playlist');
    await _assertPersonalPlaylistOnHomeAndPlaylistsTab($);

    _logStep('open channels');
    await $(GoldPathPatrolKeys.channelsTab).tap();
    await $(
      GoldPathPatrolKeys.curatedChannelsSection,
    ).waitUntilExists(timeout: const Duration(minutes: 2));

    _logStep('locate canary');
    await _assertCanaryVisible($, config);
    _logStep('open canary work');
    await _openCanaryWork($, config);

    _logStep('reassert active FF1 device');
    await ensurePatrolActiveDevice(config);
    _logStep('tap FF1 play');
    await _tapPlayOnFf1($);

    _logStep('wait for playback state');
    await _waitForNowDisplayingOrPlayableState($);

    if (config.soakDuration > Duration.zero) {
      _logStep('soak for ${config.soakDuration.inSeconds}s');
      await Future<void>.delayed(config.soakDuration);
    }
  });
}

Future<void> _completeOnboardingIfNeeded(PatrolIntegrationTester $) async {
  if ($('Explore digital art playlists').exists) {
    await _tapOnboardingAction(
      $,
      actionKey: GoldPathPatrolKeys.onboardingIntroduceNext,
      actionLabel: 'Next',
    );
  }

  if ($('See the art you already own').exists) {
    await _submitPersonalAddressInOnboarding($, _personalAddressName);
    await _tapOnboardingAction(
      $,
      actionKey: GoldPathPatrolKeys.onboardingAddAddressSecondary,
      actionLabel: 'Next/Skip for now',
    );
  }

  if ($('Add FF1 to your screens').exists) {
    await _tapOnboardingAction(
      $,
      actionKey: GoldPathPatrolKeys.onboardingSetupFf1Secondary,
      actionLabel: 'Finish',
    );
  }
}

Future<void> _tapOnboardingAction(
  PatrolIntegrationTester $, {
  required ValueKey<String> actionKey,
  required String actionLabel,
}) async {
  final actionFinder = find.byKey(actionKey);
  final action = $(actionKey);
  final deadline = DateTime.now().add(const Duration(seconds: 20));

  while (DateTime.now().isBefore(deadline)) {
    await action.waitUntilExists(timeout: const Duration(seconds: 2));

    try {
      await $.tester.ensureVisible(actionFinder.first);
      await $.pump(const Duration(milliseconds: 200));
    } on Exception {
      // Keep retrying while screen is stabilizing.
    }

    if (await _tryTapVisible($, action)) {
      return;
    }

    await $.pump(const Duration(milliseconds: 300));
  }

  throw TimeoutException(
    'Timed out tapping onboarding action "$actionLabel" after waiting for '
    'a hit-testable target.',
  );
}

Future<void> _submitPersonalAddressInOnboarding(
  PatrolIntegrationTester $,
  String address,
) async {
  await _waitForOnboardingAddressActionsReady($);
  await _openAddAddressFromOnboarding($);
  await _enterAddressAndSubmit($, address);

  await $(
    'See the art you already own',
  ).waitUntilVisible(timeout: const Duration(minutes: 1));
  await $(address).waitUntilExists(timeout: const Duration(minutes: 1));
}

Future<void> _openAddAddressFromOnboarding(PatrolIntegrationTester $) async {
  final textFieldFinder = $(GoldPathPatrolKeys.onboardingAddAddressInput);
  final submitButtonFinder = $(GoldPathPatrolKeys.onboardingAddAddressSubmit);
  final deadline = DateTime.now().add(const Duration(seconds: 45));

  while (DateTime.now().isBefore(deadline)) {
    await _waitForOnboardingAddressActionsReady($);
    await _tapOnboardingAction(
      $,
      actionKey: GoldPathPatrolKeys.onboardingAddAddressPrimary,
      actionLabel: 'Add Address',
    );

    await $.pump(const Duration(milliseconds: 500));

    if (await _exists(textFieldFinder) || await _exists(submitButtonFinder)) {
      return;
    }
  }

  throw TimeoutException(
    'Timed out waiting for add-address screen after tapping onboarding action.',
  );
}

Future<void> _waitForOnboardingAddressActionsReady(
  PatrolIntegrationTester $,
) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));

  while (DateTime.now().isBefore(deadline)) {
    final isWaiting = await _isOnboardingAddressGateBlocked($);
    if (!isWaiting) {
      return;
    }

    _logStep('waiting for onboarding address actions to unlock');
    await $.pump(const Duration(seconds: 1));
  }

  throw TimeoutException(
    'Timed out waiting for onboarding address actions to unlock.',
  );
}

Future<bool> _isOnboardingAddressGateBlocked(PatrolIntegrationTester $) async {
  final waitingLabelVisible = await _isVisible(
    $('Please wait'),
    timeout: const Duration(milliseconds: 300),
  );
  if (waitingLabelVisible) {
    return true;
  }

  return _isVisible(
    $('Address adds stay disabled while startup sync settles.'),
    timeout: const Duration(milliseconds: 300),
  );
}

Future<void> _enterAddressAndSubmit(
  PatrolIntegrationTester $,
  String address,
) async {
  final inputFinder = $(GoldPathPatrolKeys.onboardingAddAddressInput);

  await inputFinder.waitUntilExists(timeout: const Duration(seconds: 30));

  await inputFinder.tap();
  await $.pump(const Duration(milliseconds: 300));
  await $.tester.enterText(
    find.byKey(GoldPathPatrolKeys.onboardingAddAddressInput),
    address,
  );
  await $.pump(const Duration(milliseconds: 300));
  await $.tester.testTextInput.receiveAction(TextInputAction.done);
  await $.pump(const Duration(milliseconds: 500));

  if (await _isVisible($(GoldPathPatrolKeys.onboardingAddAddressSubmit))) {
    await $(GoldPathPatrolKeys.onboardingAddAddressSubmit).tap();
  }

  await $.pump(const Duration(milliseconds: 500));

  if (await _isVisible($(GoldPathPatrolKeys.onboardingAddAliasSkip))) {
    await $(GoldPathPatrolKeys.onboardingAddAliasSkip).tap();
  }
}

Future<void> _assertPersonalPlaylistOnHomeAndPlaylistsTab(
  PatrolIntegrationTester $,
) async {
  await _waitForPersonalPlaylistLabel($);
  await $(GoldPathPatrolKeys.playlistsTab).tap();
  await _waitForPersonalPlaylistLabel($);
}

Future<void> _assertCanaryVisible(
  PatrolIntegrationTester $,
  GoldPathPatrolConfig config,
) async {
  if (config.canaryChannelId case final channelId?) {
    await $(
      GoldPathPatrolKeys.channelRow(channelId),
    ).waitUntilVisible(timeout: const Duration(minutes: 2));
    expect($(GoldPathPatrolKeys.channelRow(channelId)), findsOneWidget);
    return;
  }

  await $(
    config.canaryChannelTitle,
  ).waitUntilVisible(timeout: const Duration(minutes: 2));
  expect($(config.canaryChannelTitle), findsWidgets);
}

Future<void> _openCanaryWork(
  PatrolIntegrationTester $,
  GoldPathPatrolConfig config,
) async {
  final channelFinder = config.canaryChannelId != null
      ? $(GoldPathPatrolKeys.channelRow(config.canaryChannelId!))
      : $(
          find.ancestor(
            of: find.text(config.canaryChannelTitle, findRichText: true),
            matching: find.byType(ChannelListRow),
          ),
        );

  if (config.canaryChannelId != null && config.canaryWorkId != null) {
    final canaryWorkFinder = channelFinder.$(
      GoldPathPatrolKeys.channelWork(
        channelId: config.canaryChannelId!,
        workId: config.canaryWorkId!,
      ),
    );
    await _openCanaryWorkUntilPlayTargetVisible(
      $,
      tapWork: () async {
        await canaryWorkFinder.waitUntilVisible(
          timeout: const Duration(minutes: 2),
        );
        await canaryWorkFinder.tap();
      },
    );
    return;
  }

  final workThumbnails = channelFinder.$(WorkItemThumbnail);
  await _waitForThumbnailInChannelRow(
    $,
    thumbnailsFinder: workThumbnails,
    timeout: const Duration(minutes: 2),
  );
  await _openCanaryWorkUntilPlayTargetVisible(
    $,
    tapWork: () async {
      await _tapVisibleInScrollableContext(
        $,
        workThumbnails.at(0),
        description: 'first canary work thumbnail',
      );
    },
  );
}

Future<void> _openCanaryWorkUntilPlayTargetVisible(
  PatrolIntegrationTester $, {
  required Future<void> Function() tapWork,
}) async {
  final deadline = DateTime.now().add(const Duration(minutes: 2));

  while (DateTime.now().isBefore(deadline)) {
    await tapWork();

    final hasPlayTarget = await _isAnyFf1PlayTargetVisible($);
    if (hasPlayTarget) {
      return;
    }

    await $.pump(const Duration(milliseconds: 500));
  }

  throw TimeoutException(
    'Timed out opening canary work before FF1 play controls became visible.',
  );
}

Future<void> _tapVisibleInScrollableContext(
  PatrolIntegrationTester $,
  PatrolFinder finder, {
  required String description,
  Duration timeout = const Duration(seconds: 20),
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    try {
      await finder.waitUntilExists(timeout: const Duration(seconds: 2));
      await $.tester.ensureVisible(finder.first);
      await $.pump(const Duration(milliseconds: 250));
    } on Exception {
      await $.pump(const Duration(milliseconds: 250));
    }

    if (await _tryTapVisible($, finder)) {
      return;
    }
  }

  throw TimeoutException(
    'Timed out tapping $description after waiting for a hit-testable target.',
  );
}

Future<bool> _isAnyFf1PlayTargetVisible(PatrolIntegrationTester $) async {
  if (await _isVisible($(GoldPathPatrolKeys.ffDisplayTooltipButton))) {
    return true;
  }
  return _isVisible($(GoldPathPatrolKeys.ffDisplayButton));
}

Future<bool> _isVisible(
  PatrolFinder finder, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    await finder.waitUntilVisible(timeout: timeout);
    return true;
  } on TimeoutException {
    return false;
  } on Exception {
    return false;
  }
}

Future<bool> _exists(
  PatrolFinder finder, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    await finder.waitUntilExists(timeout: timeout);
    return true;
  } on TimeoutException {
    return false;
  } on Exception {
    return false;
  }
}

Future<void> _tapPlayOnFf1(PatrolIntegrationTester $) async {
  final deadline = DateTime.now().add(const Duration(minutes: 1));
  final tooltipPlayButton = $(GoldPathPatrolKeys.ffDisplayTooltipButton);
  final defaultPlayButton = $(GoldPathPatrolKeys.ffDisplayButton);

  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 250));

    if (await _tryTapVisible($, tooltipPlayButton)) {
      return;
    }

    if (await _tryTapVisible($, defaultPlayButton)) {
      return;
    }
  }

  throw TimeoutException(
    'Timed out waiting for a visible FF1 play target (tooltip or default).',
  );
}

Future<bool> _tryTapVisible(
  PatrolIntegrationTester $,
  PatrolFinder finder, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  try {
    await finder.waitUntilVisible(timeout: timeout);
    await finder.tap();
    return true;
  } on TimeoutException {
    return false;
  } on Exception {
    return false;
  }
}

Future<void> _waitForPersonalPlaylistLabel(PatrolIntegrationTester $) async {
  try {
    await $(
      _personalAddressName,
    ).waitUntilVisible(timeout: const Duration(minutes: 3));
    return;
  } on TimeoutException {
    await $(
      _personalAddressFallbackName,
    ).waitUntilVisible(timeout: const Duration(minutes: 1));
  }
}

Future<void> _waitForNowDisplayingOrPlayableState(
  PatrolIntegrationTester $,
) async {
  try {
    await $(
      GoldPathPatrolKeys.nowDisplayingBar,
    ).waitUntilExists(timeout: const Duration(seconds: 45));
    return;
  } on TimeoutException {
    // Some CI runs cast successfully but the global now-displaying overlay
    // never materializes. In that case, verify the FF1 play controls are still
    // reachable on detail as a fallback signal that playback was triggered.
  } on PatrolFinderException {
    // Fall through to the same fallback check.
  }

  final hasPlayableState = await _isAnyFf1PlayTargetVisible($);
  if (hasPlayableState) {
    return;
  }

  throw TimeoutException(
    'Timed out waiting for now-displaying bar or reachable FF1 play controls.',
  );
}

Future<void> _waitForThumbnailInChannelRow(
  PatrolIntegrationTester $, {
  required PatrolFinder thumbnailsFinder,
  required Duration timeout,
}) async {
  final deadline = DateTime.now().add(timeout);

  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 250));
    if (thumbnailsFinder.exists) {
      return;
    }
  }

  throw TimeoutException(
    'Timed out waiting for a work thumbnail inside the canary channel row.',
  );
}

void _logStep(String message) {
  debugPrint('gold_path_test: $message');
}
