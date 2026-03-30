import 'package:app/app/bootstrap/database_reset_recovery_service.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAppStateService implements AppStateServiceBase {
  final List<String> callSequence = <String>[];
  final Set<String> tracked = <String>{};
  final Map<String, AddressIndexingProcessStatus> statuses =
      <String, AddressIndexingProcessStatus>{};

  @override
  Future<void> clearAddressCheckpoint(String address) async {
    callSequence.add('clearCheckpoint:$address');
  }

  @override
  Future<void> addTrackedAddress(String address, {String alias = ''}) async {
    callSequence.add('addTracked:$address:$alias');
    tracked.add(address);
  }

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    callSequence.add('setStatus:$address:${status.state}');
    if (!tracked.contains(address)) {
      throw StateError('setAddressIndexingStatus before addTrackedAddress');
    }
    statuses[address] = status;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('tracks address before persisting indexing status', () async {
    final appState = _RecordingAppStateService();
    final service = DatabaseResetRecoveryService(appStateService: appState);

    await service.recover(
      normalizedAddresses: const ['0xabc'],
      aliasForAddress: (address) => shortAddressAlias(address),
    );

    expect(
      appState.callSequence,
      equals(const <String>[
        'clearCheckpoint:0xabc',
        'addTracked:0xabc:0xabc',
        'setStatus:0xabc:AddressIndexingProcessState.indexingTriggered',
      ]),
    );
    expect(
      appState.statuses['0xabc']?.state,
      AddressIndexingProcessState.indexingTriggered,
    );
    expect(
      appState.statuses['0xabc']?.workflowId,
      isNull,
      reason: 'recovery uses indexingTriggeredPending (workflowId unknown yet)',
    );
  });
}
