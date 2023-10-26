import 'dart:convert';

import 'package:pmtiles/pmtiles.dart';

/// A simple example of reading a PmTiles archive.
Future<int> main() async {
  // Open the archive from a file. HTTP URLs are also acceptable.
  final archive = await PmTilesArchive.from("/path/to/file.pmtiles");
  try {
    // # Metadata
    // Information about the archive is available in the header and metadata.
    print("Header:");
    print(archive.header);

    // Some interesting fields are also on the main tiles archive object.
    print("Type: ${archive.tileType}"); // e.g  mvt, png, jpg, etc.
    print("Compression: ${archive.tileCompression}"); // e.g gzip, brotli, etc.

    // The metadata is a embedded JSON object, as described here:
    // https://github.com/protomaps/PMTiles/blob/main/spec/v3/spec.md#5-json-metadata
    print("Metadata:");
    final prettyJson = JsonEncoder.withIndent('  ') // for clarity pretty print
        .convert(await archive.metadata);
    print(prettyJson);

    // # Tiles
    // To extract a tiles from the archive, you index them by a tile ID (which
    // can be converted to/from a ZXY coordinate).
    final int tileId = ZXY(4, 3, 2).toTileId();

    // To extract a single tile:
    final Tile t = await archive.tile(tileId);
    t.type; // e.g. mvt, png, jpg, etc.

    // The uncompressed bytes of the tile is available as a List<int>.
    t.bytes();

    // Equally if the tile is going to be reserved, you may leave it compressed
    // in the format that was used in the archive. See tiles.tileCompression above.
    t.compressedBytes();

    // To extract multiple tiles:
    final tiles = archive.tiles([tileId, tileId + 1, tileId + 2]);

    // This returns a Stream<Tiles> and Tiles will be returned as they become
    // available from the archive. This is optimised to reduce the requests
    // to the archive's backing store, leading to faster extraction.
    await for (final tile in tiles) {
      print("${tile.id} is available");

      // Again the bytes are available via:
      tile.bytes();
    }
  } finally {
    // Don't forget the close the archive once you are done.
    await archive.close();
  }

  return 0;
}
