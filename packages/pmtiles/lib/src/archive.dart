import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

import 'compression.dart';
import 'directory.dart';
import 'exceptions.dart';
import 'header.dart';
import 'io.dart';
import 'loading_cache.dart';
import 'range.dart';
import 'tile.dart';
import 'types.dart';
import 'utils.dart';

/// PmTiles archive
///
/// A PmTiles archive is a single file that contains all the tiles for a map.
///
class PmTilesArchive {
  final ReadAt _f;

  /// The archive's header.
  Header header;

  /// The archive's root directory.
  Directory root;

  /// Cache of leaf entries
  /// Currently unbounded.
  late final LoadingCache<(int, int), Directory> _leafCache;

  PmTilesArchive._(
    this._f, {
    required this.header,
    required this.root,
  }) {
    _leafCache = LoadingCache<(int, int), Directory>(
      (key) => _loadLeaf(key.$1, key.$2),
      capacity: 8,
    );
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get _internalDecoder {
    return header.internalCompression.decoder();
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get tileDecoder {
    return header.tileCompression.decoder();
  }

  /// Returns a JSON Object containing the embedded metadata.
  /// See https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#5-json-metadata
  Future<Object?> get metadata async {
    final metadata =
        await _f.readAt(header.metadataOffset, header.metadataLength);
    final utf8ToJson = utf8.decoder.fuse(json.decoder);

    return _internalDecoder.fuse(utf8ToJson).convert(await metadata.toBytes());
  }

  /// Finds the entry for this tile. If the tile is not found return null.
  Future<Entry?> lookup(int tileId) async {
    Directory dir = root; // Start at the root

    // Iteratively search for the tile, capped to three deep.
    for (int depth = 0; depth < 3; depth++) {
      final entry = dir.find(tileId);

      if (entry == null || !entry.isLeaf) {
        return entry;
      }

      assert(entry.isLeaf);

      dir = await _leaf(entry.offset, entry.length);
    }
    return null;
  }

  /// Returns a handle to a single tile [tileId].
  ///
  /// The returned tile may not exist, or be corrupt. This will be discovered
  /// when Tile.bytes() or Tile.compressedBytes() is called.
  Future<Tile> tile(int tileId) async {
    final entry = await lookup(tileId);
    if (entry == null || entry.isLeaf) {
      return Tile(
        tileId,
        exception: TileNotFoundException(tileId),
      );
    }

    final tile = await _f.readAt(
      header.tileDataOffset + entry.offset,
      entry.length,
    );

    return Tile(
      tileId,
      bytes: await tile.toBytes(),
      compression: tileCompression,
      type: tileType,
    );
  }

  /// Issues a read for the [range], then turns them into [Tile]s that are published to [controller].
  Future<void> _readRangeToTiles(
    final StreamController controller,
    List<MapEntry<Entry, List<int>>> entriesToTileIds,
  ) {
    assert(entriesToTileIds.isNotEmpty);
    assert(() {
      for (int i = 0; i < entriesToTileIds.length - 1; i++) {
        final Entry cur = entriesToTileIds[i].key;
        final Entry next = entriesToTileIds[i + 1].key;
        assert(cur.offset + cur.length == next.offset,
            "Expect entries $cur and $next to be contingous");
      }

      return true;
    }());

    // Calculate the range to read.
    int begin = entriesToTileIds.first.key.offset;
    Entry last = entriesToTileIds.last.key;
    int end = last.offset + last.length;

    return _f.readAt(header.tileDataOffset + begin, end - begin).then(
      (http.ByteStream stream) async {
        final buffer = CordBuffer();

        // Current entry being processed
        final i = entriesToTileIds.iterator;
        final more = i.moveNext();
        assert(more, "Expected there to be atleast one entry");

        // Current read offset
        int offset = begin;

        await for (final bytes in stream) {
          if (controller.isClosed) {
            // If one of the other streams broke, this may close the controller.
            break;
          }

          buffer.addAll(bytes);

          // If we have atleast enough bytes for the first entry, try and
          // process it, repeating until we don't have enough bytes anymore.
          Entry entry = i.current.key;
          while (buffer.length >= entry.length) {
            assert(offset == entry.offset,
                "Expected the entry $entry to start at the current offset ${hexPad(offset)}");

            final bytes = buffer.getRange(0, entry.length).toList();
            for (final tileId in i.current.value) {
              // For each tile this entry maps to, publish it.
              controller.add(Tile(
                tileId,
                bytes: bytes,
                compression: tileCompression,
                type: tileType,
              ));
            }

            buffer.removeRange(0, bytes.length);
            offset += bytes.length;

            // No more entries, so bail.
            if (!i.moveNext()) {
              break;
            }
            entry = i.current.key;
          }
        }

        assert(buffer.length == 0,
            "Expected to have read all the bytes but ${buffer.length} remain");
      },
    );
  }

  /// Returns a stream of tiles for the given [tileIds]. The tiles my be return
  /// out of order. This tries to batch the fetching of tiles together to reduce
  /// the calls to the underlying archive.
  Stream<Tile> tiles(List<int> tileIds) {
    // Seperate the definition and assignment of [controller] so that we can
    // pass it to the onListen callback.
    late final StreamController<Tile> controller;

    controller = StreamController(onListen: () async {
      try {
        // Find the location of all the tiles first.
        final entries = await Future.wait(tileIds.map(lookup));

        // Construct a map of the Entries to the Tile IDs.
        // This is because multiple tiles may share the same Entry.
        final entriesMap = SplayTreeMap<Entry, List<int>>(
          (key1, key2) => key1.offset.compareTo(key2.offset),
        );
        for (var i = 0; i < tileIds.length; i++) {
          final tileId = tileIds[i];
          final entry = entries[i];

          if (entry == null) {
            controller.add(Tile(
              tileId,
              exception: TileNotFoundException(tileId),
            ));
            continue;
          }

          if (entriesMap.containsKey(entry)) {
            entriesMap[entry]!.add(tileId);
          } else {
            entriesMap[entry] = [tileId];
          }
        }

        // Merge all entries together, into a few large range reads.
        final ranges = IntRange.unionAll(
          entriesMap.keys.map(
            (entry) => IntRange(entry.offset, entry.offset + entry.length),
          ),
        );

        // Now do the larger range reads.
        final reads = ranges.map((range) {
          /// Find all the entries that are in this range.
          /// They are already sorted, and will be processed in order.
          /// TODO We can most likey be smarter can use the fact they are sorted
          /// to partition this.
          final rangeEntries = entriesMap.entries
              .where((e) => range.contains(e.key.offset))
              .toList();

          return _readRangeToTiles(controller, rangeEntries);
        });

        /// Finally await for all the reads to have finished before closing the
        /// stream.
        await Future.wait(reads);
      } catch (e) {
        controller.addError(e);
      } finally {
        controller.close();
      }
    });

    return controller.stream;
  }

  /// Read a Leaf Directory from offset (from the beginning of the left section)
  Future<Directory> _loadLeaf(int offset, int length) async {
    if (offset + length > header.leafDirectoriesLength) {
      throw CorruptArchiveException(
          "Directory Entry points outside of leaf directory.");
    }

    // TODO Consider if we want to cache leafs.
    // I suspect at any time we are only using 1-2 of them.

    final leaf = await _f.readAt(header.leafDirectoriesOffset + offset, length);
    final uncompressedleaf = _internalDecoder.convert(await leaf.toBytes());

    return Directory.from(uncompressedleaf, header: header);
  }

  /// Read a Leaf Directory from offset (from the beginning of the left section) and cache it.
  Future<Directory> _leaf(int offset, int length) async {
    return _leafCache.get((offset, length));
  }

  /// Reads a PmTiles archive from the given ReadAt interface.
  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  static Future<PmTilesArchive> fromReadAt(ReadAt f) async {
    final headerAndRoot =
        await (await f.readAt(0, headerAndRootMaxLength)).toBytes();

    if (headerAndRoot.length < headerLength) {
      throw CorruptArchiveException('Header is too short.');
    }

    final header = Header(
      ByteData.view(
        // Make a copy of the first headerLength (127) bytes.
        headerAndRoot.sublist(0, headerLength).buffer,
      ),
    );
    header.validate();

    if (header.rootDirectoryOffset + header.rootDirectoryLength >
        headerAndRoot.length) {
      throw CorruptArchiveException('Root directory is out of bounds.');
    }

    if (header.clustered == Clustered.notClustered) {
      throw UnsupportedError('Unclustered archives.');
    }

    final root = Uint8List.view(
      headerAndRoot.buffer,
      header.rootDirectoryOffset,
      header.rootDirectoryLength,
    );

    final uncompressedRoot = header.internalCompression.decoder().convert(root);

    return PmTilesArchive._(
      f,
      header: header,
      root: Directory.from(uncompressedRoot, header: header),
    );
  }

  /// Opens the PmTiles archive from the given path or URL.
  static Future<PmTilesArchive> from(String pathOrUrl) async {
    if (pathOrUrl.startsWith('http://') || pathOrUrl.startsWith('https://')) {
      return fromUri(Uri.parse(pathOrUrl));
    }
    return fromFile(File(pathOrUrl));
  }

  /// Opens a PmTiles archive from the given URL.
  static Future<PmTilesArchive> fromUri(
    Uri url, {
    http.Client? client,
    Map<String, String>? headers,
  }) async {
    return fromReadAt(HttpAt(
      client ?? http.Client(),
      url,
      headers: headers,
      // We ask the HttpAt to close the client if we created it here.
      closeClient: client == null,
    ));
  }

  /// Opens a PmTiles archive from the given file.
  /// Must call [close] when done.
  static Future<PmTilesArchive> fromFile(File f) async {
    return fromReadAt(FileAt(f));
  }

  static Future<PmTilesArchive> fromBytes(List<int> bytes) async {
    return fromReadAt(MemoryAt(bytes));
  }

  Future<void> close() async {
    return _f.close();
  }

  /// The version of the PMTiles spec this archive uses.
  int get version => header.version;

  /// Compression of all tiles in the archive.
  Compression get tileCompression => header.tileCompression;

  /// Type of tiles in the archive.
  TileType get tileType => header.tileType;

  /// The minimum zoom of the tiles in the archive.
  int get minZoom => header.minZoom;

  /// The maximum zoom of the tiles in the archive.
  int get maxZoom => header.maxZoom;

  /// The minimum latitude and longitude of the bounds of the tiles in
  /// the archive.
  LatLng get minPosition => header.minPosition;

  /// The maximum latitude and longitude of the bounds of the tiles in
  /// the archive.
  LatLng get maxPosition => header.maxPosition;

  /// The center zoom.
  /// A reader MAY use this as the initial zoom when displaying tiles from the
  /// PMTiles archive.
  int get centerZoom => header.centerZoom;

  /// The latitude and longitude of the center position.
  /// A reader MAY use this as the initial center position when displaying tiles
  /// from the PMTiles archive.
  LatLng get centerPosition => header.centerPosition;
}
