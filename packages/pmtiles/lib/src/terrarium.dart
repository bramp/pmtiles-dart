/// Helpers for PMTiles v3.6 `encoding: terrarium` metadata.
class Terrarium {
  const Terrarium._();

  /// Metadata value for `encoding` when tiles use Terrarium elevation format.
  ///
  /// Used with archive metadata, for example:
  /// `metadata['encoding'] == Terrarium.encoding`.
  static const String encoding = 'terrarium';

  /// Returns true if metadata declares PMTiles terrain encoding.
  ///
  /// Example:
  /// ```dart
  /// final metadata = await archive.metadata;
  /// final enabled = Terrarium.isTerrarium(metadata);
  /// ```
  static bool isTerrarium(Object? metadata) {
    if (metadata is! Map) {
      return false;
    }

    final value = metadata['encoding'];
    return value == encoding;
  }

  /// Decodes elevation (meters) from Terrarium RGB channels.
  ///
  /// Formula from PMTiles v3.6 spec:
  /// (red * 256 + green + blue / 256) - 32768
  static double decodeElevation(int red, int green, int blue) {
    _validateChannel('red', red);
    _validateChannel('green', green);
    _validateChannel('blue', blue);

    return (red * 256 + green + blue / 256.0) - 32768.0;
  }

  /// Decodes elevation (meters) from a byte list containing RGB values.
  static double decodeElevationFromRgb(List<int> rgb, {int offset = 0}) {
    if (offset < 0 || offset + 2 >= rgb.length) {
      throw RangeError.range(offset, 0, rgb.length - 3, 'offset');
    }

    return decodeElevation(rgb[offset], rgb[offset + 1], rgb[offset + 2]);
  }

  /// Decodes elevation (meters) from an RGBA byte list using [pixelIndex].
  ///
  /// Each pixel consumes 4 bytes in RGBA order, where only RGB are used for
  /// Terrarium decoding and alpha is ignored.
  static double decodeElevationFromRgba(List<int> rgba, {int pixelIndex = 0}) {
    if (pixelIndex < 0) {
      throw RangeError.range(pixelIndex, 0, null, 'pixelIndex');
    }

    final offset = pixelIndex * 4;
    if (offset + 2 >= rgba.length) {
      final maxPixelIndex = (rgba.length - 3) ~/ 4;
      throw RangeError.range(pixelIndex, 0, maxPixelIndex, 'pixelIndex');
    }

    return decodeElevation(rgba[offset], rgba[offset + 1], rgba[offset + 2]);
  }

  static void _validateChannel(String name, int value) {
    if (value < 0 || value > 255) {
      throw RangeError.range(value, 0, 255, name);
    }
  }
}
