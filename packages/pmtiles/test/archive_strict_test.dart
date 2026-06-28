@TestOn('vm')
library;

import 'dart:typed_data';

import 'package:pmtiles/src/archive.dart';
import 'package:pmtiles/src/exceptions.dart';
import 'package:test/test.dart';

void main() {
  group('PmTilesArchive.fromBytes strict mode', () {
    test('non-strict mode allows empty root directory', () async {
      final archive = await PmTilesArchive.fromBytes(
        buildArchiveWithRootDirectory(encodeDirectory([])),
      );
      await archive.close();
    });

    test('strict mode rejects empty root directory', () async {
      await expectLater(
        () => PmTilesArchive.fromBytes(
          buildArchiveWithRootDirectory(encodeDirectory([])),
          strict: true,
        ),
        throwsA(isA<CorruptArchiveException>()),
      );
    });

    test(
      'strict mode rejects zero-length root directory entry',
      () async {
        final rootDir = encodeDirectory([
          const EncodedEntry(
            tileId: 0,
            runLength: 1,
            length: 0,
            encodedOffset: 1,
          ),
        ]);

        await expectLater(
          () => PmTilesArchive.fromBytes(
            buildArchiveWithRootDirectory(rootDir),
            strict: true,
          ),
          throwsA(isA<CorruptArchiveException>()),
        );
      },
    );
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
  var v = value;
  while (v >= 0x80) {
    out.add((v & 0x7f) | 0x80);
    v >>= 7;
  }
  out.add(v);
}

List<int> buildArchiveWithRootDirectory(List<int> rootDirectoryBytes) {
  const headerLength = 127;
  const rootOffset = headerLength;
  final rootLength = rootDirectoryBytes.length;

  // Keep all other sections empty and colocated after root.
  final metadataOffset = rootOffset + rootLength;
  final leafDirsOffset = metadataOffset;
  final tileDataOffset = metadataOffset;

  final header = ByteData(headerLength);

  final magic = Uint8List.fromList('PMTiles'.codeUnits);
  for (var i = 0; i < magic.length; i++) {
    header.setUint8(i, magic[i]);
  }
  header
    ..setUint8(0x07, 3) // version
    ..setUint64(0x08, rootOffset, Endian.little)
    ..setUint64(0x10, rootLength, Endian.little)
    ..setUint64(0x18, metadataOffset, Endian.little)
    ..setUint64(0x20, 0, Endian.little) // metadata length
    ..setUint64(0x28, leafDirsOffset, Endian.little)
    ..setUint64(0x30, 0, Endian.little) // leaf dirs length
    ..setUint64(0x38, tileDataOffset, Endian.little)
    ..setUint64(0x40, 0, Endian.little) // tile data length
    // Addressed tiles / entries / contents unknown -> 0
    ..setUint64(0x48, 0, Endian.little)
    ..setUint64(0x50, 0, Endian.little)
    ..setUint64(0x58, 0, Endian.little)
    // clustered=true, internal=none, tile=none, type=unknown
    ..setUint8(0x60, 1)
    ..setUint8(0x61, 1)
    ..setUint8(0x62, 1)
    ..setUint8(0x63, 0)
    // min/max zoom
    ..setUint8(0x64, 0)
    ..setUint8(0x65, 0);

  // min/max/center positions + center zoom remain zeroed.

  return [
    ...header.buffer.asUint8List(),
    ...rootDirectoryBytes,
  ];
}
