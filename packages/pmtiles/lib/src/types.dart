enum Clustered { notClustered, clustered }

enum Compression { unknown, none, gzip, brotli, zstd }

enum TileType {
  unknown,

  /// Vector Tile
  mvt,

  /// MapLibre Vector Tile
  mlt,

  /// Raster Tile
  png,
  jpeg,
  webp,
  avif,
}

extension TileTypeMime on TileType {
  /// Returns the mime type for this tile type.
  String mimeType() => switch (this) {
    TileType.mvt => 'application/vnd.mapbox-vector-tile',
    TileType.mlt => 'application/vnd.maplibre-vector-tile',
    TileType.png => 'image/png',
    TileType.jpeg => 'image/jpeg',
    TileType.webp => 'image/webp',
    TileType.avif => 'image/avif',
    _ => throw UnsupportedError('Unknown tile type $this'),
  };

  /// Returns the file extension for this tile type.
  String ext() => switch (this) {
    TileType.mvt => 'mvt',
    TileType.mlt => 'mlt',
    TileType.png => 'png',
    TileType.jpeg => 'jpg',
    TileType.webp => 'webp',
    TileType.avif => 'avif',
    _ => throw UnsupportedError('Unknown tile type $this'),
  };
}
