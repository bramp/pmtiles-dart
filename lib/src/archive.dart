import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';

import 'convert.dart';
import 'directory.dart';
import 'exceptions.dart';
import 'header.dart';
import 'types.dart';

class PmTilesArchive {
  // TODO come up with a better interface than a RandomAccessFile.
  final RandomAccessFile f;

  /// The Archive's header.
  Header header;

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
    await f.setPosition(header.metadataOffset);
    final metadata = await f.read(header.metadataLength);
    final utf8ToJson = utf8.decoder.fuse(json.decoder);

    return _internalDecoder.fuse(utf8ToJson).convert(metadata);
  }

  /// Return the tile data for [tileId] as a list of bytes.
  ///
  /// If [uncompress] is true, the data will be uncompressed per the spec. This
  /// can be useful if the tile data is about to be re-served compressed, and
  /// can avoid a uncompress re-compress cycle.
  Future<List<int>> tile(int tileId, {bool uncompress = true}) async {
    final root = this.root;

    final entry = root.find(tileId);
    if (entry == null) {
      // TODO Convert to a nicer exception
      throw TileNotFoundException(tileId);
    }

    if (entry.isLeaf) {
      throw Exception("TODO Support leaf");
    }

    await f.setPosition(header.tileDataOffset + entry.offset);
    final tile = await f.read(entry.length);
    if (!uncompress) {
      return tile;
    }

    return tileDecoder.convert(tile);
  }

  static Future<PmTilesArchive> from(RandomAccessFile f) async {
    await f.setPosition(0);
    final headerAndRoot = await f.read(headerAndRootMaxLength);
    final header = Header(
      ByteData.view(
        // Make a copy of the first headerLength (127) bytes.
        headerAndRoot.sublist(0, headerLength).buffer,
      ),
    );
    header.validate();

    if (header.rootDirectoryOffset + header.rootDirectoryLength >
        headerAndRoot.length) {
      throw Exception('Root directory is out of bounds');
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
      root: Directory.from(uncompressedRoot),
    );
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
  Converter<List<int>, List<int>> decoder() => switch (this) {
        Compression.none => nullConverter,
        Compression.gzip => zlib.decoder,
        // TODO Add support for the following:
        // Compression.brotli,
        // Compression.zstd,
        _ => throw Exception('$this compression is not supported'),
      };
}
