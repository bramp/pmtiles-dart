import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'convert.dart';
import 'directory.dart';
import 'exceptions.dart';
import 'header.dart';
import 'io.dart';
import 'tile.dart';
import 'types.dart';

class PmTilesArchive {
  final ReadAt f;

  /// The archive's header.
  Header header;

  /// The archive's root directory.
  Directory root;

  PmTilesArchive._(
    this.f, {
    required this.header,
    required this.root,
  });

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
        await f.readAt(header.metadataOffset, header.metadataLength);
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

  /// Return the tile data for [tileId] as a list of bytes.
  ///
  /// If [uncompress] is true, the data will be uncompressed per the spec. This
  /// can be useful if the tile data is about to be re-served compressed, and
  /// can avoid a uncompress re-compress cycle.
  Future<List<int>> tile(int tileId, {bool uncompress = true}) async {
    final entry = await lookup(tileId);
    if (entry == null || entry.isLeaf) {
      throw TileNotFoundException(tileId);
    }

    final tile =
        await f.readAt(header.tileDataOffset + entry.offset, entry.length);
    if (!uncompress) {
      return tile.toBytes();
    }

    return tileDecoder.convert(await tile.toBytes());
  }

  /// Read a Leaf Directory from offset (from the beginning of the left section)
  Future<Directory> _leaf(int offset, int length) async {
    if (offset + length > header.leafDirectoriesLength) {
      throw CorruptArchiveException(
          "Directory Entry points outside of leaf directory.");
    }

    // TODO Consider if we want to cache leafs.
    // I suspect at any time we are only using 1-2 of them.

    final leaf = await f.readAt(header.leafDirectoriesOffset + offset, length);
    final uncompressedleaf = _internalDecoder.convert(await leaf.toBytes());

    return Directory.from(uncompressedleaf, header: header);
  }

  static Future<PmTilesArchive> _from(ReadAt f) async {
    final headerAndRoot =
        await (await f.readAt(0, headerAndRootMaxLength)).toBytes();
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
      throw UnimplementedError('Unclustered archives are not supported.');
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
    return _from(HttpAt(client ?? http.Client(), url, headers: headers));
  }

  /// Opens a PmTiles archive from the given file.
  /// Must call [close] when done.
  static Future<PmTilesArchive> fromFile(File f) async {
    final r = await f.open(mode: FileMode.read);
    return _from(RandomAccessFileAt(r));
  }

  Future<void> close() async {
    return f.close();
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

extension on Compression {
  // TODO I wonder if we can change this to Converter<Uint8List, Uint8List>
  Converter<List<int>, List<int>> decoder() => switch (this) {
        Compression.none => nullConverter,
        Compression.gzip => zlib.decoder,
        // TODO Add support for the following:
        // Compression.brotli,
        // Compression.zstd,
        _ => throw UnimplementedError('$this compression is not supported.'),
      };
}
