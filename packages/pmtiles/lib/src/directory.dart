import 'package:collection/collection.dart';
import 'package:meta/meta.dart';
import 'exceptions.dart';
import 'zxy.dart';
import 'package:protobuf/protobuf.dart';

/// A single entry in the directory. Represents either:
/// 1) One or more tiles that are identical.
/// 2) A leaf entry.
class Entry {
  /// The first tile ID in this run of tiles that are identical to this one.
  int tileId;

  /// The length of this run.
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

  int get lastTileId => tileId + runLength;

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

    return '$address tiles $tileId-$lastTileId (run: $runLength)';
  }
}

@immutable
class Directory {
  final List<Entry> entries;

  Directory({required this.entries});

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

    for (var i = 0; i < n; i++) {
      final run = reader.readUint32().toInt();
      entries[i].runLength = run;
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
          throw CorruptArchiveException(
              "Invalid offset of zero in first entry of directory");
        }

        final prevEntry = entries[i - 1];
        entries[i].offset = prevEntry.offset + prevEntry.length;
      } else {
        /// Non-zero offset, means real offset is offset - 1.
        entries[i].offset = offset - 1;
      }

      // TODO Check entries[i].offset is < header.tileDataLength
    }
    assert(entries.isSorted((a, b) => a.tileId.compareTo(b.tileId)));

    assert(reader.isAtEnd(), "We should have read everything");

    return Directory(entries: entries);
  }

  /// Finds the [Entry] which contains [tileId], or null if not found.
  Entry? find(int tileId) {
    final i = lowerBound(
      entries,
      Entry(tileId: tileId),
      compare: (p0, p1) => p0.tileId <= p1.tileId ? -1 : 1,
    );

    if (i == 0) {
      // Result is before the directory
      return null;
    }

    if (i > 0) {
      final entry = entries[i - 1];

      if (entry.isLeaf ||
          (entry.tileId <= tileId && tileId < entry.lastTileId)) {
        return entry;
      }
    }

    return null;
  }

  @override
  String toString() {
    return 'entries:\n'
        '  ${entries.join('\n  ')}';
  }
}
