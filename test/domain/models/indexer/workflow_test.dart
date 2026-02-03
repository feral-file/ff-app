import 'package:app/domain/models/indexer/workflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('IndexingJobStatus isDone/isSuccess', () {
    expect(IndexingJobStatus.completed.isDone, isTrue);
    expect(IndexingJobStatus.completed.isSuccess, isTrue);
    expect(IndexingJobStatus.running.isDone, isFalse);
  });
}

// End of file.
