import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import 'server_args.dart';

final client = http.Client();
late final String pmtilesUrl;
final sampleDir = path.join(Directory.current.path, 'samples');

/// Use the pmtiles server to get the tile, as a source of comparision
Future<http.Response> getReferenceTile(
    String archive, int tildId, String ext) async {
  final t = ZXY.fromTileId(tildId);

  final basename = path.basenameWithoutExtension(archive);
  final response = await client.get(
    Uri.parse('$pmtilesUrl/$basename/${t.z}/${t.x}/${t.y}.$ext'),
  );
  return response;
}

dynamic getReferenceMetadata(String sample) async {
  final basename = path.basenameWithoutExtension(sample);
  return json.decoder.convert(
    await http.read(
      Uri.parse('$pmtilesUrl/$basename/metadata'),
    ),
  );
}

/// Wrapper for a ReadAt, that counts how many requests/bytes are read.
class CountingReadAt implements ReadAt {
  final ReadAt _inner;
  int requests = 0;
  int bytes = 0;

  CountingReadAt(this._inner);

  @override
  Future<void> close() {
    return _inner.close();
  }

  @override
  Future<http.ByteStream> readAt(int offset, int length) {
    requests++;
    bytes += length;
    return _inner.readAt(offset, length);
  }

  void reset() {
    requests = 0;
    bytes = 0;
  }
}

String pmtilesServingToUrl(String logline) {
  return logline.replaceAllMapped(
      RegExp(r'(.* Serving .* port )(\d+)( .* interface )([\d.]+)(.*)'),
      (Match m) => "http://${m[4]}:${m[2]}");
  // ${m[4]} may be 0.0.0.0, which seems to allow us to connect to (on my
  // mac), but I'm not sure that's valid everywhere. Maybe we replaced
  // that with localhost.
}

/// Start a `pmtile server` instance, returning the URL its running on.
Future<String> startPmtilesServer() async {
  final channel = spawnHybridUri(
    'server.dart',
    stayAlive: true,
    message: ServerArgs(
      executable: 'pmtiles',
      arguments: [
        'serve',
        '.',

        '--port', '\$port',

        // Allow requests from any origin. This allows the `chrome` browser
        // based tests to work.
        '--cors',
        '*'
      ],
      workingDirectory: 'samples',
      waitFor: 'Serving',
    ).toJson(),
  );

  addTearDown(() async {
    // Tell the pmtiles server to shutdown and wait for the sink to be closed.
    channel.sink.add("tearDownAll");
    await channel.sink.done;
  });

  // Get the url pmtiles server is running on.
  return pmtilesServingToUrl(await channel.stream.first);
}

// This is very heavy handed, but we'll run a `pmtiles server`, and makes 1000s
// of API calls comparing the reference results to the results to our library.
//
// There is a lot of additional complexity here, so these tests can be
// performaned from a web browser. As such, the serving of the test data is done
// from a `spawnHybridUri` isolate, and the actual test in this file is run
// in the browser.
void main() async {
  final samples = [
    'samples/countries.pmtiles',
    'samples/countries-raster.pmtiles',
    'samples/countries-leaf.pmtiles',
    'samples/countries-leafs.pmtiles',
    'samples/trails.pmtiles',
  ];

  setUpAll(() async {
    pmtilesUrl = await startPmtilesServer();
  });

  group('archive', () {
    for (final sample in samples) {
      test('$sample metadata()', () async {
        // Fetch the reference metadata from the pmtiles server.
        final expected = await getReferenceMetadata(sample);

        // Now test our implementation
        final file = File(sample);
        final archive = await PmTilesArchive.fromFile(file);
        try {
          final actual = await archive.metadata;
          expect(actual, equals(expected));
        } finally {
          await archive.close();
        }
      });

      test('$sample tile(..)', () async {
        final file = File(sample);
        final archive = await PmTilesArchive.fromFile(file);
        try {
          final ext = archive.header.tileType.ext();

          // TODO Maybe set this to min/max location
          for (var id = 0; id < 5400; id++) {
            final response = await getReferenceTile(sample, id, ext);
            final expected = response.bodyBytes;

            try {
              final tile = await archive.tile(id);
              final actual = Uint8List.fromList(tile.bytes());

              // If we managed to call tiles.tile, then the server should have also
              // returned a 200 OK
              expect(200, equals(response.statusCode), reason: 'Tile $id');
              expect(actual, equals(expected), reason: 'Tile $id');
            } on TileNotFoundException {
              // If we throw a TileNotFoundException we should expect the server
              // to return a 404 Not Found, or a 204 No Content.
              expect(204, equals(response.statusCode), reason: 'Tile $id');
            }
          }
        } finally {
          await archive.close();
        }
      });

      test('$sample tiles(..)', () async {
        final file = File(sample);

        final archive = await PmTilesArchive.fromFile(file);
        try {
          final ext = archive.header.tileType.ext();
          const groupSize = 16 * 16;

          // TODO Maybe set this to min/max location
          for (var id = 0; id < 5400; id += groupSize) {
            final wanted = List.generate(groupSize, (index) => id + index);

            // Fetch and wait for all the tiles in one large go
            final tiles = await archive.tiles(wanted).toList();
            expect(tiles.length, wanted.length);

            // Now for each tile, check it matches what we expected
            for (id in wanted) {
              final tile = tiles.singleWhere((t) => t.id == id, orElse: () {
                fail('Failed to find Tile $id in list of fetched tiles $tiles');
              });

              final response = await getReferenceTile(sample, id, ext);

              try {
                final actual = Uint8List.fromList(tile.bytes());
                final expected = response.bodyBytes;

                // If we managed to call tiles.tiles, then the server should
                // have also returned a 200 OK
                expect(200, equals(response.statusCode), reason: 'Tile $id');
                expect(actual, equals(expected), reason: 'Tile $id');
              } on TileNotFoundException {
                // If we throw a TileNotFoundException we should expect the server
                // to return a 404 Not Found, or a 204 No Content.
                expect(204, equals(response.statusCode), reason: 'Tile $id');
              }
            }
          }
        } finally {
          await archive.close();
        }
      });

      test('$sample tiles(..) counting reads', () async {
        final file = CountingReadAt(FileAt(File(sample)));

        final archive = await PmTilesArchive.fromReadAt(file);
        try {
          // One request to read the header + root directory
          expect(file.requests, equals(1));
          expect(file.bytes, equals(16384));
          file.reset();

          const groupSize = 16 * 16;
          final wanted = List.generate(groupSize, (index) => index);

          // Fetch the first groupSize tiles.
          final tiles = await archive.tiles(wanted).toList();
          expect(tiles.length, wanted.length);

          // Check we made the right number of requests.
          if (archive.header.leafDirectoriesLength > 0) {
            // Expect 1 tile + 1 or 2 leaf read (in addition to the header read above).
            expect(file.requests, inInclusiveRange(2, 3));
          } else {
            // Expect 1 tile read (in addition to the header read above).
            expect(file.requests, equals(1));
          }
          file.reset();
        } finally {
          await archive.close();
        }
      });
    }
  }, timeout: Timeout(Duration(minutes: 1)));
}
