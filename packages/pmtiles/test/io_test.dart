import 'dart:io';
import 'dart:typed_data';

import 'package:pmtiles/src/io.dart';
import 'package:test/test.dart';

void main() {
  group('FileAt', () {
    late Directory directory;
    late File tempFile;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp();
      tempFile = File("${directory.path}/test_file");

      final f = await tempFile.create();
      await f.writeAsBytes(
        List.generate(100, (index) => index),
      );
    });

    tearDown(() async {
      await directory.delete(recursive: true);
    });

    final tests = <(int, int), List<int>>{
      (0, 0): [],
      (0, 1): [0],
      (0, 5): [0, 1, 2, 3, 4],
      (0, 10): [0, 1, 2, 3, 4, 5, 6, 7, 8, 9],
      (1, 9): [1, 2, 3, 4, 5, 6, 7, 8, 9],
      (2, 2): [2, 3],
    };

    test('readAt single', () async {
      final f = FileAt(tempFile);

      for (final t in tests.entries) {
        final (offset, length) = t.key;
        final expected = t.value;

        final stream = await f.readAt(offset, length);
        final bytes = await stream.toBytes();

        expect(bytes, equals(expected));
      }
    });

    test('readAt concurrent', () async {
      final f = FileAt(tempFile);

      Future<Uint8List> readAt(int offset, int length) async {
        final stream = await f.readAt(offset, length);
        return await stream.toBytes();
      }

      var count = 0;
      final allReads = tests.map((key, value) {
        final (offset, length) = key;
        final expected = value;

        return MapEntry(
          key,
          readAt(offset, length).then((actual) {
            expect(actual, equals(expected));
            count++;
          }),
        );
      });

      // Now we await all the reads at the same time
      // The actual test is done a few lines up.
      await Future.wait(allReads.values);
      expect(count, equals(tests.length));
    });
  });

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
