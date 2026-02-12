import 'dart:async';

import 'package:app/infra/config/app_state_service.dart';
import 'package:app/infra/services/indexer_service.dart';
import 'package:app/infra/services/indexer_sync_service.dart';
import 'package:logging/logging.dart';

/// Orchestrates per-address indexing + sync as a stoppable/pauseable process.
class AddressIndexingProcessService {
  AddressIndexingProcessService({
    required IndexerService indexerService,
    required IndexerSyncService indexerSyncService,
    required AppStateService appStateService,
    Logger? logger,
  }) : _indexerService = indexerService,
       _indexerSyncService = indexerSyncService,
       _appStateService = appStateService,
       _log = logger ?? Logger('AddressIndexingProcessService');

  final IndexerService _indexerService;
  final IndexerSyncService _indexerSyncService;
  final AppStateService _appStateService;
  final Logger _log;

  static const Duration _pollDelay = Duration(seconds: 5);
  static const Duration _indexingTimeout = Duration(minutes: 15);
  static const int _batchSize = 50;

  final Map<String, _AddressProcess> _processes = <String, _AddressProcess>{};

  Future<void> start(String address) async {
    final normalizedAddress = _normalizeAddress(address);
    if (normalizedAddress.isEmpty) {
      throw ArgumentError('address must not be empty');
    }

    final process = _processes.putIfAbsent(
      normalizedAddress,
      () => _AddressProcess(address: normalizedAddress),
    );
    process.cancelled = false;
    process.paused = false;

    if (process.running != null) {
      _log.info('Address process already running: $normalizedAddress');
      return;
    }

    process.running = _runProcess(process);
    unawaited(
      process.running!.whenComplete(() {
        process.running = null;
        if (process.cancelled) {
          _processes.remove(normalizedAddress);
        }
      }),
    );
  }

  Future<void> stop(String address) async {
    final normalizedAddress = _normalizeAddress(address);
    final process = _processes[normalizedAddress];
    if (process == null) {
      await _setState(
        normalizedAddress,
        AddressIndexingProcessState.stopped,
      );
      return;
    }

    process.cancelled = true;
    process.paused = false;
    await _setState(normalizedAddress, AddressIndexingProcessState.stopped);
  }

  Future<void> pause(String address) async {
    final normalizedAddress = _normalizeAddress(address);
    final process = _processes[normalizedAddress];
    if (process == null) {
      await _setState(
        normalizedAddress,
        AddressIndexingProcessState.paused,
      );
      return;
    }
    process.paused = true;
    await _setState(normalizedAddress, AddressIndexingProcessState.paused);
  }

  Future<void> resume(String address) async {
    final normalizedAddress = _normalizeAddress(address);
    final process = _processes[normalizedAddress];
    if (process == null) {
      await start(normalizedAddress);
      return;
    }
    process.paused = false;
    process.cancelled = false;
    if (process.running == null) {
      process.running = _runProcess(process);
      unawaited(
        process.running!.whenComplete(() {
          process.running = null;
          if (process.cancelled) {
            _processes.remove(normalizedAddress);
          }
        }),
      );
    }
  }

  Future<void> _runProcess(_AddressProcess process) async {
    try {
      if (process.workflowId == null || process.workflowId!.isEmpty) {
        if (process.cancelled) return;
        if (process.paused) return;

        await _setState(
          process.address,
          AddressIndexingProcessState.indexingTriggered,
          clearError: true,
        );
        final workflowId = await _triggerIndexing(process.address);
        process.workflowId = workflowId;
      }

      if (!process.indexingDone) {
        await _setState(
          process.address,
          AddressIndexingProcessState.waitingForIndexStatus,
          clearError: true,
        );
        final ready = await _waitForWorkflow(process);
        if (!ready) {
          if (process.cancelled || process.paused) return;
          throw Exception('Indexing workflow did not complete successfully');
        }
        process.indexingDone = true;
      }

      await _setState(
        process.address,
        AddressIndexingProcessState.syncingTokens,
        clearError: true,
      );

      while (!process.cancelled && !process.paused) {
        final page = await _indexerSyncService.syncTokensPageForAddress(
          address: process.address,
          limit: _batchSize,
          offset: process.offset,
        );
        final loaded = page.fetchedCount;

        if (loaded <= 0) {
          break;
        }

        final nextOffset = page.nextOffset;
        if (nextOffset == null || nextOffset <= process.offset) {
          break;
        }
        process.offset = nextOffset;
      }

      if (process.cancelled) {
        await _setState(process.address, AddressIndexingProcessState.stopped);
        return;
      }
      if (process.paused) {
        await _setState(process.address, AddressIndexingProcessState.paused);
        return;
      }

      await _setState(process.address, AddressIndexingProcessState.completed);
    } on Object catch (e, stack) {
      _log.warning('Address process failed for ${process.address}', e, stack);
      await _setState(
        process.address,
        AddressIndexingProcessState.failed,
        errorMessage: e.toString(),
      );
    }
  }

  Future<String> _triggerIndexing(String address) async {
    final results = await _indexerService.indexAddressesList(<String>[address]);
    for (final result in results) {
      if (_addressesEqual(result.address, address) &&
          result.workflowId.isNotEmpty) {
        return result.workflowId;
      }
    }
    throw Exception('Indexer did not return workflowId for $address');
  }

  Future<bool> _waitForWorkflow(_AddressProcess process) async {
    final workflowId = process.workflowId;
    if (workflowId == null || workflowId.isEmpty) {
      return false;
    }
    final startedAt = DateTime.now();
    while (!process.cancelled && !process.paused) {
      final status = await _indexerService.getAddressIndexingJobStatus(
        workflowId: workflowId,
      );
      if (status.status.isDone) {
        return status.status.isSuccess;
      }
      if (DateTime.now().difference(startedAt) > _indexingTimeout) {
        return false;
      }
      await Future<void>.delayed(_pollDelay);
    }
    return false;
  }

  Future<void> _setState(
    String address,
    AddressIndexingProcessState state, {
    String? errorMessage,
    bool clearError = false,
  }) async {
    await _appStateService.setAddressIndexingStatus(
      address: address,
      status: AddressIndexingProcessStatus(
        state: state,
        updatedAt: DateTime.now().toUtc(),
        errorMessage: clearError ? null : errorMessage,
      ),
    );
  }

  String _normalizeAddress(String address) {
    final trimmed = address.trim();
    if (trimmed.startsWith('0X')) {
      return '0x${trimmed.substring(2)}';
    }
    return trimmed;
  }

  bool _addressesEqual(String left, String right) {
    if (_isEthereumAddress(left) || _isEthereumAddress(right)) {
      return left.toLowerCase() == right.toLowerCase();
    }
    return left == right;
  }

  bool _isEthereumAddress(String address) {
    return address.startsWith('0x') || address.startsWith('0X');
  }
}

class _AddressProcess {
  _AddressProcess({
    required this.address,
  });

  final String address;
  String? workflowId;
  int offset = 0;
  bool indexingDone = false;
  bool paused = false;
  bool cancelled = false;
  Future<void>? running;
}
