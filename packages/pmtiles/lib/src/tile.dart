import 'compression.dart';
import 'types.dart';

/// Represents a single tile in the archive.
class Tile {
  final int id;

  final TileType type;
  final Compression compression;

  /// The compressed bytes for this tile.
  final List<int>? _bytes;

  /// The exception that occured when trying to read this tile.
  final Exception? _exception;

  Tile(
    this.id, {
    List<int>? bytes,
    Exception? exception,
    this.compression = Compression.unknown,
    this.type = TileType.unknown,
  })  : _bytes = bytes,
        _exception = exception,
        assert(bytes != null || exception != null,
            "One of bytes or exception must be set");

  /// The tile's uncompressed bytes.
  /// This may throw an Exception if there was an issue reading or decompressing
  /// the bytes.
  List<int> bytes() {
    final bytes = compressedBytes();

    if (compression == Compression.none) {
      return bytes;
    }

    return compression.decoder().convert(bytes);
  }

  /// The tile's bytes compressed with the [compression] algorithm.
  /// This may be useful if the Tile is going to be served with the same
  /// compression as how they are stored in the archive.
  /// This may throw an Exception if there was an issue reading the bytes for
  /// any reason.
  List<int> compressedBytes() {
    if (_exception != null) {
      throw _exception!;
    }

    return _bytes!;
  }
}
