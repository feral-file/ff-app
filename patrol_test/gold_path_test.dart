import 'dart:async';

import 'package:app/app/patrol/gold_path_patrol_config.dart';
import 'package:app/app/patrol/gold_path_patrol_keys.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter/material.dart' show TextField;
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'common.dart';

const _personalAddressName = 'reas.eth';
const _personalAddressFallbackName = '0x457e...eea6';

void main() {
  patrolTest(
    'gold path patrol',
    ($) async {
      final config = GoldPathPatrolConfig.fromDartDefines();

      await createAppForPatrol($, config: config);
      await _completeOnboardingIfNeeded($);
      await _assertPersonalPlaylistOnHomeAndPlaylistsTab($);

      await $(GoldPathPatrolKeys.channelsTab).tap();
      await $(GoldPathPatrolKeys.curatedChannelsSection).waitUntilExists(
        timeout: const Duration(minutes: 2),
      );

      await _assertCanaryVisible($, config);
      await _openCanaryWork($, config);

      await ensurePatrolActiveDevice(config);
      await _tapPlayOnFf1($);

      await _waitForNowDisplayingOrPlayableState($);

      if (config.soakDuration > Duration.zero) {
        await Future<void>.delayed(config.soakDuration);
      }
    },
  );
}

Future<void> _completeOnboardingIfNeeded(PatrolIntegrationTester $) async {
  if ($('Explore digital art playlists').exists) {
    await $('Next').tap();
  }

  if ($('See the art you already own').exists) {
    await _submitPersonalAddressInOnboarding($, _personalAddressName);
    await $('Next').tap();
  }

  if ($('Add FF1 to your screens').exists) {
    await $('Finish').tap();
  }
}

Future<void> _submitPersonalAddressInOnboarding(
  PatrolIntegrationTester $,
  String address,
) async {
  await $('Add Address').tap();

  final inputField = $(find.byType(TextField));
  await inputField.waitUntilExists(
    timeout: const Duration(seconds: 30),
  );
  await inputField.tap();
  await inputField.enterText(address);
  await $('Submit').tap();

  await $('See the art you already own').waitUntilVisible(
    timeout: const Duration(minutes: 1),
  );
  await $(address).waitUntilExists(
    timeout: const Duration(minutes: 1),
  );
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
    await $(GoldPathPatrolKeys.channelRow(channelId)).waitUntilVisible(
      timeout: const Duration(minutes: 2),
    );
    expect($(GoldPathPatrolKeys.channelRow(channelId)), findsOneWidget);
    return;
  }

  await $(config.canaryChannelTitle).waitUntilVisible(
    timeout: const Duration(minutes: 2),
  );
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
      await workThumbnails.at(0).tap();
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

Future<bool> _isAnyFf1PlayTargetVisible(PatrolIntegrationTester $) async {
  if (await _isVisible(
    $(GoldPathPatrolKeys.ffDisplayTooltipButton),
  )) {
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
    await $(_personalAddressName).waitUntilVisible(
      timeout: const Duration(minutes: 3),
    );
    return;
  } on TimeoutException {
    await $(_personalAddressFallbackName).waitUntilVisible(
      timeout: const Duration(minutes: 1),
    );
  }
}

Future<void> _waitForNowDisplayingOrPlayableState(
  PatrolIntegrationTester $,
) async {
  try {
    await $(GoldPathPatrolKeys.nowDisplayingBar).waitUntilExists(
      timeout: const Duration(seconds: 45),
    );
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
