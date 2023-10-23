# pmtiles-dart

Read PMTiles v3 archives stored locally or remotely.

## Usage

```dart
import 'package:pmtiles/pmtiles.dart';

final tiles = await PmTilesArchive.from('/path/to/file.pmtiles');
try {
    print(tiles.tileType); // e.g mvt, png, jpeg, etc.

    final tileId = ZXY(0, 0, 0).toTileId();
    final tileBytes = await tiles.tile(tildId, {uncompress: true});

    // Do something with tileBytes

} finally {
    await tiles.close();
}
```

## Development

Use `melos bootstrap` to install dependencies and link packages together.

## Additional information

The specification is here https://github.com/protomaps/PMTiles/tree/main/spec/v3

## LICENSE

```
BSD 2-Clause License

Copyright (c) 2023, Andrew Brampton

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