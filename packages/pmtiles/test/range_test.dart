import 'package:pmtiles/src/range.dart';
import 'package:test/test.dart';
import 'package:trotter/trotter.dart';

void main() {
  group('IntRange', () {
    test('contains', () {
      final range = IntRange(0, 10);

      expect(range.contains(5), isTrue);
      expect(range.contains(10), isFalse);
    });

    test('overlaps', () {
      final range1 = IntRange(0, 10);
      final range2 = IntRange(5, 15);
      final range3 = IntRange(10, 20);

      expect(range1.overlaps(range2), isTrue);
      expect(range1.overlaps(range3), isFalse);
    });

    test('union (overlap)', () {
      final range1 = IntRange(0, 10);
      final range2 = IntRange(5, 15);

      expect(range1.union(range2), equals(IntRange(0, 15)));
      expect(range2.union(range1), equals(IntRange(0, 15)));
    });

    test('union (adjacent)', () {
      final range1 = IntRange(5, 15);
      final range2 = IntRange(15, 20);

      expect(range1.union(range2), equals(IntRange(5, 20)));
      expect(range2.union(range1), equals(IntRange(5, 20)));
    });

    test('union (consume)', () {
      final range1 = IntRange(0, 15);
      final range2 = IntRange(5, 10);

      expect(range1.union(range2), equals(IntRange(0, 15)));
      expect(range2.union(range1), equals(IntRange(0, 15)));
    });

    test('union (no overlap)', () {
      final range1 = IntRange(0, 5);
      final range2 = IntRange(25, 30);

      expect(() => range1.union(range2), throwsFormatException);
      expect(() => range2.union(range1), throwsFormatException);
    });

    test('unionAll', () {
      final ranges = [
        IntRange(0, 10),
        IntRange(5, 15),
        IntRange(15, 20),
        IntRange(0, 15),
        IntRange(5, 10),
        IntRange(0, 5),
        IntRange(25, 30),
      ];

      // Try all Permutations of the ranges
      for (final ranges in Permutations(ranges.length, ranges).call()) {
        expect(
          IntRange.unionAll(ranges),
          equals([IntRange(0, 20), IntRange(25, 30)]),
        );
      }
    });
  });
}
