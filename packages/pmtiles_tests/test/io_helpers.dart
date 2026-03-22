import 'dart:async';

import 'package:http/http.dart';
import 'package:pmtiles/pmtiles.dart';
import 'package:test/test.dart';

import 'server_args.dart';

/// Wrapper for a ReadAt, that counts how many requests/bytes are read.
class CountingReadAt implements ReadAt {
  CountingReadAt(this._inner);
  final ReadAt _inner;
  int requests = 0;
  int bytes = 0;

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
    (m) => 'http://${m[4]}:${m[2]}',
  );
  // ${m[4]} may be 0.0.0.0, which seems to allow us to connect to (on my
  // mac), but I'm not sure that's valid everywhere. Maybe we replaced
  // that with localhost.
}

/// Start a `pmtiles serve` instance, returning the URL its running on.
Future<String> startPmtilesServer() async {
  final channel = spawnHybridUri(
    'server.dart',
    stayAlive: true,
    message: const ServerArgs(
      executable: 'pmtiles',
      arguments: [
        'serve',
        '.',

        '--port', r'$port',

        // Allow requests from any origin. This allows the `chrome` browser
        // based tests to work.
        '--cors', '*',
      ],
      workingDirectory: 'samples',
    ).toJson(),
  );

  final output = <String>[];
  final urlCompleter = Completer<String>();

  channel.stream.listen(
    (dynamic line) {
      final s = line as String;
      output.add(s);
      if (!urlCompleter.isCompleted) {
        urlCompleter.complete(s);
      }
    },
    onDone: () {
      if (!urlCompleter.isCompleted) {
        urlCompleter.completeError(
          Exception(
            'pmtiles stream closed without output.\n${output.join('\n')}',
          ),
        );
      }
    },
  );

  addTearDown(() async {
    // Tell the pmtiles server to shutdown and wait for the sink to be closed.
    channel.sink.add('tearDownAll');
    try {
      await channel.sink.done.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      print('pmtiles tearDown timed out. Output:\n${output.join('\n')}');
      rethrow;
    }
  });

  // Get the url pmtiles server is running on.
  return pmtilesServingToUrl(await urlCompleter.future);
}

/// Starts a plain http server, returning the URL its running on.
Future<String> startHttpServer() async {
  final channel = spawnHybridUri(
    'server.dart',
    stayAlive: true,
    message: const ServerArgs(
      executable: 'npx',
      arguments: [
        'http-server',
        '.',

        // Allow requests from any origin. This allows the `chrome` browser
        // based tests to work.
        '--cors', '*',
      ],
      workingDirectory: 'samples',

      // Needed for `npx` to find `node`.
      includeParentEnvironment: true,
    ).toJson(),
  );

  final output = <String>[];
  final urlCompleter = Completer<String>();

  channel.stream.listen(
    (dynamic line) {
      final s = line as String;
      output.add(s);
      if (!urlCompleter.isCompleted && s.contains('http://127.0.0.1:')) {
        urlCompleter.complete(s.trim());
      }
    },
    onDone: () {
      if (!urlCompleter.isCompleted) {
        urlCompleter.completeError(
          Exception(
            'http-server stream closed without URL.\n${output.join('\n')}',
          ),
        );
      }
    },
  );

  addTearDown(() async {
    // Tell the server to shutdown and wait for the sink to be closed.
    channel.sink.add('tearDownAll');
    try {
      await channel.sink.done.timeout(const Duration(seconds: 10));
    } on TimeoutException {
      print('http-server tearDown timed out. Output:\n${output.join('\n')}');
      rethrow;
    }
  });

  // Get the url server is running on.
  return urlCompleter.future;
}
