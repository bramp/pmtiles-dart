import 'dart:convert';
import 'dart:io';
import 'package:stream_channel/stream_channel.dart';

import 'server_args.dart';

/// Gets a free port on the local machine.
///
/// This is racy, because we don't hold the port open, but it's good enough for
/// our purposes.
///
/// Borrowed from https://stackoverflow.com/a/14095888/88646
Future<int> getUnusedPort([InternetAddress? address]) {
  return ServerSocket.bind(address ?? InternetAddress.loopbackIPv4, 0)
      .then((socket) {
    var port = socket.port;
    socket.close();
    return port;
  });
}

/// Spawns a process that can be used for receiving test requests.
///
/// Use like this:
/// ```dart
///   setUpAll(() async {
///     channel = spawnHybridUri(
///       'server.dart',
///       stayAlive: true,
///       message: ServerArgs(
///         executable: 'http-server',
///         arguments: ['.'],
///         workingDirectory: 'samples',
///       ).toJson(),
///     );
///
///     url = await channel!.stream.first;
///     // Now the server is ready
///   });
///
///   tearDownAll(() async {
///     // Tell the server to shutdown and wait for the sink to be closed.
///     if (channel != null) {
///       channel!.sink.add("tearDownAll");
///       await channel!.sink.done;
///     }
///   });
/// ```
///
hybridMain(StreamChannel channel, Object message) async {
  final args = ServerArgs.fromJson(message as Map<String, dynamic>);

  // Find the binary, as Process seems to require a full path.
  final executableFullPath =
      Process.runSync('which', [args.executable]).stdout.toString().trim();

  if (executableFullPath.isEmpty) {
    throw Exception('Could not find `${args.executable}` binary');
  }

  // Replace any `$port`, with a random port number
  final arguments = await Future.wait(args.arguments.map((s) async {
    while (s.contains('\$port')) {
      final port = await getUnusedPort();
      s = s.replaceFirst('\$port', port.toString());
    }
    return s;
  }));

  // Invoke the binary
  Process process = await Process.start(
    executableFullPath,
    arguments,
    workingDirectory: args.workingDirectory,
    includeParentEnvironment: false,
  );

  try {
    // Wait until it prints the 'available' string.
    final stdout = process.stdout.transform(utf8.decoder).asBroadcastStream();
    final url = await stdout.firstWhere((line) => line.contains(args.waitFor));

    // Then ignore the rest
    stdout.drain();

    // Always print stderr
    process.stderr.transform(utf8.decoder).forEach(print);

    // Send the line we found
    channel.sink.add(url);

    // Wait for the channel to receive a message telling us to tearDown.
    await channel.stream.first; // the received message should be "tearDownAll".
  } finally {
    // The spawned process may hang around due to
    // https://github.com/dart-lang/sdk/issues/53772 :(

    // Cleanup the process
    process.kill();
    await process.exitCode;
  }

  // and we are done.
  channel.sink.close();
}
