class TileNotFoundException implements Exception {
  final int tileId;

  TileNotFoundException(this.tileId);

  @override
  String toString() {
    return 'TileNotFoundException: $tileId';
  }
}
