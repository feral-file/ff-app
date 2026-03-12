import 'dart:async';

import 'package:app/app/patrol/orbit2_patrol_config.dart';
import 'package:app/app/patrol/orbit2_patrol_keys.dart';
import 'package:app/widgets/channels/channel_list_row.dart';
import 'package:app/widgets/work_item_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import 'common.dart';

const _personalAddressName = 'reas.eth';

void main() {
  patrolTest(
    'orbit2 gold path patrol',
    ($) async {
      final config = Orbit2PatrolConfig.fromDartDefines();

      await createAppForPatrol($, config: config);
      await _completeOnboardingIfNeeded($);
      await _assertPersonalPlaylistOnHomeAndPlaylistsTab($);

      await $(Orbit2PatrolKeys.channelsTab).tap();
      await $(Orbit2PatrolKeys.curatedChannelsSection).waitUntilExists(
        timeout: const Duration(minutes: 2),
      );

      await _assertCanaryVisible($, config);
      await _openCanaryWork($, config);

      await $(Orbit2PatrolKeys.ffDisplayButton).waitUntilVisible(
        timeout: const Duration(minutes: 1),
      );
      await _tapPlayOnFf1($);

      await $(Orbit2PatrolKeys.nowDisplayingBar).waitUntilVisible(
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
  await $('Address or ENS / Tezos domain').waitUntilVisible(
    timeout: const Duration(seconds: 30),
  );
  await $('Address or ENS / Tezos domain').enterText(address);
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
  await $(Orbit2PatrolKeys.playlistsTab).tap();
  await $(_personalAddressName).waitUntilVisible(
    timeout: const Duration(minutes: 3),
  );
}

Future<void> _assertCanaryVisible(
  PatrolIntegrationTester $,
  Orbit2PatrolConfig config,
) async {
  if (config.canaryChannelId case final channelId?) {
    await $(Orbit2PatrolKeys.channelRow(channelId)).waitUntilVisible(
      timeout: const Duration(minutes: 2),
    );
    expect($(Orbit2PatrolKeys.channelRow(channelId)), findsOneWidget);
    return;
  }

  await $(config.canaryChannelTitle).waitUntilVisible(
    timeout: const Duration(minutes: 2),
  );
  expect($(config.canaryChannelTitle), findsWidgets);
}

Future<void> _openCanaryWork(
  PatrolIntegrationTester $,
  Orbit2PatrolConfig config,
) async {
  final channelFinder = config.canaryChannelId != null
      ? $(Orbit2PatrolKeys.channelRow(config.canaryChannelId!))
      : $(
          find.ancestor(
            of: find.text(config.canaryChannelTitle, findRichText: true),
            matching: find.byType(ChannelListRow),
          ),
        );

  if (config.canaryChannelId != null && config.canaryWorkId != null) {
    await channelFinder
        .$(
          Orbit2PatrolKeys.channelWork(
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
  if ($('Tap the Play button to send the playlist to your FF1.').exists) {
    await $(Orbit2PatrolKeys.ffDisplayTooltipButton).tap();
    return;
  }

  await $(Orbit2PatrolKeys.ffDisplayButton).tap();
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
