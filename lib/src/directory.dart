import 'package:meta/meta.dart';
import 'package:pmtiles/src/zxy.dart';
import 'package:protobuf/protobuf.dart';

/// A single entry in the directory. Represents either:
/// 1) One or more tiles that are identical.
/// 2) A leaf entry.
class Entry {
  /// The tile ID of the first tile in this run.
  int tileId;

  /// The number of tiles which are identical to this one.
  int runLength;

  /// The offset within the Tile Data section.
  int offset;

  /// The length of this tile within the Tile Data section.
  int length;

  Entry({
    this.tileId = 0,
    this.runLength = 0,
    this.offset = 0,
    this.length = 0,
  });

  ZXY get zxy => ZXY.fromTileId(tileId);

  /// Is a entry that indexes into the leaf directory.
  bool get isLeaf => runLength == 0;

  @override
  String toString() {
    pad(x) => x.toRadixString(16).padLeft(8, '0');

    final address = '[${pad(offset)}-${pad(offset + length)})';
    if (isLeaf) {
      return '$address leaf: $tileId';
    }

    if (runLength == 1) {
      return '$address tile: $tileId';
    }

    return '$address tiles $tileId-${tileId + runLength} (run: $runLength)';
  }
}

@immutable
class Directory {
  final List<Entry> entries;

  /// The number of tiles in the directory. If null, the number of tiles is unknown.
  /// Should match the [numberOfTileEntries] value in the [Header].
  /// TODO Validate the above statement.
  final int? totalTiles;

  Directory({
    required this.entries,
    this.totalTiles,
  }) : assert(totalTiles == null || totalTiles >= entries.length);

  static Directory from(List<int> uncompressed) {
    final reader = CodedBufferReader(uncompressed);

    final n = reader.readUint64().toInt();

    // TODO Check there is roughly ~4 bytes * n available in the buffer.

    final entries = <Entry>[];

    // TODO Due to how ints work, `n.toInt()` may lose percesion, and we should
    // check if that impacts us.
    // TODO I bet these can all be readUint32, and it'll be fine!
    int lastId = 0;
    for (var i = 0; i < n; i++) {
      final delta = reader.readUint64().toInt();
      // TODO Check we don't overflow lastId
      lastId += delta;

      entries.add(Entry(tileId: lastId));
    }

    int totalTiles = 0;
    for (var i = 0; i < n; i++) {
      final run = reader.readUint32().toInt();
      entries[i].runLength = run;
      totalTiles += run;
    }

    for (var i = 0; i < n; i++) {
      entries[i].length = reader.readUint32().toInt();
    }

    for (var i = 0; i < n; i++) {
      final offset = reader.readUint64().toInt();

      if (offset == 0) {
        /// Offset of zero means this entry is immediately following the
        /// previous one.

        if (i == 0) {
          throw Exception("Invalid offset of zero in first entry of directory");
        }

        final prevEntry = entries[i - 1];
        entries[i].offset = prevEntry.offset + prevEntry.length;
      } else {
        /// Non-zero offset, means real offset is offset - 1.
        entries[i].offset = offset - 1;
      }

      // TODO Check entries[i].offset is < header.tileDataLength
    }

    assert(reader.isAtEnd(), "We should have read everything");

    return Directory(
      entries: entries,
      totalTiles: totalTiles,
    );
  }

  /// Finds the [Entry] which contains [tileId], or null if not found.
  Entry? find(int tileId) {
    // TODO Change this to a binary search, and not a linear search.
    for (final entry in entries) {
      if (entry.tileId <= tileId && tileId < entry.tileId + entry.runLength) {
        return entry;
      }
    }
    return null;
  }

  @override
  String toString() {
    return '''
      entries:
        ${entries.join('\n        ')}
      totalTiles: $totalTiles,
    ''';
  }
}
