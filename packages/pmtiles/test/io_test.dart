import 'package:pmtiles/src/io.dart';
import 'package:test/test.dart';

void main() {
  group('CordBuffer', () {
    test('addAll', () {
      final buffer = CordBuffer();
      buffer.addAll([1, 2, 3]);
      expect(buffer.toList(), equals([1, 2, 3]));
      expect(buffer.length, equals(3));

      buffer.addAll([4, 5, 6]);
      expect(buffer.toList(), equals([1, 2, 3, 4, 5, 6]));
      expect(buffer.length, equals(6));
    });

    test('getRange', () {
      final buffer = CordBuffer();
      buffer.addAll([1, 2, 3]);
      buffer.addAll([4, 5, 6]);
      expect(buffer.length, equals(6));

      final full = [1, 2, 3, 4, 5, 6];

      expect(buffer.getRange(0, 0), equals(full.getRange(0, 0)));
      expect(buffer.getRange(0, 1), equals(full.getRange(0, 1)));
      expect(buffer.getRange(0, 2), equals(full.getRange(0, 2)));
      expect(buffer.getRange(0, 3), equals(full.getRange(0, 3)));
      expect(buffer.getRange(1, 3), equals(full.getRange(1, 3)));

      expect(buffer.getRange(0, 4), equals(full.getRange(0, 4)));
      expect(buffer.getRange(3, 5), equals(full.getRange(3, 5)));
    });

    test('removeRange', () {
      final buffer = CordBuffer();
      buffer.addAll([1, 2, 3]);
      buffer.addAll([4, 5, 6]);
      expect(buffer.length, equals(6));

      buffer.removeRange(0, 0);
      expect(buffer.toList(), equals([1, 2, 3, 4, 5, 6]));
      expect(buffer.length, equals(6));

      buffer.removeRange(0, 1);
      expect(buffer.toList(), equals([2, 3, 4, 5, 6]));
      expect(buffer.length, equals(5));

      buffer.removeRange(0, 3);
      expect(buffer.toList(), equals([5, 6]));
      expect(buffer.length, equals(2));

      buffer.removeRange(0, 2);
      expect(buffer.toList(), equals([]));
      expect(buffer.length, equals(0));
    });
  });
}
