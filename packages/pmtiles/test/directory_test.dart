import 'package:pmtiles/src/directory.dart';
import 'package:pmtiles/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('Directory.from', () {
    test('accepts empty directory in non-strict mode', () {
      final directory = Directory.from([0]);
      expect(directory.entries, isEmpty);
    });

    test('accepts zero-length entry in non-strict mode', () {
      final bytes = encodeDirectory([
        EncodedEntry(tileId: 0, runLength: 1, length: 0, encodedOffset: 1),
      ]);

      final directory = Directory.from(bytes);
      expect(directory.entries, hasLength(1));
      expect(directory.entries.single.length, 0);
    });

    test('accepts valid single entry directory', () {
      final bytes = encodeDirectory([
        EncodedEntry(tileId: 0, runLength: 1, length: 1, encodedOffset: 1),
      ]);

      final directory = Directory.from(bytes);
      expect(directory.entries, hasLength(1));
      expect(directory.entries.single.tileId, 0);
      expect(directory.entries.single.runLength, 1);
      expect(directory.entries.single.length, 1);
      expect(directory.entries.single.offset, 0);
    });

    test('rejects empty directory in strict mode', () {
      expect(
        () => Directory.from([0], strict: true),
        throwsA(isA<CorruptArchiveException>()),
      );
    });

    test('rejects zero-length entry in strict mode', () {
      final bytes = encodeDirectory([
        EncodedEntry(tileId: 0, runLength: 1, length: 0, encodedOffset: 1),
      ]);

      expect(
        () => Directory.from(bytes, strict: true),
        throwsA(isA<CorruptArchiveException>()),
      );
    });
  });
}

class EncodedEntry {
  const EncodedEntry({
    required this.tileId,
    required this.runLength,
    required this.length,
    required this.encodedOffset,
  });

  final int tileId;
  final int runLength;
  final int length;
  final int encodedOffset;
}

List<int> encodeDirectory(List<EncodedEntry> entries) {
  final out = <int>[];
  writeVarint(out, entries.length);

  var lastTileId = 0;
  for (final entry in entries) {
    writeVarint(out, entry.tileId - lastTileId);
    lastTileId = entry.tileId;
  }

  for (final entry in entries) {
    writeVarint(out, entry.runLength);
  }

  for (final entry in entries) {
    writeVarint(out, entry.length);
  }

  for (final entry in entries) {
    writeVarint(out, entry.encodedOffset);
  }

  return out;
}

void writeVarint(List<int> out, int value) {
  if (value < 0) {
    throw ArgumentError.value(value, 'value', 'Must be >= 0');
  }

  var v = value;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
}
