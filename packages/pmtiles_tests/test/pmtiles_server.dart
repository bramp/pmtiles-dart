import 'dart:convert';
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';
import 'package:path/path.dart' as path;

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

final sampleDir = path.join(Directory.current.path, 'samples');

/// Starts a `pmtiles serve` process, that can be used for receiving test
/// requests.
hybridMain(StreamChannel channel) async {
  int port = await getUnusedPort(InternetAddress.loopbackIPv4);

  // Find the pmtiles binary
  // We could consider allowing this to be set on the env.
  final pmtiles =
      Process.runSync('which', ['pmtiles']).stdout.toString().trim();

  if (pmtiles.isEmpty) {
    throw Exception('Could not find pmtiles binary');
  }

  // Invoke `pmtiles serve`.
  Process process = await Process.start(
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

  try {
    // Wait until it prints 'Serving ... on port'
    final stdout = process.stdout.transform(utf8.decoder).asBroadcastStream();
    await stdout.firstWhere((line) => line.contains('Serving'));

    // The spawned `pmtiles` process may hang around due to
    // https://github.com/dart-lang/sdk/issues/53772 :(

    // Then ignore the rest
    stdout.drain();

    // Always print stderr
    process.stderr.transform(utf8.decoder).forEach(print);

    // Send the port back to the test
    channel.sink.add(port);

    // Wait for the channel to receive a message telling us to tearDown.
    await channel.stream.first; // the received rule should be "tearDownAll".
  } finally {
    // Cleanup the process
    process.kill();
    await process.exitCode;
  }

  // and we are done.
  channel.sink.close();
}
