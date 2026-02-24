import 'package:app/infra/services/forget_local_data_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('forgetIExist executes stop and cleanup sequence in order', () async {
    final events = <String>[];

    final service = ForgetLocalDataService(
      stopWorkersGracefully: () async {
        events.add('stop-workers');
      },
      checkpointDatabase: () async {
        events.add('checkpoint');
      },
      truncateDatabase: () async {
        events.add('truncate-db');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    expect(events, <String>[
      'pause-feed',
      'pause-token-polling',
      'stop-workers',
      'checkpoint',
      'truncate-db',
      'checkpoint',
      'clear-objectbox',
      'truncate-db',
      'checkpoint',
    ]);
  });

  test('forgetIExist runs post-reset callback after cleanup', () async {
    final events = <String>[];

    final service = ForgetLocalDataService(
      stopWorkersGracefully: () async {
        events.add('stop-workers');
      },
      checkpointDatabase: () async {
        events.add('checkpoint');
      },
      truncateDatabase: () async {
        events.add('truncate-db');
      },
      clearObjectBoxData: () async {
        events.add('clear-objectbox');
      },
      pauseFeedWork: () {
        events.add('pause-feed');
      },
      pauseTokenPolling: () {
        events.add('pause-token-polling');
      },
      onResetCompleted: () async {
        events.add('on-reset-completed');
      },
      postDrainSettleDuration: Duration.zero,
    );

    await service.forgetIExist();

    expect(events.last, equals('on-reset-completed'));
  });
}
