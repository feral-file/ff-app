import 'package:app/app/bootstrap/database_reset_reindex_service.dart';
import 'package:app/infra/config/app_state_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingAppStateService implements AppStateServiceBase {
  _RecordingAppStateService(this.trackedAddresses);

  final List<String> trackedAddresses;
  final List<String> callSequence = <String>[];
  final List<String> statusResets = <String>[];

  @override
  Future<List<String>> getTrackedPersonalAddresses() async => trackedAddresses;

  @override
  Future<void> clearAddressCheckpoint(String address) async {
    callSequence.add('clearCheckpoint:$address');
  }

  @override
  Future<void> setPersonalTokensListFetchOffset({
    required String address,
    required int? nextFetchOffset,
  }) async {
    callSequence.add('clearCursor:$address:$nextFetchOffset');
  }

  @override
  Future<void> setAddressIndexingStatus({
    required String address,
    required AddressIndexingProcessStatus status,
  }) async {
    callSequence.add('setStatus:$address:${status.state}');
    statusResets.add(address);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test(
    'resets tracked addresses when database reset marker is present',
    () async {
      final appState = _RecordingAppStateService(const ['0xabc', '0xdef']);
      final service = DatabaseResetReindexService(appStateService: appState);

      final didReset = await service.resetTrackedAddressesIfNeeded(
        consumeResetMarker: () async => true,
      );

      expect(didReset, isTrue);
      expect(
        appState.callSequence,
        equals(const <String>[
          'clearCheckpoint:0xabc',
          'clearCursor:0xabc:null',
          'setStatus:0xabc:AddressIndexingProcessState.idle',
          'clearCheckpoint:0xdef',
          'clearCursor:0xdef:null',
          'setStatus:0xdef:AddressIndexingProcessState.idle',
        ]),
      );
    },
  );

  test('does nothing when database reset marker is absent', () async {
    final appState = _RecordingAppStateService(const ['0xabc']);
    final service = DatabaseResetReindexService(appStateService: appState);

    final didReset = await service.resetTrackedAddressesIfNeeded(
      consumeResetMarker: () async => false,
    );

    expect(didReset, isFalse);
    expect(appState.callSequence, isEmpty);
  });
}
