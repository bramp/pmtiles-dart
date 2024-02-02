# pmtiles

by Andrew Brampton ([bramp.net](https://bramp.net))

Read PMTiles v3 archives stored locally or remotely.

[GitHub](https://github.com/bramp/pmtiles-dart) | [Package](https://pub.dev/packages/pmtiles) | [API Docs](https://pub.dev/documentation/pmtiles/latest/)

## Usage

```dart
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

```

## Support Matrix

Some effort has been made to ensure this library works correctly on
the native Dart VM, as well as when dart2js is used to compiled to
JavaScript (e.g. for use with Node.js or Chrome). The following table
shows the support matrix.

| Feature | Dart VM | Node.js | Browsers (e.g Chrome) |
| ------: | :-----: | :-----: | :-------------------: |
|         | Native  | dart2js |        dart2js        |
|    File |   Yes   |   No    |          No           |
|    HTTP |   Yes   |   No    |          Yes          |

If the library is used in an UnsupportedError exception will be thrown.

## Development

Use `melos bootstrap` to install dependencies and link packages together.

The package is broken up into `pmtiles`, `pmtiles_cli` and `pmtiles_tests`. The
`pmtiles` package contains the core logic and is published to [pub.dev](https://pub.dev/packages/pmtiles).
`pmtiles_cli` is a simple test command line.

Finally, `pmtiles_tests` is a collection of integration tests, including a suite
of sample files. This is kept seperate to `pmtiles` so the library remains
small.

To run all the tests on the dartvm, use `melos test`.  Additionally the tests
can be run via [Node.js](https://nodejs.org/) and [Chrome](https://www.google.com/chrome/)
`melos test:node` and `melos test:chrome` respectively. This ensures the library
works when compiled under dart2js.


## Additional information

The specification is here https://github.com/protomaps/PMTiles/tree/main/spec/v3

## LICENSE

```
BSD 2-Clause License

Copyright (c) 2023-2024, Andrew Brampton

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this
   list of conditions and the following disclaimer.

2. Redistributions in binary form must reproduce the above copyright notice,
   this list of conditions and the following disclaimer in the documentation
   and/or other materials provided with the distribution.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```