// Reason: worker message protocol types are self-descriptive.
// ignore_for_file: cast_nullable_to_non_nullable

/// Opcodes for worker isolate communication.
enum WorkerOpcode {
  /// Scheduler → Worker: start processing.
  start,

  /// Scheduler → Worker: pause and checkpoint.
  pause,

  /// Scheduler → Worker: stop completely.
  stop,

  /// Scheduler → Worker: add work item.
  enqueueWork,

  /// Worker → Scheduler: work item completed successfully.
  workComplete,

  /// Worker → Scheduler: work item failed.
  workFailed,

  /// Worker → Scheduler: state transition occurred.
  stateChanged,

  /// Worker → Scheduler: progress update.
  progressUpdate,

  /// IngestFeedWorker → Scheduler: query needed for bare items.
  queryNeeded,

  /// ItemEnrichmentQueryWorker → Scheduler: batches ready for distribution.
  batchesReady,

  /// ItemEnrichmentQueryWorker → Scheduler: no bare items to process.
  noBareItems,

  /// Scheduler → EnrichItemWorker: enrichment batch assignment.
  enrichmentNeeded,
}

/// Base message structure for worker isolate communication.
class WorkerMessage {
  /// Creates a [WorkerMessage].
  const WorkerMessage({
    required this.opcode,
    required this.workerId,
    required this.payload,
  });

  /// Creates a [WorkerMessage] from a list received from isolate.
  factory WorkerMessage.fromList(List<Object?> list) {
    if (list.length < 3) {
      throw ArgumentError('Invalid message format: $list');
    }

    final opcodeStr = list[0] as String;
    final opcode = WorkerOpcode.values.firstWhere(
      (op) => op.name == opcodeStr,
      orElse: () => throw ArgumentError('Unknown opcode: $opcodeStr'),
    );

    return WorkerMessage(
      opcode: opcode,
      workerId: list[1] as String,
      payload: Map<String, dynamic>.from(list[2] as Map),
    );
  }

  /// Message operation code.
  final WorkerOpcode opcode;

  /// ID of the worker sending or receiving this message.
  final String workerId;

  /// Message payload data.
  final Map<String, dynamic> payload;

  /// Converts this message to a sendable list for isolate communication.
  List<Object?> toList() {
    return <Object?>[
      opcode.name,
      workerId,
      payload,
    ];
  }

  @override
  String toString() => 'WorkerMessage(opcode: $opcode, workerId: $workerId)';
}
