import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

/// Gets a free port on the local machine.
/// Borrowed from https://stackoverflow.com/a/14095888/88646
/// This is racy, because we don't hold the port open, but it's good enough for
/// our purposes.
Future<int> getUnusedPort(InternetAddress? address) {
  return ServerSocket.bind(address ?? InternetAddress.loopbackIPv4, 0)
      .then((socket) {
    var port = socket.port;
    socket.close();
    return port;
  });
}

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

// This is very heavy handed, but we'll run a pmtiles server, and compare
// the results to our library.
void main() async {
  final port = await getUnusedPort(InternetAddress.loopbackIPv4);
  late final Process process;
  final client = http.Client();

  final sampleDir = p.join(Directory.current.path, 'samples');
  final samples = [
    'samples/countries.pmtiles',
    'samples/countries-raster.pmtiles',
    'samples/countries-leaf.pmtiles',
    'samples/countries-leafs.pmtiles',
    'samples/trails.pmtiles',
  ];

  setUpAll(() async {
    // Find the pmtiles binary
    // We could consider allowing this to be set on the env.
    final pmtiles =
        Process.runSync('which', ['pmtiles']).stdout.toString().trim();
    expect(pmtiles, isNotEmpty, reason: 'Could not find pmtiles binary');

    // Invoke `pmtiles serve`.
    process = await Process.start(
      pmtiles,
      [
        'serve',
        '.',
        '--port',
        port.toString(),
      ],
      includeParentEnvironment: false,
      workingDirectory: sampleDir,
    );

    // Wait until it prints 'Serving ... on port'
    final stdout = process.stdout.transform(utf8.decoder).asBroadcastStream();
    await stdout.firstWhere((line) => line.contains('Serving'));

    // Then ignore the rest
    stdout.drain();

    // Always print stderr
    process.stderr.transform(utf8.decoder).forEach(print);
  });

  tearDownAll(() async {
    process.kill();
    await process.exitCode;
  });

  /// Use the pmtiles server to get the tile, as a source of comparision
  Future<http.Response> getReferenceTile(
      String archive, int tildId, String ext) async {
    final t = ZXY.fromTileId(tildId);

    final response = await client.get(
      Uri.parse(
          'http://localhost:$port/${p.basenameWithoutExtension(archive)}/${t.z}/${t.x}/${t.y}.$ext'),
    );
    return response;
  }

  group('archive', () {
    for (final sample in samples) {
      test('$sample metadata()', () async {
        final expected = json.decoder.convert(
          await http.read(
            Uri.parse(
                'http://localhost:$port/${p.basenameWithoutExtension(sample)}/metadata'),
          ),
        );

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
