import 'package:http/http.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';

import 'server_args.dart';

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
  Future<ByteStream> readAt(int offset, int length) {
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
      (Match m) => 'http://${m[4]}:${m[2]}');
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
    channel.sink.add('tearDownAll');
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
    channel.sink.add('tearDownAll');
    await channel.sink.done;
  });

  final url = await channel.stream
      .firstWhere((line) => line.contains('http://127.0.0.1:'), orElse: () {
    throw Exception('Failed to find available line.');
  });

  // Get the url server is running on.
  return (url as String).trim();
}
