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

    test('sublist', () {
      final buffer = CordBuffer();
      buffer.addAll([1, 2, 3]);
      buffer.addAll([4, 5, 6]);
      expect(buffer.length, equals(6));

      final full = [1, 2, 3, 4, 5, 6];

      expect(buffer.sublist(0, 0), equals(full.sublist(0, 0)));
      expect(buffer.sublist(0, 1), equals(full.sublist(0, 1)));
      expect(buffer.sublist(0, 2), equals(full.sublist(0, 2)));
      expect(buffer.sublist(0, 3), equals(full.sublist(0, 3)));
      expect(buffer.sublist(0, 4), equals(full.sublist(0, 4)));

      // This is not currently supported.
      //expect(buffer.sublist(1, 3), equals(full.sublist(1, 3)));
      //expect(buffer.sublist(3, 5), equals(full.sublist(3, 5)));
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

    test('large', () {
      // This is a ~real example from running code, that was terribly slow!
      final buffer = CordBuffer();
      final bytes = List.generate(2 * 1024 * 1024, (index) => index % 256);

      buffer.addAll(bytes);

      while (buffer.length > 0) {
        final read = buffer.sublist(0, 1024).toList();
        expect(read.length, equals(1024));

        buffer.removeRange(0, 1024);
      }
    });
  });
}
