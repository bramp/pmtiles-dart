enum Clustered {
  notClustered,
  clustered,
}

enum Compression {
  unknown,
  none,
  gzip,
  brotli,
  zstd,
}

enum TileType {
  unknown,

  /// Vector Tile
  mvt,
  png,
  jpeg,
  webp,
  avif
}
