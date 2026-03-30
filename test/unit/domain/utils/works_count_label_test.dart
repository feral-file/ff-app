import 'package:app/domain/utils/works_count_label.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatWorksCountLabel', () {
    test('uses singular for exactly one', () {
      expect(formatWorksCountLabel(1), '1 work');
    });

    test('uses plural for zero and counts greater than one', () {
      expect(formatWorksCountLabel(0), '0 works');
      expect(formatWorksCountLabel(2), '2 works');
      expect(formatWorksCountLabel(7), '7 works');
    });
  });
}
