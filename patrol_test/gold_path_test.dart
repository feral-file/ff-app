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

      await $(GoldPathPatrolKeys.ffDisplayButton).waitUntilVisible(
        timeout: const Duration(minutes: 1),
      );
      await _tapPlayOnFf1($);

      await $(GoldPathPatrolKeys.nowDisplayingBar).waitUntilVisible(
        timeout: const Duration(minutes: 2),
      );

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
  await $(address).waitUntilVisible(
    timeout: const Duration(minutes: 1),
  );
}

Future<void> _assertPersonalPlaylistOnHomeAndPlaylistsTab(
  PatrolIntegrationTester $,
) async {
  await $(_personalAddressName).waitUntilVisible(
    timeout: const Duration(minutes: 3),
  );
  await $(GoldPathPatrolKeys.playlistsTab).tap();
  await $(_personalAddressName).waitUntilVisible(
    timeout: const Duration(minutes: 3),
  );
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
    await channelFinder
        .$(
          GoldPathPatrolKeys.channelWork(
            channelId: config.canaryChannelId!,
            workId: config.canaryWorkId!,
          ),
        )
        .waitUntilVisible(timeout: const Duration(minutes: 2))
        .tap();
    return;
  }

  final workThumbnails = channelFinder.$(WorkItemThumbnail);
  await _waitForThumbnailInChannelRow(
    $,
    thumbnailsFinder: workThumbnails,
    timeout: const Duration(minutes: 2),
  );
  await workThumbnails.at(0).tap();
}

Future<void> _tapPlayOnFf1(PatrolIntegrationTester $) async {
  const tooltipCopy = 'Tap the Play button to send the playlist to your FF1.';
  final deadline = DateTime.now().add(const Duration(minutes: 1));

  while (DateTime.now().isBefore(deadline)) {
    await $.pump(const Duration(milliseconds: 250));

    if ($(GoldPathPatrolKeys.ffDisplayTooltipButton).exists ||
        $(tooltipCopy).exists) {
      await $(GoldPathPatrolKeys.ffDisplayTooltipButton).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(GoldPathPatrolKeys.ffDisplayTooltipButton).tap();
      return;
    }

    if ($(GoldPathPatrolKeys.ffDisplayButton).exists &&
        !$(tooltipCopy).exists) {
      await $(GoldPathPatrolKeys.ffDisplayButton).waitUntilVisible(
        timeout: const Duration(seconds: 20),
      );
      await $(GoldPathPatrolKeys.ffDisplayButton).tap();
      return;
    }
  }

  throw TimeoutException(
    'Timed out waiting for a visible FF1 play target (tooltip or default).',
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
