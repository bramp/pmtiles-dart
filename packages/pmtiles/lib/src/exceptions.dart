class TileNotFoundException implements Exception {
  final int tileId;

  TileNotFoundException(this.tileId);

  @override
  String toString() {
    return 'TileNotFoundException: $tileId';
  }
}

class CorruptArchiveException implements Exception {
  final String message;

  CorruptArchiveException(this.message);

  @override
  String toString() {
    return 'CorruptArchive: $message';
  }
}
