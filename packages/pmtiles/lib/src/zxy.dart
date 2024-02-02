import 'dart:math';

import 'package:meta/meta.dart';

/// Convert from Tile ID to ZXY and back.
///
@immutable
class ZXY {
  final int z;
  final int x;
  final int y;

  /// The maximum supported zoom level.
  ///
  /// Only allow up to (and including) 26, so that this library works in places
  /// where doubles are used to represent ints, such as JavaScript.
  ///    tileID = 2^53 + 1 = ZXY(27, 67108861, 67108863)
  static const maxAllowedZoom = 26;

  const ZXY(this.z, this.x, this.y)
      : assert(z >= 0 && z < 27),
        assert(x >= 0 && x < (1 << z)),
        assert(y >= 0 && x < (1 << z));

  /// Maps a tileId to the appropriate Zoom, X and Y coordinate.
  factory ZXY.fromTileId(int tileId) {
    // We search each zoom level finding which one the tile belongs to
    // Then we use a Hilbert curve to map the ID into the X and Y coordinates.
    //
    // Some example are:
    //   |Z|X|Y|TileID|
    //   |0|0|0|0|
    //   |1|0|0|1|
    //   |1|0|1|2|
    //   |1|1|1|3|
    //   |1|1|0|4|
    //   |2|0|0|5|
    //   |...
    //   |12|3423|1763|19078479|
    //
    if (tileId < 0) {
      throw FormatException('Tile ID $tileId must be a positive integer.');
    }

    for (int z = 0; z <= maxAllowedZoom; z++) {
      // We could also replace the `pow(2, 2 * z)` with `1 << (2 * z)` but bit
      // operations are truncated to 32 bits in dart2js.
      // See https://github.com/dart-lang/sdk/issues/8298
      final tilesAtZoom = pow(2, 2 * z).toInt();

      if (tileId < tilesAtZoom) {
        final (x, y) = _Hilbert.map(1 << z, tileId);
        return ZXY(z, x, y);
      }

      tileId -= tilesAtZoom;
    }

    throw FormatException(
        'max zoom depth of $maxAllowedZoom exceeded while decoding $tileId');
  }

  int toTileId() {
    // The tile ID is effectively the sum of all possible tiles on previous
    // layers, and the value of the tile on this layer (as mapped by a Hilbert
    // curve). e.g
    //
    // for (int i = 0; i < z; i++) {
    //   tilesOnPreviousLayers += 1 << (i * 2);
    // }
    //
    // However that loop can be removed by using the following formula from
    // https://oeis.org/A002450.
    final tilesOnPreviousLayers = (pow(2, 2 * z) - 1) ~/ 3;

    // We could also replace the `pow(2, 2 * z)` with `1 << (2 * z)` but bit
    // operations are truncated to 32 bits in dart2js.
    // See https://github.com/dart-lang/sdk/issues/8298

    return tilesOnPreviousLayers + _Hilbert.inverse(1 << z, x, y);
  }

  @override
  bool operator ==(Object other) =>
      other is ZXY &&
      other.runtimeType == runtimeType &&
      other.z == z &&
      other.x == x &&
      other.y == y;

  @override
  int get hashCode => Object.hash(z, x, y);

  @override
  String toString() => 'ZXY($z, $x, $y)';
}

class _Hilbert {
  /// Maps t to (x, y) on a N x N Hilbert curve.
  static (int, int) map(int n, int t) {
    assert(t >= 0 && t < n * n);

    int x = 0;
    int y = 0;

    for (var i = 1; i < n; i = i * 2) {
      final rx = t & 2 == 2;
      final ry = t & 1 == (rx ? 0 : 1);

      (x, y) = _rotate(i, x, y, rx, ry);

      if (rx) {
        x = x + i;
      }
      if (ry) {
        y = y + i;
      }

      t = t ~/ 4;
    }

    return (x, y);
  }

  /// Inverse maps (x, y) to t on a N x N Hilbert curve.
  static int inverse(int n, int x, int y) {
    assert(x >= 0 && x < n && y >= 0 && y < n);

    int t = 0;

    for (int i = n ~/ 2; i > 0; i = i ~/ 2) {
      final rx = (x & i) > 0;
      final ry = (y & i) > 0;

      t += i * i * ((rx ? 3 : 0) ^ (ry ? 1 : 0));

      (x, y) = _rotate(i, x, y, rx, ry);
    }

    return t;
  }

  static (int, int) _rotate(int n, int x, int y, bool rx, bool ry) {
    if (!ry) {
      if (rx) {
        x = n - 1 - x;
        y = n - 1 - y;
      }

      return (y, x);
    }
    return (x, y);
  }
}
