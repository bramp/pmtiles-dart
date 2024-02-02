import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:meta/meta.dart';

import 'convert.dart';
import 'exceptions.dart';
import 'types.dart';
import 'int64.dart';

// Minimum valid header length.
const headerLength = 127;

// Max header + root length.
const headerAndRootMaxLength = 16384;

/// PMTiles Header
///
/// Offset    00   01   02   03   04   05   06   07   08   09   0A   0B   0C   0D   0E   0F
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000000  |           Magic Number           |  V |         Root Directory Offset         |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000010  |         Root Directory Length         |            Metadata Offset            |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000020  |            Metadata Length            |        Leaf Directories Offset        |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000030  |        Leaf Directories Length        |            Tile Data Offset           |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000040  |            Tile Data Length           |         Num of Addressed Tiles        |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000050  |         Number of Tile Entries        |        Number of Tile Contents        |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000060  |  C | IC | TC | TT |MinZ|MaxZ|              Min Position             |      Max
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
/// 000070   Position                     |CenZ|            Center Position            |
///         +----+----+----+----+----+----+----+----+----+----+----+----+----+----+----+
@immutable
class Header {
  final ByteData data;

  Header(
    this.data,
  ) : assert(data.lengthInBytes == headerLength);

  Uint8List get magic => data.buffer.asUint8List(0x00, 0x07);
  int get version => data.getUint8(0x07);
  int get rootDirectoryOffset => data.getSafeUint64(0x08, Endian.little);
  int get rootDirectoryLength => data.getSafeUint64(0x10, Endian.little);
  int get metadataOffset => data.getSafeUint64(0x18, Endian.little);
  int get metadataLength => data.getSafeUint64(0x20, Endian.little);
  int get leafDirectoriesOffset => data.getSafeUint64(0x28, Endian.little);
  int get leafDirectoriesLength => data.getSafeUint64(0x30, Endian.little);
  int get tileDataOffset => data.getSafeUint64(0x38, Endian.little);
  int get tileDataLength => data.getSafeUint64(0x40, Endian.little);

  /// TODO Figure out what this field means.
  int get numberOfAddressedTiles => data.getSafeUint64(0x48, Endian.little);

  /// Number of tile entries in the directories. (I think)
  int get numberOfTileEntries => data.getSafeUint64(0x50, Endian.little);

  /// Number of unique tiles in the Tile Data. (I think)
  int get numberOfTileContents => data.getSafeUint64(0x58, Endian.little);

  Clustered get clustered => data.getClustered(0x60);

  /// Compression of the root directory, metadata, and all leaf directories.
  Compression get internalCompression => data.getCompression(0x61);

  /// Compression of the tile data.
  Compression get tileCompression => data.getCompression(0x62);

  /// Type of tile data.
  TileType get tileType => data.getTileType(0x63);

  int get minZoom => data.getUint8(0x64);
  int get maxZoom => data.getUint8(0x65);

  LatLng get minPosition => data.getLatLng(0x66);
  LatLng get maxPosition => data.getLatLng(0x6E);

  int get centerZoom => data.getUint8(0x76);
  LatLng get centerPosition => data.getLatLng(0x77);

  /// Checks the header is valid, and throws an exception if not.
  /// If [strict] is true, then additional checks are made.
  void validate({bool strict = false}) {
    final magic = utf8.decode(this.magic, allowMalformed: true);
    if (magic != "PMTiles") {
      throw CorruptArchiveException(
          'Invalid magic in header file, found "$magic"');
    }

    if (version != 3) {
      throw UnsupportedError('Version "$version" files');
    }

    if (!strict) {
      return;
    }

    // If any "int64" are greater than 2^53, we may have problems when
    // running as JavaScript. If any are greater than 2^63, we may also have
    // problems due to dart not having a unsigned int64 type.
    // TODO Add more robust testing of these values:
    rootDirectoryOffset;
    rootDirectoryLength;
    metadataOffset;
    metadataLength;
    leafDirectoriesOffset;
    leafDirectoriesLength;
    tileDataOffset;
    tileDataLength;
    numberOfAddressedTiles;
    numberOfTileEntries;
    numberOfTileContents;

    // Check we can read each of these enum values. These may throw exceptions.
    clustered;
    internalCompression;
    tileCompression;
    tileType;

    if (minZoom > maxZoom) {
      throw CorruptArchiveException(
          'Invalid min and max zoom. Max zoom ($maxZoom) must be greater than or equal to the min zoom ($minZoom)');
    }

    if (centerZoom < minZoom || centerZoom > maxZoom) {
      throw CorruptArchiveException(
          'Invalid center zoom. Center zoom ($centerZoom) must be between the min zoom ($minZoom) and max zoom ($maxZoom)');
    }
  }

  @override
  String toString() {
    return '''
      magic: ${utf8.decode(magic)},
      version: $version,
      rootDirectoryOffset: $rootDirectoryOffset,
      rootDirectoryLength: $rootDirectoryLength,
      metadataOffset: $metadataOffset,
      metadataLength: $metadataLength,
      leafDirectoriesOffset: $leafDirectoriesOffset,
      leafDirectoriesLength: $leafDirectoriesLength,
      tileDataOffset: $tileDataOffset,
      tileDataLength: $tileDataLength,
      numberOfAddressedTiles: $numberOfAddressedTiles,
      numberOfTileEntries: $numberOfTileEntries,
      numberOfTileContents: $numberOfTileContents,
      clustered: $clustered,
      internalCompression: $internalCompression,
      tileCompression: $tileCompression,
      tileType: $tileType,
      minZoom: $minZoom,
      maxZoom: $maxZoom,
      minPosition: $minPosition,
      maxPosition: $maxPosition,
      centerZoom: $centerZoom,
      centerPosition: $centerPosition,
    ''';
  }
}
