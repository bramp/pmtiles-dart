class TileNotFoundException implements Exception {
  TileNotFoundException(this.tileId);
  final int tileId;

  @override
  String toString() {
    return 'TileNotFoundException: $tileId';
  }
}

class CorruptArchiveException implements Exception {
  CorruptArchiveException(this.message);
  final String message;

  @override
  String toString() {
    return 'CorruptArchiveException: $message';
  }
}
