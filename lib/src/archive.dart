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

  /// Cache of the Archive's header. Populated with a call to [header].
  Header? _header;

  PmTilesArchive._(
    this.f,
  );

  /// Returns the PMTiles header.
  /// See https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#3-header
  /// TODO make this not async
  Future<Header> get header async {
    if (_header != null) return _header!;

    await f.setPosition(0);
    final headerAndRoot = await f.read(headerAndRootMaxLength);

    _header = Header(
      ByteData.sublistView(headerAndRoot, 0, 127),
    );
    _header!.validate();

    return _header!;
  }

  Future<Directory> get root async {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    // TODO This can be read out of the first 16k we already read.
    await f.setPosition(header.rootDirectoryOffset);
    final root = await f.read(header.rootDirectoryLength);

    final uncompressedRoot = _internalDecoder.convert(root);

    return Directory.from(uncompressedRoot);
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get _internalDecoder {
    assert(_header != null, 'Must call header before metadata');

    return _header!.internalCompression.decoder();
  }

  /// Return an appropriate decoder for the internal compression.
  Converter<List<int>, List<int>> get tileDecoder {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

    return header.tileCompression.decoder();
  }

  /// Returns a JSON Object containing the embedded metadata.
  /// See https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#5-json-metadata
  Future<Object?> get metadata async {
    assert(_header != null, 'Must call header before metadata');
    final header = _header!;

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
    assert(_header != null, 'Must call header before lookup');
    final header = _header!;

    final root = await this.root;

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
    final archive = PmTilesArchive._(f);

    // Read it once to check it's valid.
    await archive.header;

    return archive;
  }

  /// The version of the PMTiles spec this archive uses.
  int get version => _header!.version;

  /// Compression of all tiles in the archive.
  Compression get tileCompression => _header!.tileCompression;

  /// Type of tiles in the archive.
  TileType get tileType => _header!.tileType;

  /// The minimum zoom of the tiles in the archive.
  int get minZoom => _header!.minZoom;

  /// The maximum zoom of the tiles in the archive.
  int get maxZoom => _header!.maxZoom;

  /// The minimum latitude and longitude of the bounds of the tiles in
  /// the archive.
  LatLng get minPosition => _header!.minPosition;

  /// The maximum latitude and longitude of the bounds of the tiles in
  /// the archive.
  LatLng get maxPosition => _header!.maxPosition;

  /// The center zoom.
  /// A reader MAY use this as the initial zoom when displaying tiles from the
  /// PMTiles archive.
  int get centerZoom => _header!.centerZoom;

  /// The latitude and longitude of the center position.
  /// A reader MAY use this as the initial center position when displaying tiles
  /// from the PMTiles archive.
  LatLng get centerPosition => _header!.centerPosition;
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
