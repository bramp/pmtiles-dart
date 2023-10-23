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

// TODO Move these tests into a seperate project, as they include deps that the
// main library doesn't need (e.g. http).
void main() async {
  // This is very heavy handed, but we'll run a pmtiles server, and compare
  // the results to our library.
  final port = await getUnusedPort(InternetAddress.loopbackIPv4);
  late final Process process;

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

  group('archive', () {
    for (final archive in samples) {
      test('$archive metadata', () async {
        final expected = json.decoder.convert(
          await http.read(
            Uri.parse(
                'http://localhost:$port/${p.basenameWithoutExtension(archive)}/metadata'),
          ),
        );

        final file = File(archive);
        final tiles = await PmTilesArchive.fromFile(file);
        try {
          final actual = await tiles.metadata;
          expect(actual, equals(expected));
        } finally {
          await tiles.close();
        }
      });

      test('$archive tiles', () async {
        final file = File(archive);
        final tiles = await PmTilesArchive.fromFile(file);

        try {
          final ext = tiles.header.tileType.ext();

          // TODO Maybe set this to min/max location
          for (var id = 0; id < 5400; id++) {
            final t = ZXY.fromTileId(id);

            final response = await http.get(
              Uri.parse(
                  'http://localhost:$port/${p.basenameWithoutExtension(archive)}/${t.z}/${t.x}/${t.y}.$ext'),
            );
            final expected = response.bodyBytes;

            try {
              final actual = Uint8List.fromList(
                await tiles.tile(id, uncompress: true),
              );

              // If we managed to call tiles.tile, then the server should have also
              // returned a 200 OK
              expect(200, equals(response.statusCode),
                  reason: '$archive Tile $id $t');
              expect(actual, equals(expected), reason: '$archive Tile $id $t');
            } on TileNotFoundException {
              // If we throw a TileNotFoundException we should expect the server
              // to return a 404 Not Found, or a 204 No Content.
              expect(204, equals(response.statusCode),
                  reason: '$archive Tile $id $t');
            }
          }
        } finally {
          await tiles.close();
        }
      });
    }
  }, timeout: Timeout(Duration(minutes: 1))); // TODO Change timeout
}
