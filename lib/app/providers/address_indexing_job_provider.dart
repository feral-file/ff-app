import 'package:app/domain/models/indexer/workflow.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// In-memory indexing job status by address for the current app session.
///
/// Notes:
/// - This state is **not persisted**. It exists to drive real-time UI updates
///   while indexing is running.
/// - Keys are stored lowercased so Ethereum addresses match regardless of case.
class AddressIndexingJobState {
  const AddressIndexingJobState({
    this.jobsByAddress = const <String, AddressIndexingJobResponse>{},
  });

  final Map<String, AddressIndexingJobResponse> jobsByAddress;

  AddressIndexingJobState copyWith({
    Map<String, AddressIndexingJobResponse>? jobsByAddress,
  }) {
    return AddressIndexingJobState(
      jobsByAddress: jobsByAddress ?? this.jobsByAddress,
    );
  }

  AddressIndexingJobResponse? getJob(String address) {
    if (address.isEmpty) return null;
    return jobsByAddress[address.toLowerCase()];
  }

  bool isIndexing(String address) {
    final job = getJob(address);
    return job?.status == IndexingJobStatus.running;
  }

  int get activeIndexingCount {
    return jobsByAddress.values
        .where((job) => job.status == IndexingJobStatus.running)
        .length;
  }
}

class AddressIndexingJobNotifier extends Notifier<AddressIndexingJobState> {
  @override
  AddressIndexingJobState build() => const AddressIndexingJobState();

  void updateJob(AddressIndexingJobResponse response) {
    if (response.address.isEmpty) return;
    final updated = Map<String, AddressIndexingJobResponse>.from(
      state.jobsByAddress,
    );
    updated[response.address.toLowerCase()] = response;
    state = state.copyWith(jobsByAddress: updated);
  }

  void clearJob(String address) {
    if (address.isEmpty) return;
    final updated = Map<String, AddressIndexingJobResponse>.from(
      state.jobsByAddress,
    )..remove(address.toLowerCase());
    state = state.copyWith(jobsByAddress: updated);
  }
}

/// Holds the latest indexing job status per address.
final addressIndexingJobProvider =
    NotifierProvider<AddressIndexingJobNotifier, AddressIndexingJobState>(
      AddressIndexingJobNotifier.new,
    );

/// Convenience provider to watch a single address.
final indexingJobStatusProvider =
    Provider.family<AddressIndexingJobResponse?, String>((ref, address) {
  return ref.watch(addressIndexingJobProvider).getJob(address);
});
