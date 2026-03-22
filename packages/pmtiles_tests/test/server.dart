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
  return ServerSocket.bind(address ?? InternetAddress.loopbackIPv4, 0).then((
    socket,
  ) {
    final port = socket.port;
    socket.close();
    return port;
  });
}

/// Recursively finds all descendant PIDs of the given [pid].
Future<List<int>> _descendantPids(int pid) async {
  final result = await Process.run('pgrep', ['-P', '$pid']);
  if (result.exitCode != 0) return [];
  final children = (result.stdout as String)
      .split('\n')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .map(int.parse)
      .toList();
  final descendants = <int>[];
  for (final child in children) {
    descendants.add(child);
    descendants.addAll(await _descendantPids(child));
  }
  return descendants;
}

/// Sends [signal] to a list of PIDs using the system `kill` command.
Future<void> _killPids(List<int> pids, String signal) async {
  if (pids.isEmpty) return;
  await Process.run('kill', [signal, ...pids.map((p) => '$p')]);
}

/// Kills a process and all its descendants, waiting briefly for graceful exit
/// before force-killing.
///
/// See https://github.com/dart-lang/sdk/issues/53772
Future<void> killProcess(Process process) async {
  final pid = process.pid;

  // Collect all descendant PIDs before killing (they may reparent to init).
  final descendants = await _descendantPids(pid);
  final allPids = [pid, ...descendants];

  // SIGTERM the entire tree.
  await _killPids(allPids, '-TERM');

  // Wait briefly for graceful exit, then force-kill and move on.
  await process.exitCode.timeout(
    const Duration(seconds: 5),
    onTimeout: () async {
      // Re-collect descendants (tree may have changed) and SIGKILL everything.
      final remaining = await _descendantPids(pid);
      await _killPids([pid, ...remaining], '-KILL');
      return -1; // Don't await exitCode again; just move on.
    },
  );
}

/// Spawns a process that can be used for receiving test requests.
///
/// Use like this:
/// ```dart
///   setUpAll(() async {
///     final channel = spawnHybridUri(
///       'server.dart',
///       stayAlive: true,
///       message: ServerArgs(
///         executable: 'npx',
///         arguments: ['http-server', '.'],
///         workingDirectory: 'samples',
///       ).toJson(),
///     );
///
///     addTearDown(() async {
///       // Tell the server to shutdown and wait for the sink to be closed.
///       channel.sink.add("tearDownAll");
///       await channel.sink.done;
///     });
///
///     url = await channel.stream.first;
///     // Now the server is ready
///   });
/// ```
///
Future<void> hybridMain(StreamChannel<dynamic> channel, Object message) async {
  final args = ServerArgs.fromJson(message as Map<String, dynamic>);

  // Find the binary, as Process seems to require a full path.
  final executableFullPath = Process.runSync('which', [
    args.executable,
  ]).stdout.toString().trim();

  if (executableFullPath.isEmpty) {
    throw Exception('Could not find `${args.executable}` binary');
  }

  // Replace any `$port`, with a random port number
  final arguments = await Future.wait(
    args.arguments.map((arg) async {
      var s = arg;
      if (s.contains(r'$port')) {
        final port = await getUnusedPort();
        s = s.replaceFirst(r'$port', port.toString());
      }
      return s;
    }),
  );

  // Invoke the binary
  final process = await Process.start(
    executableFullPath,
    arguments,
    workingDirectory: args.workingDirectory,
    includeParentEnvironment: args.includeParentEnvironment,
  );

  try {
    // Forward both stdout and stderr to the sink, one line at a time.
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(channel.sink.add);

    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(channel.sink.add);

    // Wait for the channel to receive a message telling us to tearDown.
    await channel.stream.first; // the received message should be "tearDownAll".
  } finally {
    await killProcess(process);
  }

  // and we are done.
  channel.sink.close();
}
