import 'package:app/infra/database/objectbox_init.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('chooseObjectBoxOpenStrategy', () {
    test('uses create when no open store exists for path', () {
      final strategy = chooseObjectBoxOpenStrategy(isOpenAtPath: false);
      expect(strategy, ObjectBoxOpenStrategy.create);
    });

    test('uses attach when a store is already open for path', () {
      final strategy = chooseObjectBoxOpenStrategy(isOpenAtPath: true);
      expect(strategy, ObjectBoxOpenStrategy.attach);
    });
  });
}
