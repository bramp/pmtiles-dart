// Exclude from node because it doesn't support the HTTP APIs needed to get
// the reference tiles.
@TestOn('!node')

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

import '../samples/headers.dart';
import 'io_helpers.dart';
import 'server_args.dart';

final client = http.Client();
late final String pmtilesUrl;
late final String httpUrl;

/// Use the pmtiles server to get the tile, as a source of comparision
Future<http.Response> getReferenceTile(
    String archive, int tileId, String ext) async {
  final t = ZXY.fromTileId(tileId);

  final basename = path.basenameWithoutExtension(archive);
  final response = await client.get(
    Uri.parse('$pmtilesUrl/$basename/${t.z}/${t.x}/${t.y}.$ext'),
  );
  return response;
}

dynamic getReferenceMetadata(String sample) async {
  final basename = path.basenameWithoutExtension(sample);
  final response =
      await client.get(Uri.parse('$pmtilesUrl/$basename/metadata'));

  // JSON response is UTF-8, but by default Dart HTTP's library thinks all
  // responses are ISO-8859-1. So for our testing purposes we explictly
  // decode it.
  return json.decoder.convert(utf8.decode(response.bodyBytes));
}

String pmtilesServingToUrl(String logline) {
  return logline.replaceAllMapped(
      RegExp(r'(.* Serving .* port )(\d+)( .* interface )([\d.]+)(.*)'),
      (Match m) => "http://${m[4]}:${m[2]}");
  // ${m[4]} may be 0.0.0.0, which seems to allow us to connect to (on my
  // mac), but I'm not sure that's valid everywhere. Maybe we replaced
  // that with localhost.
}

/// Start a `pmtiles serve` instance, returning the URL its running on.
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
        '--cors', '*'
      ],
      workingDirectory: 'samples',
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

/// Starts a plain http server, returning the URL its running on.
Future<String> startHttpServer() async {
  final channel = spawnHybridUri(
    'server.dart',
    stayAlive: true,
    message: ServerArgs(
      executable: 'http-server',
      arguments: [
        '.',

        // Allow requests from any origin. This allows the `chrome` browser
        // based tests to work.
        '--cors', '*'
      ],
      workingDirectory: 'samples',

      // Needed for `env` in http-server to find `node`.
      includeParentEnvironment: true,
    ).toJson(),
  );

  addTearDown(() async {
    // Tell the server to shutdown and wait for the sink to be closed.
    channel.sink.add("tearDownAll");
    await channel.sink.done;
  });

  final url = await channel.stream
      .firstWhere((line) => line.contains("http://127.0.0.1:"), orElse: () {
    throw Exception('Failed to find available line.');
  });

  // Get the url server is running on.
  return (url as String).trim();
}

// This is very heavy handed, but we'll run a `pmtiles server`, and makes 1000s
// of API calls comparing the reference results to the results to our library.
//
// There is a lot of additional complexity here, so these tests can be
// performaned from a web browser. As such, the serving of the test data is done
// from a `spawnHybridUri` isolate, and the actual test in this file is run
// in the browser.
void main() async {
  setUpAll(() async {
    pmtilesUrl = await startPmtilesServer();
    httpUrl = await startHttpServer();
  });

  for (final api in ['file', 'http']) {
    /// Returns the ReadAt for specific sample file. This may differ depending
    /// on test/environment.
    ReadAt readAtForSample(String sample) {
      switch (api) {
        case 'http':
          final p = path.basename(sample);
          return HttpAt(
            client,
            Uri.parse('$httpUrl/$p'),
          );
        case 'file':
          final p = path.join('samples', sample);
          return FileAt(File(p));
        default:
          throw Exception('Unknown API: $api');
      }
    }

    group('PmTilesArchive (via $api)', () {
      for (final sample in sampleHeaders.keys) {
        test('$sample metadata()', () async {
          final expected = await getReferenceMetadata(sample);

          final f = readAtForSample(sample);
          final archive = await PmTilesArchive.fromReadAt(f);

          try {
            final actual = await archive.metadata;
            expect(actual, equals(expected));
          } finally {
            await archive.close();
          }
        });

        test('$sample tile(..)', () async {
          final f = readAtForSample(sample);
          final archive = await PmTilesArchive.fromReadAt(f);

          try {
            final ext = archive.header.tileType.ext();

            // Set the min/max tile to test for.
            final min = ZXY(archive.header.minZoom, 0, 0).toTileId();
            final max = ZXY(archive.header.maxZoom, 0, 0).toTileId();

            // Some files have a lot of tiles, so we'll only test a subset.
            int increments = math.max((max - min) ~/ 5003, 1);

            for (int id = min; id < max; id += increments) {
              final reference = await getReferenceTile(sample, id, ext);
              final expected = reference.bodyBytes;

              final tile = await archive.tile(id);
              try {
                final actual = Uint8List.fromList(tile.bytes());

                // If we managed to call tiles.tile, then the server should have also
                // returned a 200 OK
                expect(200, equals(reference.statusCode), reason: 'Tile: $id');
                expect(actual, equals(expected), reason: 'Tile: $id');
              } on TileNotFoundException {
                // If we throw a TileNotFoundException we should expect the server
                // to return 204 No Content.

                // `pmtiles serve` returns 204 if the tile isn't found in the
                // archive, except when the zoom is too deep, which is returns 404.
                // It also returns 404 if the archive isn't found.
                expect(204, equals(reference.statusCode),
                    reason:
                        'Tile: $id, Request: ${reference.request?.url.toString()}');
              }
            }
          } finally {
            await archive.close();
          }
        });

        test('$sample tile(..) out of zoom range', () async {
          final f = readAtForSample(sample);
          final archive = await PmTilesArchive.fromReadAt(f);

          try {
            final ext = archive.header.tileType.ext();

            // Set the min/max tile to test for.
            final min = ZXY(archive.header.minZoom, 0, 0).toTileId();
            final max = ZXY(archive.header.maxZoom + 1, 0, 0).toTileId();

            if (archive.header.minZoom > 0) {
              final id = min - 1;
              final reference = await getReferenceTile(sample, id, ext);

              // Out of zoom range should return 404 by the server
              expect(404, equals(reference.statusCode),
                  reason:
                      'Tile: $id, Request: ${reference.request?.url.toString()}');

              final tile = await archive.tile(id);
              expect(() => tile.compressedBytes(),
                  throwsA(isA<TileNotFoundException>()),
                  reason:
                      'Tile: $id, Request: ${reference.request?.url.toString()}');
            }

            if (archive.header.maxZoom <= ZXY.maxAllowedZoom) {
              final id = max;
              final reference = await getReferenceTile(sample, id, ext);

              // Out of zoom range should return 404 by the server
              expect(404, equals(reference.statusCode),
                  reason:
                      'Tile: $id, Request: ${reference.request?.url.toString()}');

              final tile = await archive.tile(id);
              expect(() => tile.compressedBytes(),
                  throwsA(isA<TileNotFoundException>()),
                  reason:
                      'Tile: $id, Request: ${reference.request?.url.toString()}');
            }
          } finally {
            await archive.close();
          }
        });

        test('$sample tiles(..)', () async {
          final f = readAtForSample(sample);
          final archive = await PmTilesArchive.fromReadAt(f);

          try {
            final ext = archive.header.tileType.ext();
            const groupSize = 16 * 16;

            // Set the min/max tile to test for.
            final min = ZXY(archive.header.minZoom, 0, 0).toTileId();
            final max = ZXY(archive.header.maxZoom + 1, 0, 0).toTileId();

            int increments = math.max((max - min) ~/ 5003, 1);

            for (var id = min; id < max; id += (groupSize * increments)) {
              final remaining = max - id;
              final wanted = List.generate(
                  math.min(groupSize, remaining), (index) => id + index);

              // Fetch and wait for all the tiles in one large go
              final tiles = await archive.tiles(wanted).toList();
              expect(tiles.length, wanted.length);

              // Now for each tile, check it matches what we expected
              for (id in wanted) {
                final tile = tiles.singleWhere((t) => t.id == id, orElse: () {
                  fail(
                      'Failed to find Tile $id in list of fetched tiles $tiles');
                });

                final reference = await getReferenceTile(sample, id, ext);
                final expected = reference.bodyBytes;

                try {
                  final actual = Uint8List.fromList(tile.bytes());

                  // If we managed to call tiles.tiles, then the server should
                  // have also returned a 200 OK
                  expect(200, equals(reference.statusCode),
                      reason: 'Tile: $id');
                  expect(actual, equals(expected), reason: 'Tile: $id');
                } on TileNotFoundException {
                  // If we throw a TileNotFoundException we should expect the server
                  // to return a 404 Not Found, or a 204 No Content.
                  expect(204, equals(reference.statusCode),
                      reason:
                          'Tile: $id, Request: ${reference.request?.url.toString()}');
                }
              }
            }
          } finally {
            await archive.close();
          }
        });

        test('$sample tiles(..) counting reads', () async {
          final f = CountingReadAt(readAtForSample(sample));
          final archive = await PmTilesArchive.fromReadAt(f);

          try {
            // One request to read the header + root directory
            expect(f.requests, equals(1));
            expect(f.bytes, equals(16384));
            f.reset();

            const groupSize = 16 * 16;
            final min = ZXY(archive.header.minZoom, 0, 0).toTileId();
            final wanted = List.generate(groupSize, (index) => min + index);

            // Fetch the first groupSize tiles.
            final tiles = await archive.tiles(wanted).toList();
            expect(tiles.length, wanted.length);

            /// In some of the files there is a edge case where none are the
            /// tiles are found, so we remove them.
            tiles.removeWhere((tile) {
              try {
                tile.compressedBytes();
                return false;
              } on TileNotFoundException {
                return true;
              }
            });
            final expectedTileReads = tiles.isEmpty ? 0 : 1;

            // Check we made the right number of requests.
            if (archive.header.leafDirectoriesLength > 0) {
              expect(
                  f.requests,
                  inInclusiveRange(
                      expectedTileReads + 1, expectedTileReads + 2),
                  reason: 'Expect $expectedTileReads tile + 1-2 leaf read');
            } else {
              expect(f.requests, expectedTileReads,
                  reason: 'Expect $expectedTileReads tile read');
            }
            f.reset();
          } finally {
            await archive.close();
          }
        });
      }
    }, onPlatform: {
      ...api == 'file'
          ? {'js': Skip('File API is not supported in dart2js')}
          : {},
    }, timeout: Timeout(Duration(seconds: 90)));
  }
}
