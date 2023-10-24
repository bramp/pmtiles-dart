import 'dart:convert';
import 'dart:typed_data';

import 'package:latlong2/latlong.dart';
import 'package:pmtiles/pmtiles.dart';

/// Converting between types.
///

/// Convenient class to do nothing, but can be used in places where we assume
/// a converter is required.
class NullConverter<S> extends Converter<S, S> {
  const NullConverter();

  @override
  S convert(S input) => input;

  @override
  Sink<S> startChunkedConversion(Sink<S> sink) => sink;
}

final nullConverter = NullConverter<List<int>>();

extension PmpTilesByteData on ByteData {
  Clustered getClustered(int byteOffset) {
    final b = getUint8(byteOffset);
    return switch (b) {
      0 => Clustered.notClustered,
      1 => Clustered.clustered,
      _ => throw CorruptArchiveException('Invalid clustered value "$b"'),
    };
  }

  Compression getCompression(int byteOffset) {
    final b = getUint8(byteOffset);
    return switch (b) {
      0 => Compression.unknown,
      1 => Compression.none,
      2 => Compression.gzip,
      3 => Compression.brotli,
      4 => Compression.zstd,
      _ => throw CorruptArchiveException('Invalid compression value "$b"'),
    };
  }

  TileType getTileType(int byteOffset) {
    final b = getUint8(byteOffset);
    return switch (b) {
      0 => TileType.unknown,
      1 => TileType.mvt,
      2 => TileType.png,
      3 => TileType.jpeg,
      4 => TileType.webp,
      5 => TileType.avif,
      _ => throw CorruptArchiveException('Invalid tile type value "$b"'),
    };
  }

  LatLng getLatLng(int byteOffset) {
    final longitude = getInt32(byteOffset, Endian.little);
    final latitude = getInt32(byteOffset + 4, Endian.little);

    return LatLng(
      latitude.toDouble() / 10000000.0,
      longitude.toDouble() / 10000000.0,
    );
  }
}
