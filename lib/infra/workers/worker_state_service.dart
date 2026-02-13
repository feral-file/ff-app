// Reason: persistence interface methods are intentionally concise.
// ignore_for_file: public_member_api_docs

import 'dart:convert';

import 'package:app/infra/database/objectbox_init.dart';
import 'package:app/infra/database/objectbox_models.dart';
import 'package:app/objectbox.g.dart' show WorkerStateEntity_;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';
import 'package:objectbox/objectbox.dart';

/// Persisted worker state + optional checkpoint payload.
class WorkerStateSnapshot {
  const WorkerStateSnapshot({
    required this.stateIndex,
    this.checkpoint,
  });

  final int stateIndex;
  final Map<String, dynamic>? checkpoint;
}

abstract class WorkerStateStore {
  Future<WorkerStateSnapshot?> load(String workerId);

  Future<void> save({
    required String workerId,
    required int stateIndex,
    Map<String, dynamic>? checkpoint,
  });

  Future<void> clearCheckpoint(String workerId);
}

/// ObjectBox-backed persistence service for worker state/checkpoints.
class WorkerStateService implements WorkerStateStore {
  WorkerStateService({
    required Box<WorkerStateEntity> workerStateBox,
    Logger? logger,
  }) : _workerStateBox = workerStateBox,
       _log = logger ?? Logger('WorkerStateService');

  final Box<WorkerStateEntity> _workerStateBox;
  final Logger _log;

  WorkerStateEntity _getOrCreate(String workerId) {
    final query = _workerStateBox
        .query(WorkerStateEntity_.workerId.equals(workerId))
        .build();
    final existing = query.findFirst();
    query.close();
    if (existing != null) {
      return existing;
    }

    final created = WorkerStateEntity(
      workerId: workerId,
      updatedAtUs: DateTime.now().toUtc().microsecondsSinceEpoch,
    );
    created.id = _workerStateBox.put(created);
    return created;
  }

  @override
  Future<WorkerStateSnapshot?> load(String workerId) async {
    final query = _workerStateBox
        .query(WorkerStateEntity_.workerId.equals(workerId))
        .build();
    final row = query.findFirst();
    query.close();
    if (row == null) {
      return null;
    }

    Map<String, dynamic>? checkpoint;
    if (row.hasCheckpoint && row.checkpointJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(row.checkpointJson);
        if (decoded is Map<String, dynamic>) {
          checkpoint = decoded;
        } else if (decoded is Map) {
          checkpoint = Map<String, dynamic>.from(decoded);
        }
      } on FormatException catch (e) {
        _log.warning('Failed to decode checkpoint for $workerId: $e');
      }
    }

    return WorkerStateSnapshot(
      stateIndex: row.stateIndex,
      checkpoint: checkpoint,
    );
  }

  @override
  Future<void> save({
    required String workerId,
    required int stateIndex,
    Map<String, dynamic>? checkpoint,
  }) async {
    final row = _getOrCreate(workerId)
      ..stateIndex = stateIndex
      ..hasCheckpoint = checkpoint != null
      ..checkpointJson = checkpoint == null ? '{}' : jsonEncode(checkpoint)
      ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
    _workerStateBox.put(row);
  }

  @override
  Future<void> clearCheckpoint(String workerId) async {
    final row = _getOrCreate(workerId)
      ..hasCheckpoint = false
      ..checkpointJson = '{}'
      ..updatedAtUs = DateTime.now().toUtc().microsecondsSinceEpoch;
    _workerStateBox.put(row);
  }
}

final workerStateServiceProvider = Provider<WorkerStateStore>((ref) {
  final store = getInitializedObjectBoxStore();
  return WorkerStateService(
    workerStateBox: store.box<WorkerStateEntity>(),
    logger: Logger('WorkerStateService'),
  );
});
